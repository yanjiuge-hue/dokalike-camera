import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';

import '../models/enums.dart';

/// 相机服务：CameraController 生命周期、拍照、模式切换。
///
/// 注意：本文件使用 `import ... as cam` 别名以避免 camera 插件的
/// `ResolutionPreset` 与业务模型 [ResolutionPreset] 重名。
class CameraService {
  CameraController? controller;

  /// 设备相机列表（判断多镜头用，A-5）
  List<cam.CameraDescription> cameras = const [];

  /// 当前相机索引
  int cameraIndex = 0;

  /// 帧流广播（DetectionPipeline 订阅）
  final StreamController<cam.CameraImage> _imageController =
      StreamController<cam.CameraImage>.broadcast();

  bool _streaming = false;
  bool _detectionPaused = false;

  cam.ResolutionPreset? _lastPreset;

  bool get isReady => controller?.value.isInitialized ?? false;
  bool get isStreaming => _streaming;
  bool get isFrontCamera =>
      controller?.description.lensDirection == cam.CameraLensDirection.front;

  /// 是否具备多镜头（粗略判定：相机数 > 2，A-5；精确判定可按 name 过滤）
  bool get hasMultiLens => cameras.length > 2;

  /// 帧流
  Stream<cam.CameraImage> get imageStream => _imageController.stream;

  /// 当前预览宽高比（宽/高，竖屏预览）
  double get previewAspect {
    final size = controller?.value.previewSize;
    if (size == null) return 9 / 16;
    // previewSize 为横屏传感器尺寸，竖屏使用时需交换
    return size.height / size.width;
  }

  /// 传感器方向（度）：0 / 90 / 180 / 270
  int get sensorOrientation =>
      controller?.description.sensorOrientation ?? 0;

  /// 图像相对预览的旋转（顺时针 90° 的整数倍）
  int get previewQuarterTurns {
    final front = isFrontCamera;
    switch (sensorOrientation) {
      case 90:
        return front ? 3 : 1;
      case 180:
        return 2;
      case 270:
        return front ? 1 : 3;
      default:
        return 0;
    }
  }

  /// 初始化相机（列表 + 控制器）。[preferredIndex] 用于前后摄切换。
  Future<void> initialize(
    ResolutionPreset preset, {
    int preferredIndex = 0,
  }) async {
    cameras = await cam.availableCameras();
    if (cameras.isEmpty) {
      throw StateError('未检测到可用相机');
    }
    cameraIndex = preferredIndex.clamp(0, cameras.length - 1);
    await _createController(_mapPreset(preset));
  }

  /// 重建控制器（切换前后摄 / 分辨率时复用）。
  Future<void> _createController(cam.ResolutionPreset preset) async {
    final wasStreaming = _streaming;
    await _stopStreaming();

    final old = controller;
    controller = null;
    await old?.dispose();

    final newController = cam.CameraController(
      cameras[cameraIndex],
      preset,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.yuv420,
    );
    _lastPreset = preset;
    controller = newController;
    await newController.initialize();

    if (wasStreaming) {
      await _startStreaming();
    }
  }

  /// 前后摄切换
  Future<void> switchCamera() async {
    if (cameras.length < 2) return;
    cameraIndex = (cameraIndex + 1) % cameras.length;
    await _createController(_lastPreset ?? cam.ResolutionPreset.high);
  }

  /// 切换分辨率档位
  Future<void> setResolution(ResolutionPreset preset) async {
    await _createController(_mapPreset(preset));
  }

  /// 业务档位 → camera 插件档位
  cam.ResolutionPreset _mapPreset(ResolutionPreset preset) {
    return switch (preset) {
      ResolutionPreset.standard => cam.ResolutionPreset.medium,
      ResolutionPreset.high => cam.ResolutionPreset.high,
      ResolutionPreset.veryHigh => cam.ResolutionPreset.veryHigh,
      ResolutionPreset.max => cam.ResolutionPreset.max,
    };
  }

  /// 拍照：返回原始 JPEG 字节（拍照瞬间帧流保持暂停由调用方控制）。
  Future<Uint8List> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      throw StateError('相机尚未初始化');
    }
    final file = await c.takePicture();
    final bytes = await file.readAsBytes();
    // 拍照缓存文件已读入内存，及时清理避免占用存储
    unawaited(_deleteQuietly(file.path));
    return bytes;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('清理拍照缓存失败（忽略）: $e');
    }
  }

  /// 设置闪光灯三态
  Future<void> setFlashMode(FlashMode3 mode) async {
    final c = controller;
    if (c == null) return;
    final mapped = switch (mode) {
      FlashMode3.auto => cam.FlashMode.auto,
      FlashMode3.on => cam.FlashMode.always,
      FlashMode3.off => cam.FlashMode.off,
    };
    await c.setFlashMode(mapped);
  }

  /// 设置曝光补偿（夜景模式用，A-7）。超出设备范围时自动夹取。
  Future<void> setExposureOffset(double offset) async {
    final c = controller;
    if (c == null) return;
    try {
      final min = await c.getMinExposureOffset();
      final max = await c.getMaxExposureOffset();
      await c.setExposureOffset(offset.clamp(min, max));
    } catch (e) {
      // 部分设备不支持曝光补偿：静默降级
      debugPrint('曝光补偿不可用（忽略）: $e');
    }
  }

  /// 开始输出帧流
  Future<void> startStreaming() async {
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    final c = controller;
    if (c == null || !c.value.isInitialized || _streaming) return;
    _streaming = true;
    await c.startImageStream(_imageController.add);
  }

  /// 停止输出帧流
  Future<void> stopStreaming() async {
    await _stopStreaming();
  }

  Future<void> _stopStreaming() async {
    if (!_streaming) return;
    _streaming = false;
    final c = controller;
    if (c != null && c.value.isInitialized) {
      try {
        await c.stopImageStream();
      } catch (e) {
        // 控制器销毁过程中 stopImageStream 可能抛出，忽略
        debugPrint('停止帧流异常（忽略）: $e');
      }
    }
  }

  /// 拍照瞬间暂停检测（释放 CPU 给拍摄管线，见时序图 4.3）。
  Future<void> pauseDetection() async {
    _detectionPaused = true;
    await _stopStreaming();
  }

  /// 拍照完成后恢复检测。
  Future<void> resumeDetection() async {
    if (!_detectionPaused) return;
    _detectionPaused = false;
    await _startStreaming();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _stopStreaming();
    await _imageController.close();
    await controller?.dispose();
    controller = null;
  }
}
