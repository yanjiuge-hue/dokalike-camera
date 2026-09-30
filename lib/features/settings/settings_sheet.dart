import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/enums.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/settings_provider.dart';

/// 设置底部面板（P2-5：唯一设置入口）：
/// 构图辅助开关 / 网格样式 / 美颜档 / 分辨率 / 关于与隐私声明。
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final cameraNotifier = ref.read(cameraProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('设置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),

            // ===== 构图辅助开关（P0-7，默认开启）=====
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('构图辅助'),
              subtitle:
                  const Text('三分线 / 黄金分割 / 水平仪 / 主体提示',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
              value: settings.compositionAssistEnabled,
              activeColor: const Color(0xFF3DDC97),
              onChanged: (enabled) async {
                await settingsNotifier.toggleCompositionAssist();
                await cameraNotifier.onCompositionAssistToggled();
              },
            ),

            // ===== 网格样式 =====
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('网格样式'),
              subtitle: Text('当前：${settings.gridStyle.label}',
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
              trailing: SegmentedButton<GridStyle>(
                segments: const [
                  ButtonSegment(value: GridStyle.none, label: Text('关')),
                  ButtonSegment(value: GridStyle.thirds, label: Text('三分')),
                  ButtonSegment(value: GridStyle.golden, label: Text('黄金')),
                ],
                selected: {settings.gridStyle},
                onSelectionChanged: (selection) =>
                    settingsNotifier.setGridStyle(selection.first),
              ),
            ),

            // ===== 美颜档位（A-2：关 / 轻 / 中，默认轻）=====
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('美颜'),
              subtitle: const Text('磨皮保细节，肤色自然',
                  style: TextStyle(fontSize: 12, color: Colors.white38)),
              trailing: SegmentedButton<BeautyLevel>(
                segments: const [
                  ButtonSegment(value: BeautyLevel.off, label: Text('关')),
                  ButtonSegment(value: BeautyLevel.light, label: Text('轻')),
                  ButtonSegment(value: BeautyLevel.medium, label: Text('中')),
                ],
                selected: {settings.beautyLevel},
                onSelectionChanged: (selection) =>
                    settingsNotifier.setBeautyLevel(selection.first),
              ),
            ),

            const Divider(),

            // ===== 关于与隐私（P1-6 / US-9）=====
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('隐私说明'),
              subtitle: Text(
                'AI 全部本地推理，照片仅存本机，无广告、无信息流、无强制登录、'
                '无任何数据上传。',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('版本'),
              trailing: Text('v1.0.0',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
