import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/enums.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../settings/settings_sheet.dart';

/// 顶部状态栏（PRD §5.1）：闪光灯 / 网格线 / 分辨率 / 设置。
///
/// 小图标行叠加于预览之上，不遮挡取景；各图标均有明确状态反馈。
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isReady = ref.watch(
        cameraProvider.select((s) => s.isReady));

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ===== 闪光灯（三态循环）=====
            _TopBarButton(
              icon: switch (settings.flashMode) {
                FlashMode3.auto => Icons.flash_auto,
                FlashMode3.on => Icons.flash_on,
                FlashMode3.off => Icons.flash_off,
              },
              label: settings.flashMode.label,
              onTap: isReady
                  ? () => ref.read(cameraProvider.notifier).cycleFlashMode()
                  : null,
            ),
            const Spacer(),

            // ===== 网格线 / 构图辅助（一键开关整体 + 样式循环）=====
            _TopBarButton(
              icon: switch (settings.gridStyle) {
                GridStyle.none => Icons.grid_off,
                GridStyle.thirds => Icons.grid_3x3,
                GridStyle.golden => Icons.grid_goldenratio,
              },
              label: settings.gridStyle.label,
              onTap: () async {
                await ref.read(settingsProvider.notifier).cycleGridStyle();
              },
            ),
            const Spacer(),

            // ===== 分辨率档位（A-3：iOS 仅高/标准两档）=====
            _ResolutionButton(),
            const Spacer(),

            // ===== 设置（唯一设置入口，P2-5）=====
            _TopBarButton(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => showSettingsSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分辨率档位按钮（弹层选择）。
class _ResolutionButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // A-3：iOS 端仅提供 高 / 标准 两档
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final options = isIOS
        ? const [ResolutionPreset.standard, ResolutionPreset.high]
        : ResolutionPreset.values;

    return PopupMenuButton<ResolutionPreset>(
      color: const Color(0xFF17181C),
      onSelected: (preset) =>
          ref.read(cameraProvider.notifier).setResolution(preset),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: TextStyle(
                color: option == settings.resolution
                    ? const Color(0xFF3DDC97)
                    : Colors.white,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.high_quality_outlined,
                color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              settings.resolution.label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
