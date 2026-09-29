import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/camera_provider.dart';
import '../../providers/composition_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_provider.dart';
import '../filters/data/filter_catalog.dart';
import '../filters/widgets/filter_bar.dart';
import '../filters/widgets/recommend_panel.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/capture_toast.dart';
import 'widgets/composition_overlay.dart';
import 'widgets/mode_bar.dart';
import 'widgets/timelapse_overlay.dart';
import 'widgets/top_bar.dart';

/// 相机主界面（PRD §5.1 线框）：
/// 全屏预览 + 顶部状态栏 + 构图引导层 + 滤镜栏 + 模式条 + 底部控制区。
///
/// 无首页 / 无广告 / 无登录：本页即 App 首页（P0-1）。
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  @override
  void initState() {
    super.initState();
    // 首帧渲染后异步初始化相机（冷启动 ≤1s 目标：先出骨架再就绪）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ===== 预览层（含实时滤镜，P0-8）=====
          _buildPreview(cameraState),

          // ===== 构图引导层（P0-6）=====
          if (settings.compositionAssistEnabled)
            CompositionOverlay(
              hasMultiLens: cameraState.hasMultiLens,
            ),

          // ===== 顶部状态栏（P0-10）=====
          Align(
            alignment: Alignment.topCenter,
            child: TopBar(),
          ),

          // ===== 拍后即览浮层（P2-3）=====
          if (cameraState.lastPhoto != null)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 96, right: 12),
                child: CaptureToast(photo: cameraState.lastPhoto!),
              ),
            ),

          // ===== 延时进度浮层（P1-5）=====
          if (cameraState.timelapse?.running ?? false)
            TimelapseOverlay(
              progress: cameraState.timelapse!,
              onCancel: () =>
                  ref.read(cameraProvider.notifier).cancelTimelapse(),
            ),

          // ===== 底部控制区（滤镜栏 + 模式条 + 快门区）=====
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterBar(
                    onRecommendTap: () => showRecommendPanel(context, ref),
                  ),
                  const ModeBar(),
                  const BottomControls(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ===== 状态覆盖层（初始化 / 权限 / 错误）=====
          if (!cameraState.isReady) _buildStatusLayer(cameraState),
        ],
      ),
    );
  }

  /// 预览：CameraPreview + ColorFiltered 实时滤镜（强度 = 矩阵插值）。
  Widget _buildPreview(CameraState cameraState) {
    final controller =
        ref.watch(cameraServiceProvider).controller;
    if (!cameraState.isReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    // 预览铺满屏幕（scale-to-cover）
    final size = MediaQuery.of(context).size;
    final scale = 1 /
        (controller.value.aspectRatio * (size.width / size.height));
    final preview = cam.CameraPreview(controller);

    final filterState = ref.watch(filterProvider);
    if (filterState.isOriginal || filterState.strength <= 0) {
      return ClipRect(
        child: Transform.scale(
          scale: scale.clamp(1.0, double.infinity),
          child: preview,
        ),
      );
    }

    final preset = FilterCatalog.byId(filterState.currentId);
    final matrix = preset.matrixAt(filterState.strength);
    return ClipRect(
      child: Transform.scale(
        scale: scale.clamp(1.0, double.infinity),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: preview,
        ),
      ),
    );
  }

  /// 初始化中 / 权限拒绝 / 错误 的覆盖层。
  Widget _buildStatusLayer(CameraState cameraState) {
    Widget content;
    switch (cameraState.status) {
      case CameraStatus.initializing:
        content = const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text('正在启动相机…', style: TextStyle(color: Colors.white70)),
          ],
        );
      case CameraStatus.permissionDenied:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text('需要相机权限才能拍摄',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref
                  .read(permissionServiceProvider)
                  .openAppSettingsPage(),
              child: const Text('去系统设置开启'),
            ),
          ],
        );
      case CameraStatus.error:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(cameraState.error ?? '相机初始化失败',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(cameraProvider.notifier).initialize(),
              child: const Text('重试'),
            ),
          ],
        );
      case CameraStatus.idle:
      case CameraStatus.ready:
        return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Colors.black87,
      child: Center(child: content),
    );
  }
}
