import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geometry.dart';
import '../../../models/composition_advice.dart';
// 修正：GuideLineType / LineAxis 定义在 models/enums.dart，而 composition_advice.dart
// 只 import 未 export，不会传递给本文件，需显式再 import 一次。
import '../../../models/enums.dart';
import 'composition_engine.dart';

/// 黄金分割规则：主体中心到最近 φ 线交点的距离评分（φ ≈ 0.618）。
///
/// 与三分法同构，仅参考线位置不同（0.382 / 0.618）。
class GoldenRatioRule implements CompositionRule {
  @override
  String get name => '黄金分割';

  @override
  double get weight => 0.15;

  /// 评分归一化的最大距离。
  static const double maxDistance = 0.35;

  @override
  RuleOutput evaluate(EvalContext ctx) {
    final lines = <GuideLine>[
      for (final x in AppConstants.goldenPositions)
        GuideLine(
            type: GuideLineType.golden, position: x, axis: LineAxis.vertical),
      for (final y in AppConstants.goldenPositions)
        GuideLine(
            type: GuideLineType.golden, position: y, axis: LineAxis.horizontal),
    ];

    final subject = ctx.primarySubject;
    if (subject == null || subject.isEmpty) {
      return RuleOutput(score: 0.5, lines: lines);
    }

    final center = subject.center;
    var minDist = double.infinity;
    for (final x in AppConstants.goldenPositions) {
      for (final y in AppConstants.goldenPositions) {
        final d = center.distanceTo(Offset01(x, y));
        if (d < minDist) minDist = d;
      }
    }

    final score = (1 - (minDist / maxDistance)).clamp(0.0, 1.0);
    return RuleOutput(score: score, lines: lines);
  }
}
