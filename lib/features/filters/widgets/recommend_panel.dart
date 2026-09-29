import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/filter_provider.dart';
import '../data/filter_catalog.dart';
import 'filter_bar.dart' show swatchOf;

/// AI 推荐面板（PRD §5.4）：从滤镜栏唤起的底部浮层。
///
/// 流程（时序图 4.4）：读取最近 SceneFeatures → 规则打分 →
/// 展示「滤镜名 + 置信度% + 应用按钮」→ 点击即应用并收起。
void showRecommendPanel(BuildContext context, WidgetRef ref) {
  // 打开即生成推荐（基于最近一次场景特征）
  ref.read(filterProvider.notifier).generateRecommendations();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return const _RecommendPanel();
    },
  );
}

class _RecommendPanel extends ConsumerWidget {
  const _RecommendPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部说明文案
            const Text(
              '根据当前光线与场景推荐',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            if (filterState.recommendations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '正在分析场景…稍后再试',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38),
                ),
              )
            else
              for (final recommendation in filterState.recommendations)
                _RecommendRow(
                  filterName: FilterCatalog.byId(recommendation.filterId).name,
                  filterId: recommendation.filterId,
                  confidence: recommendation.confidence,
                  reason: recommendation.reason,
                  isCurrent:
                      filterState.currentId == recommendation.filterId,
                  onApply: () {
                    notifier.applyRecommendation(recommendation);
                    Navigator.of(context).pop(); // 应用后自动收起，不打断取景
                  },
                ),
          ],
        ),
      ),
    );
  }
}

/// 单条推荐：滤镜名 + 置信度 + 理由 + 一键应用。
class _RecommendRow extends StatelessWidget {
  const _RecommendRow({
    required this.filterName,
    required this.filterId,
    required this.confidence,
    required this.reason,
    required this.isCurrent,
    required this.onApply,
  });

  final String filterName;
  final String filterId;
  final double confidence;
  final String reason;
  final bool isCurrent;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 色板小图
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: swatchOf(filterId),
            ),
          ),
          const SizedBox(width: 12),
          // 名称 + 置信度 + 理由
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      filterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(confidence * 100).round()}%',
                      style: const TextStyle(color: AppTheme.seed, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          // 一键应用
          isCurrent
              ? const Text('使用中', style: TextStyle(color: Colors.white30))
              : FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.seed,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: onApply,
                  child: const Text('应用'),
                ),
        ],
      ),
    );
  }
}
