import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/filter_provider.dart';
import '../data/filter_catalog.dart';

/// 滤镜横向滚动栏（PRD §5.3）：实时滤镜小预览 + 强度滑杆 + AI 推荐入口。
///
/// 小预览为滤镜色板（由颜色矩阵主色近似推导），选中滤镜上方显示
/// 强度滑杆（0-100%，拖动实时生效，P0-9）。
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.onRecommendTap});

  /// AI 推荐面板唤起回调
  final VoidCallback onRecommendTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ===== 强度滑杆（非原图时显示）=====
        if (!filterState.isOriginal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                const Text('强度', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: filterState.strength,
                    onChanged: (v) => notifier.setStrength(v),
                  ),
                ),
                Text(
                  '${(filterState.strength * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

        // ===== 横向滤镜列表 ==========
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: FilterCatalog.all.length + 1, // +1 = AI 推荐入口
            itemBuilder: (context, index) {
              // 末位：AI 推荐 ✨ 入口（PRD §5.3）
              if (index == FilterCatalog.all.length) {
                return _RecommendEntry(onTap: onRecommendTap);
              }
              final preset = FilterCatalog.all[index];
              return _FilterChip(
                preset: preset,
                selected: filterState.currentId == preset.id,
                onTap: () => notifier.setFilter(preset.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个滤镜项：色板小预览 + 名称。
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final FilterPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppTheme.seed : Colors.white24,
                  width: selected ? 2.5 : 1,
                ),
                gradient: swatchOf(preset.id),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preset.name,
              style: TextStyle(
                color: selected ? AppTheme.seed : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 滤镜色板（由颜色矩阵风格人工近似，仅用于小预览展示；
/// 实际滤镜效果以矩阵/LUT 为准）。
Gradient swatchOf(String filterId) {
  return switch (filterId) {
    'teal_dawn' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF8FBDBD), Color(0xFF31555C), Color(0xFF16262E)]),
    'street_200' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFB9B4AD), Color(0xFF6E6A66), Color(0xFF2E2D2C)]),
    'warm_sun' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFFFD9A0), Color(0xFFE8A96B), Color(0xFF8C5B33)]),
    'night_port' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF6C8899), Color(0xFF2C3E4C), Color(0xFF101A21)]),
    'agfa_soft' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE5C9BC), Color(0xFFB99C93), Color(0xFF6E5D5B)]),
    'fuji_green' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFA8C7A4), Color(0xFF5E8467), Color(0xFF2C4432)]),
    'kodak_gold' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFF2C879), Color(0xFFC89250), Color(0xFF6B4A2A)]),
    'mono_film' => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFD9D9D9), Color(0xFF8C8C8C), Color(0xFF2B2B2B)]),
    _ => const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFBDBDBD), Color(0xFF757575), Color(0xFF2E2E2E)]),
  };
}

/// AI 推荐入口（✨）。
class _RecommendEntry extends StatelessWidget {
  const _RecommendEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SparkleBox(),
            SizedBox(height: 4),
            Text('AI 推荐', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SparkleBox extends StatelessWidget {
  const _SparkleBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        color: Colors.white10,
      ),
      child: const Icon(Icons.auto_awesome, color: Color(0xFF3DDC97), size: 26),
    );
  }
}
