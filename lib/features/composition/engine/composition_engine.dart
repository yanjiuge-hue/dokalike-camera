import '../../../core/utils/geometry.dart';
import '../../../models/composition_advice.dart';
import '../../../models/detection_result.dart';

/// 规则评估上下文：规则只读，不产生副作用。
class EvalContext {
  const EvalContext({
    required this.input,
    required this.meta,
    this.primarySubject,
    this.hasMultiLens = false,
  });

  final DetectionResult input;
  final FrameMeta meta;

  /// 主体框（最大人脸或最大物体，归一化坐标；无主体时为 null）
  final Rect01? primarySubject;

  /// 设备是否有多镜头（决定焦段建议是否有效，A-5）
  final bool hasMultiLens;
}

/// 单条构图规则的输出。
class RuleOutput {
  const RuleOutput({
    required this.score,
    this.lines = const [],
    this.moveHint,
    this.focalHint,
    this.message,
  });

  /// 该规则评分 [0,1]（0.5 表示中性/不适用）
  final double score;
  final List<GuideLine> lines;
  final DirectionHint? moveHint;
  final FocalHint? focalHint;
  final String? message;
}

/// 构图规则接口（纯逻辑，QA 单元测试目标）。
abstract interface class CompositionRule {
  /// 规则名称（日志/调试用）。
  String get name;

  /// 规则在综合评分中的权重。
  double get weight;

  RuleOutput evaluate(EvalContext ctx);
}

/// 构图规则调度器：输入 DetectionResult + FrameMeta → CompositionAdvice。
///
/// 纯 Dart 同步执行（共享知识：引擎不维护隐式状态，EMA 滤波由调用方
/// 在传入前完成，便于测试快照）。
class CompositionEngine {
  CompositionEngine({List<CompositionRule>? rules})
      : rules = rules ??
            [
              SubjectRule(),
              ThirdsRule(),
              GoldenRatioRule(),
              HorizonRule(),
            ];

  final List<CompositionRule> rules;

  /// 评估一帧的构图质量。
  CompositionAdvice evaluate(DetectionResult input, FrameMeta meta) {
    final subject = _pickPrimarySubject(input);
    final ctx = EvalContext(
      input: input,
      meta: meta,
      primarySubject: subject,
      hasMultiLens: false, // 由调用方按设备能力注入（见 CompositionNotifier）
    );

    var totalWeight = 0.0;
    var weightedScore = 0.0;
    final lines = <GuideLine>[];
    DirectionHint? moveHint;
    FocalHint? focalHint;
    String? message;

    for (final rule in rules) {
      final out = rule.evaluate(ctx);
      totalWeight += rule.weight;
      weightedScore += out.score.clamp(0.0, 1.0) * rule.weight;
      lines.addAll(out.lines);
      // 提示优先级：先注册的规则优先（主体 > 三分 > 黄金 > 水平）
      moveHint ??= out.moveHint;
      focalHint ??= out.focalHint;
      message ??= out.message;
    }

    final score =
        totalWeight == 0 ? 0.0 : (weightedScore / totalWeight).clamp(0.0, 1.0);

    return CompositionAdvice(
      lines: lines,
      horizonAngle: meta.rollAngleDeg,
      score: score,
      moveHint: moveHint,
      focalHint: focalHint,
      message: message,
    );
  }

  /// 选取主体：优先最大人脸，其次最大物体（按面积）。
  Rect01? _pickPrimarySubject(DetectionResult input) {
    Rect01? best;
    var bestArea = 0.0;
    for (final f in input.faces) {
      if (f.rect.area > bestArea) {
        bestArea = f.rect.area;
        best = f.rect;
      }
    }
    for (final o in input.objects) {
      if (o.rect.area > bestArea) {
        bestArea = o.rect.area;
        best = o.rect;
      }
    }
    return best;
  }
}
