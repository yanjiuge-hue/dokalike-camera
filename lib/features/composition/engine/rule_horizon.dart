import '../../../core/constants/app_constants.dart';
import '../../../models/composition_advice.dart';
import 'composition_engine.dart';

/// 水平校正规则（P0-5 / P0-6）：设备横滚角阈值判定。
///
/// A-8 假设：横滚角来自加速度计（sensors_plus），而非图像估计；
/// 本规则只消费 [FrameMeta.rollAngleDeg]，角度来源可替换。
class HorizonRule implements CompositionRule {
  @override
  String get name => '水平校正';

  @override
  double get weight => 0.25;

  @override
  RuleOutput evaluate(EvalContext ctx) {
    final angle = ctx.meta.rollAngleDeg;
    final abs = angle.abs();

    if (abs <= AppConstants.horizonToleranceDeg) {
      return const RuleOutput(score: 1.0);
    }

    // 超出容差后线性衰减，至 horizonFullScaleDeg 归零
    final over = abs - AppConstants.horizonToleranceDeg;
    final span =
        AppConstants.horizonFullScaleDeg - AppConstants.horizonToleranceDeg;
    final score = (1 - over / span).clamp(0.0, 1.0);

    return RuleOutput(
      score: score,
      message: angle > 0 ? '机身左倾，向右回正' : '机身右倾，向左回正',
    );
  }
}
