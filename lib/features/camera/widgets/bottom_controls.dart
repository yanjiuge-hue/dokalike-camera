import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/photo.dart';
import '../../../providers/camera_provider.dart';

/// 底部控制区（PRD §5.1）：相册入口（最新缩略图）/ 快门（居中放大）/ 前后摄翻转。
class BottomControls extends ConsumerWidget {
  const BottomControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraProvider);
    final notifier = ref.read(cameraProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ===== 左：相册入口（最新一张缩略图，P0-3）=====
          _AlbumEntry(lastPhoto: cameraState.lastPhoto),

          // ===== 中：快门（居中放大，P0-2）=====
          _ShutterButton(
            isCapturing: cameraState.isCapturing,
            isReady: cameraState.isReady,
            onTap: () => notifier.capture(),
          ),

          // ===== 右：前后摄翻转（P0-2）=====
          _RoundIconButton(
            icon: Icons.cameraswitch_outlined,
            onTap: cameraState.cameraCount > 1
                ? () => notifier.switchCamera()
                : null,
          ),
        ],
      ),
    );
  }
}

/// 相册入口：显示最新一张照片缩略图（无照片时显示占位图标）。
class _AlbumEntry extends StatelessWidget {
  const _AlbumEntry({required this.lastPhoto});

  final Photo? lastPhoto;

  @override
  Widget build(BuildContext context) {
    final thumbPath = lastPhoto?.thumbnailPath;
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/gallery'),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          color: Colors.white10,
          image: thumbPath != null
              ? DecorationImage(
                  image: FileImage(File(thumbPath)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: thumbPath == null
            ? const Icon(Icons.photo_library_outlined,
                color: Colors.white54, size: 24)
            : null,
      ),
    );
  }
}

/// 快门按钮：按下缩放动画 + 拍摄中状态。
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.isCapturing,
    required this.isReady,
    required this.onTap,
  });

  final bool isCapturing;
  final bool isReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReady ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: isCapturing ? 66 : 74,
        height: isCapturing ? 66 : 74,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ColoredBox(
            color: isCapturing ? Colors.white54 : AppTheme.seed,
          ),
        ),
      ),
    );
  }
}

/// 圆形图标按钮。
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white10,
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
