import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geometry.dart';
import '../../../models/composition_advice.dart';
// 修正：MoveDirection / FocalSuggestion 定义在 models/enums.dart，而
// composition_advice.dart 只 import 未 export，符号不会传递过来，需显式再
// import 一次（否则 const FocalHint 里还会连带报 Invalid constant value）。
import '../../../models/enums.dart';
import 'composition_engine.dart';

/// 主体突出规则（P0-5）：过小 / 过偏 / 被裁切 / 过大四类判定。
class SubjectRule implements CompositionRule {
  @override
  String get name => '主体突出';

  @override
  double get weight => 0.35;

  @override
  RuleOutput evaluate(EvalContext ctx) {
    final subject = ctx.primarySubject;
    if (subject == null || subject.isEmpty) {
      // 无主体：中性评分，等待用户对准场景
      return const RuleOutput(score: 0.5);
    }

    final center = subject.center;
    final area = subject.area;

    // 1) 被裁切：框越界（贴边/出画）
    if (subject.isClippedByFrame()) {
      return RuleOutput(
        score: 0.1,
        moveHint: DirectionHint(
          direction: _escapeDirection(subject),
          anchor: center,
          message: '主体被裁切，调整取景',
        ),
      );
    }

    // 2) 主体过小：面积 < 8%（建议靠近或换长焦）
    if (area < AppConstants.subjectMinAreaRatio) {
      return RuleOutput(
        score: 0.2,
        moveHint: DirectionHint(
          direction: MoveDirection.moveCloser,
          anchor: center,
          message: '靠近一点，让主体更突出',
        ),
        focalHint: ctx.hasMultiLens
            ? const FocalHint(
                suggestion: FocalSuggestion.tele,
                message: '建议使用长焦',
              )
            : null,
      );
    }

    // 3) 主体过大：面积 > 65%（建议拉远或换广角）
    if (area > AppConstants.subjectMaxAreaRatio) {
      return RuleOutput(
        score: 0.3,
        moveHint: DirectionHint(
          direction: MoveDirection.moveFarther,
          anchor: center,
          message: '拉远一点，留出空间',
        ),
        focalHint: ctx.hasMultiLens
            ? const FocalHint(
                suggestion: FocalSuggestion.wide,
                message: '建议使用广角',
              )
            : null,
      );
    }

    // 4) 主体过偏：中心偏离理想点（0.5, 0.42）超过安全区
    final dx = center.x - AppConstants.subjectIdealCenterX;
    final dy = center.y - AppConstants.subjectIdealCenterY;
    if (dx.abs() > AppConstants.subjectCenterMarginX ||
        dy.abs() > AppConstants.subjectCenterMarginY) {
      final horizontal = dx.abs() >= dy.abs();
      return RuleOutput(
        score: 0.5,
        moveHint: DirectionHint(
          direction: horizontal
              ? (dx > 0 ? MoveDirection.moveLeft : MoveDirection.moveRight)
              : MoveDirection.moveRight,
          anchor: center,
          message: horizontal
              ? (dx > 0 ? '主体偏右，向左移' : '主体偏左，向右移')
              : '主体位置偏高/偏低，调整角度',
        ),
      );
    }

    // 主体大小与位置均良好
    return const RuleOutput(score: 1.0);
  }

  /// 主体被裁切时，给出「向画面中心方向移动」的逃离方向：
  /// 主体中心在画面左半边 → 多半被左边裁切 → 向右移让主体回到画面内。
  MoveDirection _escapeDirection(Rect01 subject) {
    final c = subject.center;
    if (c.x < 0.5) return MoveDirection.moveRight;
    return MoveDirection.moveLeft;
  }
}
