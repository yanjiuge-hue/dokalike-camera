import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/filters/data/filter_catalog.dart';
import '../models/enums.dart';
import '../models/photo.dart';
import '../services/camera_service.dart';
import '../services/detection_pipeline.dart';
import '../services/filter_pipeline.dart';
import '../services/photo_repository.dart';
import 'composition_provider.dart';
import 'filter_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

/// 相机状态机。
enum CameraStatus { idle, initializing, ready, permissionDenied, error }

class CameraState {
  const CameraState({
    this.status = CameraStatus.idle,
    this.error,
    this.cameraCount = 0,
    this.hasMultiLens = false,
    this.isFrontCamera = false,
    this.isCapturing = false,
    this.lastPhoto,
    this.lastCaptureAt,
    this.timelapse,
  });

  final CameraStatus status;
  final String? error;
  final int cameraCount;
  final bool hasMultiLens;
  final bool isFrontCamera;
  final bool isCapturing;

  /// 最近一张照片（拍后即览浮层 P2-3 / 相册入口缩略图）
  final Photo? lastPhoto;
  final DateTime? lastCaptureAt;

  /// 延时拍摄进度（null = 未在延时模式）
  final TimelapseProgress? timelapse;

  bool get isReady => status == CameraStatus.ready;

  CameraState copyWith({
    CameraStatus? status,
    String? error,
    int? cameraCount,
    bool? hasMultiLens,
    bool? isFrontCamera,
    bool? isCapturing,
    Photo? lastPhoto,
    DateTime? lastCaptureAt,
    TimelapseProgress? timelapse,
    bool clearError = false,
  }) {
    return CameraState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      cameraCount: cameraCount ?? this.cameraCount,
      hasMultiLens: hasMultiLens ?? this.hasMultiLens,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isCapturing: isCapturing ?? this.isCapturing,
      lastPhoto: lastPhoto ?? this.lastPhoto,
      lastCaptureAt: lastCaptureAt ?? this.lastCaptureAt,
      timelapse: timelapse ?? this.timelapse,
    );
  }
}

/// 延时拍摄进度快照（从 TimelapseController 状态映射）。
class TimelapseProgress {
  const TimelapseProgress({
    required this.running,
    required this.captured,
    required this.total,
  });

  final bool running;
  final int captured;
  final int total;

  double get progress => total == 0 ? 0 : (captured / total).clamp(0.0, 1.0);
  int get remaining => total - captured;
}

/// 相机 Notifier：初始化 / 切换 / 模式 / 拍照全流程编排
/// （时序图 4.1 启动、4.3 拍照、模式切换 P1-5）。
class CameraNotifier extends Notifier<CameraState> {
  StreamSubscription? _timelapseSub;

  @override
  CameraState build() {
    // 延时控制器状态联动（ChangeNotifier → Riverpod state）
    _timelapseSub?.cancel();
    _timelapseSub = ref
        .read(timelapseControllerProvider)
        .addListener(_onTimelapseChanged);
    ref.onDispose(() => _timelapseSub?.cancel());
    return const CameraState();
  }

  void _onTimelapseChanged() {
    final tl = ref.read(timelapseControllerProvider).state;
    if (!tl.running) {
      state = state.copyWith(timelapse: const TimelapseProgress(running: false, captured: 0, total: 0));
      return;
    }
    state = state.copyWith(
      timelapse: TimelapseProgress(
        running: tl.running,
        captured: tl.captured,
        total: tl.total,
      ),
    );
  }

  CameraService get _camera => ref.read(cameraServiceProvider);
  DetectionPipeline get _pipeline => ref.read(detectionPipelineProvider);
  FilterPipeline get _filterPipeline => ref.read(filterPipelineProvider);
  PhotoRepository get _photoRepo => ref.read(photoRepositoryProvider);

  // ===================== 初始化（时序图 4.1）=====================

  /// 权限 → 相机初始化 → 应用设置 → 按需启动检测。
  Future<void> initialize() async {
    if (state.isReady || state.status == CameraStatus.initializing) return;
    state = state.copyWith(status: CameraStatus.initializing, clearError: true);

    final permission = ref.read(permissionServiceProvider);
    if (!await permission.ensureCameraPermission()) {
      state = state.copyWith(status: CameraStatus.permissionDenied);
      return;
    }

    try {
      final settings = ref.read(settingsProvider);
      await _camera.initialize(settings.resolution);
      ref
          .read(coordinateMapperProvider)
          .updateDescription(_camera.controller?.description);
      await _camera.setFlashMode(settings.flashMode);
      await _applyModeToCamera(settings.shootMode);

      state = state.copyWith(
        status: CameraStatus.ready,
        cameraCount: _camera.cameras.length,
        hasMultiLens: _camera.hasMultiLens,
        isFrontCamera: _camera.isFrontCamera,
        clearError: true,
      );

      // 构图辅助默认开启（P0-7）→ 启动检测（模型懒加载在 pipeline.start 内）
      if (settings.compositionAssistEnabled) {
        await _pipeline.start();
      }
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        error: '相机初始化失败: $e',
      );
    }
  }

  // ===================== 前后摄 / 闪光灯 / 分辨率 =====================

  /// 前后摄切换（P0-2）。
  Future<void> switchCamera() async {
    if (!state.isReady) return;
    await _pipeline.stop();
    try {
      await _camera.switchCamera();
      ref
          .read(coordinateMapperProvider)
          .updateDescription(_camera.controller?.description);
      await _camera.setFlashMode(ref.read(settingsProvider).flashMode);
      await _applyModeToCamera(ref.read(settingsProvider).shootMode);
      state = state.copyWith(isFrontCamera: _camera.isFrontCamera);
    } catch (e) {
      state = state.copyWith(error: '切换相机失败: $e');
    } finally {
      if (ref.read(settingsProvider).compositionAssistEnabled) {
        await _pipeline.start();
      }
    }
  }

  /// 循环切换闪光灯三态（auto → on → off，P0-2）。
  Future<void> cycleFlashMode() async {
    await ref.read(settingsProvider.notifier).cycleFlashMode();
    await _camera.setFlashMode(ref.read(settingsProvider).flashMode);
  }

  /// 切换分辨率档位（P0-2）。
  Future<void> setResolution(ResolutionPreset preset) async {
    if (!state.isReady) return;
    await _pipeline.stop();
    try {
      await ref.read(settingsProvider.notifier).setResolution(preset);
      await _camera.setResolution(preset);
    } catch (e) {
      state = state.copyWith(error: '切换分辨率失败: $e');
    } finally {
      if (ref.read(settingsProvider).compositionAssistEnabled) {
        await _pipeline.start();
      }
    }
  }

  // ===================== 拍摄模式（P1-5，T05 集成）=====================

  /// 切换拍摄模式：设置持久化 + 硬件参数 + 滤镜联动 + 延时编排。
  Future<void> changeShootMode(ShootMode mode) async {
    final prev = ref.read(settingsProvider).shootMode;
    if (prev == mode) {
      if (mode == ShootMode.timelapse && state.timelapse?.running != true) {
        startTimelapse();
      }
      return;
    }

    await ref.read(settingsProvider.notifier).setShootMode(mode);
    await _applyModeToCamera(mode);

    // 夜景联动「夜港」滤镜（A-7）
    if (mode == ShootMode.night) {
      await ref
          .read(filterProvider.notifier)
          .setFilter(FilterCatalog.nightPort.id);
    } else if (prev == ShootMode.night) {
      // 离开夜景恢复原图
      await ref
          .read(filterProvider.notifier)
          .setFilter(FilterCatalog.original.id);
    }

    // 延时模式：进入即启动连拍（A-1：定时连拍 MVP）；其余模式取消进行中的连拍
    if (mode == ShootMode.timelapse) {
      startTimelapse();
    } else {
      cancelTimelapse();
    }
  }

  Future<void> _applyModeToCamera(ShootMode mode) async {
    await ref.read(modeControllerProvider).apply(mode);
  }

  /// 启动延时连拍。
  void startTimelapse() {
    ref.read(timelapseControllerProvider).start(onCapture: capture);
  }

  /// 取消延时连拍。
  void cancelTimelapse() {
    ref.read(timelapseControllerProvider).cancel();
  }

  // ===================== 构图辅助开关（P0-7）=====================

  /// 设置层开关变化后的联动（UI 在 toggle 设置后调用）。
  Future<void> onCompositionAssistToggled() async {
    final enabled = ref.read(settingsProvider).compositionAssistEnabled;
    ref.read(compositionProvider.notifier).onEnabledChanged(enabled);
    if (enabled) {
      await _pipeline.start();
    } else {
      await _pipeline.stop();
    }
  }

  // ===================== 拍照全流程（时序图 4.3）=====================

  /// 拍照：暂停检测 → 拍摄 → 滤镜/美颜 → 保存 → 恢复检测。
  ///
  /// 返回保存的 Photo（失败返回 null）。
  Future<Photo?> capture() async {
    if (!state.isReady || state.isCapturing) return null;

    state = state.copyWith(isCapturing: true, clearError: true);
    // 拍照瞬间释放 CPU 给拍摄管线（时序图 4.3）
    await _camera.pauseDetection();
    _pipeline.pauseIsolate();

    try {
      // 1) 拍摄原始 JPEG
      final bytes = await _camera.capture();

      // 2) 滤镜（预览所见 = 落盘所得，共享知识 #2）
      final filterState = ref.read(filterProvider);
      var processed = bytes;
      if (!filterState.isOriginal) {
        final preset = FilterCatalog.byId(filterState.currentId);
        processed = await _filterPipeline.applyToBytes(
          processed,
          preset,
          filterState.strength,
        );
      }

      // 3) 美颜（P1-2：默认轻档，可关；人像/前摄场景同样生效）
      final settings = ref.read(settingsProvider);
      if (settings.beautyLevel != BeautyLevel.off) {
        processed = await _filterPipeline.applyBeauty(
          processed,
          settings.beautyLevel,
        );
      }

      // 4) 保存（文件 + 缩略图 + Hive + 系统相册）
      final size = _camera.controller?.value.previewSize;
      final photo = await _photoRepo.save(
        processed,
        PhotoMeta(
          width: (size?.height ?? 0).round(), // previewSize 为横屏尺寸，竖屏交换
          height: (size?.width ?? 0).round(),
          filterId: filterState.currentId,
          filterStrength: filterState.strength,
          shootMode: settings.shootMode,
        ),
      );

      state = state.copyWith(
        lastPhoto: photo,
        lastCaptureAt: DateTime.now(),
      );
      return photo;
    } catch (e) {
      debugPrint('拍照失败: $e');
      state = state.copyWith(error: '拍照失败: $e');
      return null;
    } finally {
      _pipeline.resumeIsolate();
      await _camera.resumeDetection();
      state = state.copyWith(isCapturing: false);
    }
  }
}

final cameraProvider =
    NotifierProvider<CameraNotifier, CameraState>(CameraNotifier.new);
