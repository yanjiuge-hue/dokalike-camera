import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/constants/app_constants.dart';
import '../core/constants/asset_paths.dart';
import '../core/utils/debouncer.dart';
import '../core/utils/geometry.dart';
import '../models/detection_result.dart';
import '../models/enums.dart';
import 'camera_service.dart';
import 'coordinate_mapper.dart';
import 'face_detection_service.dart';
import 'inference_isolate.dart';

/// 检测管线（P0-4 / P0-5 核心）：节流调度 + 人脸/物体结果合流。
///
/// 帧流水线（架构 §1.3）：
/// ```
/// CameraImage 流 (30fps)
///   → Throttler（200ms + busy 丢帧）
///   ├─ FaceDetectionService（async，原生线程）
///   ├─ InferenceIsolate（后台 Isolate）
///   └─ CoordinateMapper（坐标归一化/镜像/裁剪）
///   → DetectionResult（含 SceneFeatures）
/// ```
/// 单帧流水线全程不产生阻塞 UI 的 await 链：检测回调只更新 Provider 状态。
class DetectionPipeline {
  DetectionPipeline({
    required this.cameraService,
    required this.faceDetectionService,
    required this.inferenceIsolate,
    required this.coordinateMapper,
  });

  final CameraService cameraService;
  final FaceDetectionService faceDetectionService;
  final InferenceIsolate inferenceIsolate;
  final CoordinateMapper coordinateMapper;

  final StreamController<DetectionResult> _resultsController =
      StreamController<DetectionResult>.broadcast();

  /// 检测结果流（CompositionNotifier 订阅）
  Stream<DetectionResult> get results => _resultsController.stream;

  final Throttler _throttler =
      Throttler(interval: AppConstants.frameSampleInterval);

  StreamSubscription<cam.CameraImage>? _sub;
  bool _busy = false;
  bool _running = false;
  bool _modelLoaded = false;
  bool _modelLoadAttempted = false;

  bool get isRunning => _running;
  bool get isModelAvailable => _modelLoaded;

  /// 启动管线：懒加载模型（首次调用时才 spawn Isolate，冷启动优化）+ 订阅帧流。
  Future<void> start() async {
    if (_running) return;
    _running = true;
    unawaited(_ensureModelLoaded());
    await cameraService.startStreaming();
    _sub?.cancel();
    _sub = cameraService.imageStream.listen(
      (frame) => unawaited(_onFrame(frame)),
      onError: (Object e) => debugPrint('帧流异常: $e'),
    );
  }

  /// 停止管线
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    _sub = null;
    await cameraService.stopStreaming();
  }

  /// 拍照瞬间暂停后台推理（释放 CPU 给拍摄管线，时序图 4.3）。
  /// 与 [CameraService.pauseDetection] 配对使用：后者停帧流，本方法只
  /// 暂停 Isolate 内的推理。
  void pauseIsolate() => inferenceIsolate.pause();

  /// 拍照完成后恢复后台推理。
  void resumeIsolate() => inferenceIsolate.resume();

  /// 释放全部资源
  Future<void> dispose() async {
    await stop();
    await _resultsController.close();
    faceDetectionService.dispose();
    inferenceIsolate.dispose();
  }

  /// 懒加载 TFLite 模型：主 Isolate 读字节 → init 消息传入后台 Isolate。
  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded || _modelLoadAttempted) return;
    _modelLoadAttempted = true;
    try {
      final modelBytes =
          (await rootBundle.load(AssetPaths.modelFile)).buffer.asUint8List();
      final labels = (await rootBundle.loadString(AssetPaths.labelsFile))
          .split('\n')
          .map((line) => line.trim())
          .toList(growable: false);
      await inferenceIsolate.spawn(modelBytes, labels);
      _modelLoaded = true;
      debugPrint('物体检测模型加载完成，构图辅助全量模式');
    } catch (e) {
      // 模型缺失：降级为仅人脸检测，不阻塞预览
      debugPrint('模型加载失败，构图辅助降级为仅人脸检测: $e');
    }
  }

  /// 单帧处理：节流 + 并行检测 + 合流。
  Future<void> _onFrame(cam.CameraImage frame) async {
    // 200ms 节流 + busy 丢帧（P0-4）
    if (_busy || !_throttler.shouldCall()) return;
    _busy = true;
    try {
      final quarterTurns = cameraService.previewQuarterTurns;
      final isFront = cameraService.isFrontCamera;
      // 旋转校正后（竖直方向）的宽高
      final uprightWidth = quarterTurns.isOdd ? frame.height : frame.width;
      final uprightHeight = quarterTurns.isOdd ? frame.width : frame.height;

      final meta = FrameMeta(
        width: uprightWidth,
        height: uprightHeight,
        quarterTurns: quarterTurns,
        isFrontCamera: isFront,
        previewAspect: cameraService.previewAspect,
      );

      // YUV→RGB（为 Isolate 准备 payload，同时得到平均 R/B 用于色温估计）
      final rgb = _yuv420ToRgb(frame);

      // 并行：人脸（原生线程）+ 物体（后台 Isolate）
      final facesFuture =
          faceDetectionService.detect(frame, coordinateMapper.currentRotation);
      final objectsFuture = _detectObjects(rgb, frame, quarterTurns, isFront);

      final faces = await facesFuture;
      var objects = await objectsFuture ?? const <ObjectBox>[];

      // 坐标归一化：人脸已归一化（竖直方向）→ 镜像+裁剪；物体同样处理
      final mappedFaces = faces
          .map((f) => FaceBox(
                rect: coordinateMapper.mapNormalized(f.rect, meta),
                smilingProbability: f.smilingProbability,
              ))
          .toList(growable: false);
      objects = objects
          .map((o) => ObjectBox(
                rect: coordinateMapper.mapNormalized(o.rect, meta),
                label: o.label,
                confidence: o.confidence,
              ))
          .toList(growable: false);

      // 场景特征（AI 滤镜推荐输入）：亮度只计算一次
      final luminance = _estimateLuminance(frame);
      final features = SceneFeatures(
        luminance: luminance,
        colorTemperature: _colorTempIndex(rgb.avgR, rgb.avgB),
        faceCount: mappedFaces.length,
        sceneType: _classifyScene(mappedFaces.length, objects, luminance),
      );

      _resultsController.add(DetectionResult(
        faces: mappedFaces,
        objects: objects,
        features: features,
        meta: meta,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      // 单帧失败静默丢弃，不影响预览
      debugPrint('检测帧处理失败（丢帧）: $e');
    } finally {
      _busy = false;
    }
  }

  Future<List<ObjectBox>?> _detectObjects(
    _RgbFrame rgb,
    cam.CameraImage frame,
    int quarterTurns,
    bool isFront,
  ) async {
    if (!inferenceIsolate.isReady) return null;
    final payload = FramePayload(
      rgbBytes: rgb.bytes,
      width: frame.width,
      height: frame.height,
      quarterTurns: quarterTurns,
      isFrontCamera: isFront,
    );
    return inferenceIsolate.detect(payload);
  }

  // ===================== YUV → RGB 与场景特征 =====================

  /// YUV420 转 RGB（3 字节/像素），同时累计平均 R/B。
  _RgbFrame _yuv420ToRgb(cam.CameraImage frame) {
    final width = frame.width;
    final height = frame.height;
    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    // 修正：camera 0.11 的 Plane 只暴露 bytes / bytesPerRow / width / height，
    // 已经移除 pixelStride（故报 undefined_getter），下游索引又要求 int。
    // 这里按「行跨距 ÷ 该平面每行像素数」反推像素跨距：
    //   · Y 平面每行 width 个像素            → 通常是 1；
    //   · U/V 平面水平 2:1 下采样，每行 width ~/ 2 个像素
    //     → NV21/NV12 交错存储时推导出 2，I420 平面存储时推导出 1，
    //       与原先 pixelStride 的取值一致。
    final yPixStride = _pixelStride(yRowStride, width);
    final uPixStride = _pixelStride(uRowStride, width ~/ 2);
    final vPixStride = _pixelStride(vRowStride, width ~/ 2);

    final bytes = Uint8List(width * height * 3);
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    var sumR = 0.0, sumB = 0.0;
    var idx = 0;
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final y = yBytes[row * yRowStride + col * yPixStride];
        final uvRow = row >> 1;
        final uvCol = col >> 1;
        final u = uBytes[uvRow * uRowStride + uvCol * uPixStride];
        final v = vBytes[uvRow * vRowStride + uvCol * vPixStride];

        // BT.601 全范围 YUV → RGB
        var r = y + 1.402 * (v - 128);
        var g = y - 0.344136 * (u - 128) - 0.714136 * (v - 128);
        var b = y + 1.772 * (u - 128);
        r = r < 0 ? 0 : (r > 255 ? 255 : r);
        g = g < 0 ? 0 : (g > 255 ? 255 : g);
        b = b < 0 ? 0 : (b > 255 ? 255 : b);

        bytes[idx++] = r.round();
        bytes[idx++] = g.round();
        bytes[idx++] = b.round();
        sumR += r;
        sumB += b;
      }
    }

    final pixelCount = (width * height).toDouble();
    return _RgbFrame(
      bytes: bytes,
      avgR: sumR / pixelCount,
      avgB: sumB / pixelCount,
    );
  }

  /// 由行跨距反推像素跨距（camera 0.11 移除 Plane.pixelStride 后的替代实现）。
  ///
  /// [pixelsPerRow] 为该平面每行实际像素数：Y 平面 = 图像宽，U/V 平面 = 宽的一半。
  /// 结果最小为 1，避免除零或跨距为 0 导致索引恒取首像素。
  static int _pixelStride(int rowStride, int pixelsPerRow) {
    if (rowStride <= 0 || pixelsPerRow <= 0) return 1;
    final stride = rowStride ~/ pixelsPerRow;
    return stride < 1 ? 1 : stride;
  }

  /// 亮度估计：Y 平面抽样平均（/255）。
  double _estimateLuminance(cam.CameraImage frame) {
    final yPlane = frame.planes[0].bytes;
    var sum = 0.0;
    var count = 0;
    // 每 16 个像素抽 1 个，开销极小
    for (var i = 0; i < yPlane.length; i += 16) {
      sum += yPlane[i];
      count++;
    }
    return count == 0 ? 0.5 : (sum / count) / 255.0;
  }

  /// 色温指数 [0,1]：0 偏冷、0.5 中性、1 偏暖。
  double _colorTempIndex(double avgR, double avgB) {
    final diff = (avgR - avgB) / 255.0; // 约 [-0.4, 0.4]
    return (0.5 + diff * 1.25).clamp(0.0, 1.0);
  }

  /// 场景分类（P1-3 规则版输入）。
  SceneType _classifyScene(
    int faceCount,
    List<ObjectBox> objects,
    double luminance,
  ) {
    if (faceCount > 0) return SceneType.portrait;
    if (luminance < 0.3) return SceneType.night;
    for (final o in objects) {
      if (kFoodLabels.contains(o.label)) return SceneType.food;
    }
    if (objects.isNotEmpty) return SceneType.landscape;
    return SceneType.other;
  }
}

/// YUV→RGB 转换结果。
class _RgbFrame {
  const _RgbFrame({required this.bytes, required this.avgR, required this.avgB});

  final Uint8List bytes;
  final double avgR;
  final double avgB;
}
