import 'package:flutter/material.dart';

import '../../../providers/camera_provider.dart';

/// 延时拍摄进度浮层（PRD §5.5：剩余时长/进度环 + 中途取消）。
///
/// 说明：本文件为架构清单外新增的展示组件（属 T05「mode_bar 集成」的
/// 配套 UI），逻辑全部委托 TimelapseController / CameraNotifier。
class TimelapseOverlay extends StatelessWidget {
  const TimelapseOverlay({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final TimelapseProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress.progress,
                    color: const Color(0xFF3DDC97),
                    backgroundColor: Colors.white12,
                    strokeWidth: 6,
                  ),
                  Center(
                    child: Text(
                      '${progress.captured}/${progress.total}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '延时连拍中…',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}
