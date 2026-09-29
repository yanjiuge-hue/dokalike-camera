import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/enums.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/settings_provider.dart';

/// 模式切换条（PRD §5.5）：普通 | 人像 | 夜景 | 延时。
///
/// 当前模式高亮胶囊样式；切换即时生效且持久化（P1-5）。
class ModeBar extends ConsumerWidget {
  const ModeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(cameraProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final mode in ShootMode.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => notifier.changeShootMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: settings.shootMode == mode
                        ? AppTheme.seed
                        : Colors.black45,
                    border: Border.all(
                      color: settings.shootMode == mode
                          ? AppTheme.seed
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: settings.shootMode == mode
                          ? Colors.black
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: settings.shootMode == mode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
