import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/geometry.dart';
import '../models/detection_result.dart';

/// 跨 Isolate 的帧载荷（共享知识 #6：消息体）。
///
/// [rgbBytes] 为 YUV→RGB 转换后的 3 字节/像素数据；
/// Isolate 内完成 resize 到模型输入 300×300。
class FramePayload {
  const FramePayload({
    required this.rgbBytes,
    required this.width,
    required this.height,
    required this.quarterTurns,
    required this.isFrontCamera,
  });

  final Uint8List rgbBytes;
  final int width;
  final int height;

  /// 图像相对预览方向的旋转（0/1/2/3 × 90°顺时针）
  final int quarterTurns;
  final bool isFrontCamera;

  /// 转为 Isolate 消息 Map（协议：所有消息均为 Map）
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rgbBytes': rgbBytes,
      'width': width,
      'height': height,
      'quarterTurns': quarterTurns,
      'isFrontCamera': isFrontCamera,
    };
  }
}

/// TFLite 常驻推理 Isolate（P0-4：AI 推理不阻塞主线程）。
///
/// 通信协议（共享知识 #6）：
/// - 首消息 `{'type':'init','modelBytes':...,'labels':...}`；
/// - 此后 `{'type':'detect','payload':FramePayload.toMap()}`、
///   `{'type':'pause'}`、`{'type':'resume'}`、`{'type':'dispose'}`；
/// - 响应 `{'type':'result','objects':[...]}`，objects 为 Map 列表；
/// - **单请求单响应、忙碌丢弃**：飞行中（_inFlight）再收到 detect 直接
///   丢帧（返回 null），天然背压，无重试。
///
/// tflite_flutter 为 FFI 实现，可在后台 Isolate 直接运行（不依赖平台通道）。
class InferenceIsolate {
  /// 模型输入边长（SSD MobileNet V1 量化版为 300×300）。
  ///
  /// 与 assets/models/README.md 的契约一致；若更换模型需同步修改。
  static const int inputSize = 300;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Completer<void>? _initCompleter;

  bool _inFlight = false;
  bool _paused = false;
  bool _disposed = false;
  bool _ready = false;
  Completer<List<ObjectBox>?>? _pendingCompleter;

  /// 是否已就绪（模型加载完成）
  bool get isReady => _ready && !_disposed;

  bool get isPaused => _paused;

  /// Spawn 后台 Isolate 并加载模型。
  ///
  /// 模型字节必须由主 Isolate 通过 rootBundle 读出后随 init 消息传入，
  /// 避免后台 Isolate 访问 rootBundle 的平台通道问题（架构 §6 说明 3）。
  Future<void> spawn(Uint8List modelBytes, List<String> labels) async {
    if (_isolate != null) return; // 已启动（幂等）

    _disposed = false;
    _initCompleter = Completer<void>();
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
      debugName: 'inference_isolate',
    );

    receivePort.listen(_onMessage);
    // 等待 entry 回传 sendPort + init 完成
    await _initCompleter!.future;
  }

  /// 物体检测。忙碌 / 暂停 / 未就绪时返回 null（调用方丢帧）。
  Future<List<ObjectBox>?> detect(FramePayload frame) {
    if (_disposed || _paused || _sendPort == null || _inFlight) {
      return Future.value(null);
    }
    _inFlight = true;
    final completer = Completer<List<ObjectBox>?>();
    _pendingCompleter = completer;

    _sendPort!.send(<String, dynamic>{
      'type': 'detect',
      'payload': frame.toMap(),
    });

    // 超时保护：1.2s 未返回则复位并按丢帧处理
    return completer.future.timeout(
      const Duration(milliseconds: 1200),
      onTimeout: () {
        if (!completer.isCompleted) {
          _inFlight = false;
          _pendingCompleter = null;
          return null;
        }
        // 修正：Future 没有 `.result` getter（那是 Completer 都还没提供的
        // 同步取值能力），原写法必然报 undefined_getter。语义上这里是「超时
        // 与完成发生竞态」的分支：completer 若已完成，直接把它的 future 交回
        // ——onTimeout 的返回值类型是 FutureOr<List<ObjectBox>?>，允许返回
        // Future，无需也不可能在同步上下文里取出结果。同时复位 _inFlight，
        // 避免 Isolate 被永久判定为忙碌。
        _inFlight = false;
        _pendingCompleter = null;
        return completer.future;
      },
    );
  }

  /// 拍照瞬间暂停（释放 CPU 给拍摄管线）
  void pause() {
    _paused = true;
    _sendPort?.send(<String, dynamic>{'type': 'pause'});
  }

  /// 拍照完成后恢复
  void resume() {
    _paused = false;
    _sendPort?.send(<String, dynamic>{'type': 'resume'});
  }

  /// 释放 Isolate
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sendPort?.send(<String, dynamic>{'type': 'dispose'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }

  // ===================== 主 Isolate 侧消息处理 =====================

  void _onMessage(Object? message) {
    if (message is! Map) return;
    final map = Map<String, dynamic>.from(message);
    switch (map['type'] as String?) {
      case 'ready':
        _sendPort = map['sendPort'] as SendPort?;
      case 'initDone':
        _ready = true;
        _initCompleter?.complete();
        _initCompleter = null;
      case 'result':
        final objects = _parseObjects(map['objects'] as List? ?? const []);
        _inFlight = false;
        final completer = _pendingCompleter;
        _pendingCompleter = null;
        if (completer != null && !completer.isCompleted) {
          completer.complete(objects);
        }
      case 'error':
        debugPrint('推理 Isolate 错误: ${map['message']}');
        _inFlight = false;
        final completer = _pendingCompleter;
        _pendingCompleter = null;
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
        }
    }
  }

  List<ObjectBox> _parseObjects(List raw) {
    return raw
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return ObjectBox(
            rect: Rect01(
              left: (m['left'] as num?)?.toDouble() ?? 0,
              top: (m['top'] as num?)?.toDouble() ?? 0,
              right: (m['right'] as num?)?.toDouble() ?? 0,
              bottom: (m['bottom'] as num?)?.toDouble() ?? 0,
            ),
            label: m['label'] as String? ?? 'object',
            confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList(growable: false);
  }

  // ===================== 后台 Isolate 入口 =====================

  /// Isolate 主入口：建立双向通信，接收 init/detect/pause/resume/dispose。
  static void _isolateEntry(SendPort mainSendPort) {
    final port = ReceivePort();
    // 第一步：回传本 Isolate 的 SendPort
    mainSendPort.send(<String, dynamic>{
      'type': 'ready',
      'sendPort': port.sendPort,
    });

    Interpreter? interpreter;
    var labels = const <String>[];
    var paused = false;

    port.listen((rawMessage) {
      if (rawMessage is! Map) return;
      final message = Map<String, dynamic>.from(rawMessage);
      try {
        switch (message['type'] as String?) {
          case 'init':
            labels = (message['labels'] as List).cast<String>();
            interpreter = Interpreter.fromBuffer(
              message['modelBytes'] as Uint8List,
            );
            // 打印模型张量契约，便于在 CI / 真机日志里核对模型是否匹配
            // 期望：输入 1×300×300×3；输出 4 个张量（固定顺序）
            _logModelContract(interpreter);
            mainSendPort.send(<String, dynamic>{'type': 'initDone'});
          case 'detect':
            if (paused || interpreter == null) {
              mainSendPort.send(<String, dynamic>{
                'type': 'result',
                'objects': const <Map<String, dynamic>>[],
              });
              return;
            }
            final objects = _runDetection(
              interpreter!,
              labels,
              message['payload'] as Map<String, dynamic>,
            );
            mainSendPort.send(<String, dynamic>{'type': 'result', 'objects': objects});
          case 'pause':
            paused = true;
          case 'resume':
            paused = false;
          case 'dispose':
            interpreter?.close();
            Isolate.exit();
        }
      } catch (e) {
        mainSendPort.send(<String, dynamic>{
          'type': 'error',
          'message': e.toString(),
        });
      }
    });
  }

  /// 打印模型的输入/输出张量形状与类型，用于核对模型契约。
  ///
  /// 期望契约（见 assets/models/README.md）：
  /// - 输入 0：`1 × 300 × 300 × 3`，uint8 或 float32
  /// - 输出 0：`1 × N × 4`  检测框
  /// - 输出 1：`1 × N`      类别 id
  /// - 输出 2：`1 × N`      置信度
  /// - 输出 3：`1`          有效检测数
  ///
  /// 只使用 `getInputTensor(int)` / `getOutputTensor(int)` 这两个确定的 API
  /// （输出张量个数未知，逐下标试探直到越界抛错为止）。
  static void _logModelContract(Interpreter interpreter) {
    try {
      final sb = StringBuffer('[TFLite] 模型契约：');
      final in0 = interpreter.getInputTensor(0);
      sb.write(' 输入[0] shape=${in0.shape} type=${in0.type}');

      var outCount = 0;
      for (var i = 0; i < 8; i++) {
        try {
          final t = interpreter.getOutputTensor(i);
          sb.write(' 输出[$i] shape=${t.shape} type=${t.type}');
          outCount++;
        } catch (_) {
          break; // 越界即说明输出张量到此为止
        }
      }

      final s = in0.shape;
      if (s.length != 4 || s[1] != inputSize || s[2] != inputSize || s[3] != 3) {
        sb.write(' [警告] 输入形状与期望的 1×$inputSize×$inputSize×3 不一致！');
      }
      if (outCount != 4) {
        sb.write(' [警告] 输出张量数量为 $outCount（期望 4），解析结果可能错位！');
      }
      debugPrint(sb.toString());
    } catch (e) {
      debugPrint('[TFLite] 读取模型契约失败: $e');
    }
  }

  /// 执行一次物体检测（后台 Isolate 内）。
  ///
  /// 输出 objects 的坐标为**旋转校正后（竖直方向）的归一化坐标**，
  /// 镜像与预览裁剪由主 Isolate 的 CoordinateMapper 完成。
  static List<Map<String, dynamic>> _runDetection(
    Interpreter interpreter,
    List<String> labels,
    Map<String, dynamic> payload,
  ) {
    final rgbBytes = payload['rgbBytes'] as Uint8List;
    final srcWidth = payload['width'] as int;
    final srcHeight = payload['height'] as int;
    final quarterTurns = payload['quarterTurns'] as int;

    // 1) resize 到模型输入 300×300（最近邻；归一化坐标在均匀缩放下不变）
    final isUint8 =
        interpreter.getInputTensor(0).type == TensorType.uint8;
    final input = isUint8
        ? Uint8List(inputSize * inputSize * 3)
        : List.generate(
            1,
            (_) => List.generate(
              inputSize,
              (_) => List.generate(
                inputSize,
                (_) => List.filled(3, 0.0),
                growable: false,
              ),
              growable: false,
            ),
            growable: false,
          ) as Object;

    final px = rgbBytes.length ~/ (srcWidth * srcHeight);
    for (var y = 0; y < inputSize; y++) {
      final sy = (y * srcHeight ~/ inputSize).clamp(0, srcHeight - 1);
      for (var x = 0; x < inputSize; x++) {
        final sx = (x * srcWidth ~/ inputSize).clamp(0, srcWidth - 1);
        final srcIdx = (sy * srcWidth + sx) * px;
        final di = (y * inputSize + x) * 3;
        if (isUint8) {
          final dst = input as Uint8List;
          dst[di] = rgbBytes[srcIdx];
          dst[di + 1] = rgbBytes[srcIdx + 1];
          dst[di + 2] = rgbBytes[srcIdx + 2];
        } else {
          final dst = input as List<List<List<List<double>>>>;
          dst[0][y][x][0] = rgbBytes[srcIdx] / 255.0;
          dst[0][y][x][1] = rgbBytes[srcIdx + 1] / 255.0;
          dst[0][y][x][2] = rgbBytes[srcIdx + 2] / 255.0;
        }
      }
    }

    // 2) 运行推理（SSD MobileNetV1 输出 4 张量，顺序见 assets/models/README）
    final maxDetections = interpreter.getOutputTensor(0).shape.isNotEmpty
        ? interpreter.getOutputTensor(0).shape[1]
        : 10;
    final boxes = List.generate(
      1,
      (_) => List.generate(maxDetections, (_) => List.filled(4, 0.0)),
      growable: false,
    );
    final classes = List.generate(
      1,
      (_) => List.filled(maxDetections, 0.0),
      growable: false,
    );
    final scores = List.generate(
      1,
      (_) => List.filled(maxDetections, 0.0),
      growable: false,
    );
    final numDetections = List.filled(1, 0.0);

    final outputs = <int, Object>{
      0: boxes,
      1: classes,
      2: scores,
      3: numDetections,
    };
    interpreter.runForMultipleInputs([input], outputs);

    // 3) 解析结果：过滤低置信度 → 旋转校正 → 输出 Map 列表
    final count = (numDetections[0] as num).toInt().clamp(0, maxDetections);
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final score = (scores[0][i] as num).toDouble();
      if (score < AppConstants.objectConfidenceThreshold) continue;

      final box = boxes[0][i];
      // SSD 输出顺序：ymin / xmin / ymax / xmax（归一化，传感器方向）
      var rect = Rect01.fromLTWH(box[1], box[0], box[3] - box[1], box[2] - box[0]);
      // 旋转校正到竖直方向（纯函数，位于 geometry.dart）
      rect = rotateQuarterTurns(rect, quarterTurns);

      final classId = (classes[0][i] as num).toInt();
      final label = classId >= 0 && classId < labels.length
          ? (labels[classId] == 'placeholder' ? 'object' : labels[classId])
          : 'object';

      results.add(<String, dynamic>{
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
        'label': label,
        'confidence': score,
      });
    }
    return results;
  }
}
