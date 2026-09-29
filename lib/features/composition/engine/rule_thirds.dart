import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geometry.dart';
import '../../../models/composition_advice.dart';
import 'composition_engine.dart';

/// 三分法规则（P0-5）：主体中心到最近三分交点的距离评分。
///
/// - 距离越近评分越高；距离低于 [AppConstants.snapDistance] 视为已吸附；
/// - 距离过远时给出水平方向移动提示（左/右移）。
class ThirdsRule implements CompositionRule {
  @override
  String get name => '三分法';

  @override
  double get weight => 0.25;

  /// 评分归一化的最大距离（超过该距离评分为 0）。
  static const double maxDistance = 0.35;

  @override
  RuleOutput evaluate(EvalContext ctx) {
    // 三分线永远输出（作为静态引导线，UI 按网格样式过滤显示）
    final lines = <GuideLine>[
      for (final x in AppConstants.thirdsPositions)
        GuideLine(
            type: GuideLineType.thirds, position: x, axis: LineAxis.vertical),
      for (final y in AppConstants.thirdsPositions)
        GuideLine(
            type: GuideLineType.thirds, position: y, axis: LineAxis.horizontal),
    ];

    final subject = ctx.primarySubject;
    if (subject == null || subject.isEmpty) {
      // 无主体：中性评分，仅输出引导线
      return RuleOutput(score: 0.5, lines: lines);
    }

    final center = subject.center;
    Offset01? nearest;
    var minDist = double.infinity;
    for (final x in AppConstants.thirdsPositions) {
      for (final y in AppConstants.thirdsPositions) {
        final p = Offset01(x, y);
        final d = center.distanceTo(p);
        if (d < minDist) {
          minDist = d;
          nearest = p;
        }
      }
    }

    final score = (1 - (minDist / maxDistance)).clamp(0.0, 1.0);

    if (minDist <= AppConstants.snapDistance) {
      return RuleOutput(score: score, lines: lines);
    }

    // 距离过远：提示向最近交点水平移动
    final dx = (nearest?.x ?? 0.5) - center.x;
    DirectionHint? hint;
    if (dx.abs() > 0.05) {
      hint = DirectionHint(
        direction: dx > 0 ? MoveDirection.moveRight : MoveDirection.moveLeft,
        anchor: center,
        message: dx > 0 ? '主体偏左，向右移' : '主体偏右，向左移',
      );
    }

    return RuleOutput(score: score, lines: lines, moveHint: hint);
  }
}
