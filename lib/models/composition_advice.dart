import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/geometry.dart';
import 'enums.dart';

/// 引导线（半透明叠加于预览）。
class GuideLine extends Equatable {
  const GuideLine({
    required this.type,
    required this.position,
    required this.axis,
  });

  final GuideLineType type;

  /// 位置：横向线为 y、纵向线为 x（归一化 [0,1]）。
  final double position;

  final LineAxis axis;

  @override
  List<Object?> get props => [type, position, axis];
}

/// 方向提示（箭头 + 文案）。
class DirectionHint extends Equatable {
  const DirectionHint({
    required this.direction,
    required this.anchor,
    required this.message,
  });

  final MoveDirection direction;

  /// 箭头锚点（主体附近，归一化坐标）
  final Offset01 anchor;

  final String message;

  @override
  List<Object?> get props => [direction, anchor, message];
}

/// 建议焦段提示（A-5：仅多镜头设备显示）。
class FocalHint extends Equatable {
  const FocalHint({required this.suggestion, required this.message});

  final FocalSuggestion suggestion;
  final String message;

  @override
  List<Object?> get props => [suggestion, message];
}

/// 构图评估结果：引导线 + 提示 + 综合评分。
class CompositionAdvice extends Equatable {
  const CompositionAdvice({
    required this.lines,
    required this.horizonAngle,
    required this.score,
    this.moveHint,
    this.focalHint,
    this.message,
  });

  final List<GuideLine> lines;

  /// 设备横滚角（度，正负表示左右倾斜）
  final double horizonAngle;

  /// 综合评分 [0,1]
  final double score;

  /// 移动方向提示（可为空 = 无提示）
  final DirectionHint? moveHint;

  /// 建议焦段（可为空；UI 层对单镜头设备丢弃，见 A-5）
  final FocalHint? focalHint;

  /// 气泡文案（无提示时为空）
  final String? message;

  /// 构图良好判定（P2-1：达成时线条高亮）
  bool get isGoodComposition => score >= AppConstants.goodCompositionThreshold;

  static const CompositionAdvice empty = CompositionAdvice(
    lines: [],
    horizonAngle: 0,
    score: 0,
  );

  @override
  List<Object?> get props => [score, horizonAngle, message];
}
