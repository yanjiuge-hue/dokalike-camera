import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../features/filters/data/filter_catalog.dart';
import '../features/modes/mode_controller.dart';
import '../features/modes/timelapse_controller.dart';
import '../models/filter_preset.dart';
import '../services/camera_service.dart';
import '../services/coordinate_mapper.dart';
import '../services/detection_pipeline.dart';
import '../services/face_detection_service.dart';
import '../services/filter_pipeline.dart';
import '../services/inference_isolate.dart';
import '../services/permission_service.dart';
import '../services/photo_repository.dart';
import '../services/settings_repository.dart';
import '../services/share_service.dart';

// ===================== Service Providers（DI 注册中心，共享知识 #3）=====================

/// 相机服务
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 坐标映射器
final coordinateMapperProvider = Provider<CoordinateMapper>((ref) {
  return CoordinateMapper();
});

/// ML Kit 人脸检测服务
final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  final service = FaceDetectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// TFLite 推理 Isolate
final inferenceIsolateProvider = Provider<InferenceIsolate>((ref) {
  final isolate = InferenceIsolate();
  ref.onDispose(() => isolate.dispose());
  return isolate;
});

/// 检测管线（节流 + 人脸/物体合流）
final detectionPipelineProvider = Provider<DetectionPipeline>((ref) {
  final pipeline = DetectionPipeline(
    cameraService: ref.watch(cameraServiceProvider),
    faceDetectionService: ref.watch(faceDetectionServiceProvider),
    inferenceIsolate: ref.watch(inferenceIsolateProvider),
    coordinateMapper: ref.watch(coordinateMapperProvider),
  );
  ref.onDispose(() => pipeline.dispose());
  return pipeline;
});

/// 落盘滤镜管线
final filterPipelineProvider = Provider<FilterPipeline>((ref) {
  return FilterPipeline();
});

/// 照片仓库
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository();
});

/// 设置仓库
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// 权限服务
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// 分享服务
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});

/// 滤镜目录（8 款原创滤镜 + 原图）
final filterCatalogProvider = Provider<List<FilterPreset>>((ref) {
  return FilterCatalog.all;
});

/// 拍摄模式编排器
final modeControllerProvider = Provider<ModeController>((ref) {
  return ModeController(cameraService: ref.watch(cameraServiceProvider));
});

/// 延时摄影控制器
final timelapseControllerProvider = Provider<TimelapseController>((ref) {
  final controller = TimelapseController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

// ===================== 传感器：水平仪横滚角（A-8）=====================

/// 设备横滚角流（度）：由加速度计推算，已做轻度平滑。
///
/// 竖屏持机时 roll=0；左右倾斜为正/负角度。仅用于水平仪与
/// HorizonRule（构图引擎消费 FrameMeta.rollAngleDeg）。
final rollAngleStreamProvider = StreamProvider<double>((ref) {
  final controller = StreamController<double>.broadcast();
  double smoothed = 0;
  StreamSubscription<AccelerometerEvent>? sub;
  var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  sub = accelerometerEventStream().listen((event) {
    // 竖屏持机：重力沿 -y；横滚角 = atan2(x, -y)
    final roll = _rollDegrees(event.x, event.y);
    smoothed = smoothed * 0.7 + roll * 0.3;
    final now = DateTime.now();
    if (now.difference(lastEmit) >= const Duration(milliseconds: 50)) {
      lastEmit = now;
      controller.add(smoothed);
    }
  });

  controller.onCancel = () => sub?.cancel();
  return controller.stream;
});

double _rollDegrees(double x, double y) {
  // y 接近 0（横持）时 atan2 不稳定，clamp 分母避免跳变
  final denom = y.abs() < 0.1 ? (y >= 0 ? 0.1 : -0.1) : y;
  final rad = (x == 0 && y == 0) ? 0.0 : math.atan2(x, -denom);
  return rad * 180 / math.pi;
}
