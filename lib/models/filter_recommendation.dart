import 'package:equatable/equatable.dart';

/// AI 滤镜推荐项（P1-3：滤镜 id + 置信度 + 推荐理由）。
class FilterRecommendation extends Equatable {
  const FilterRecommendation({
    required this.filterId,
    required this.confidence,
    required this.reason,
  });

  final String filterId;

  /// 置信度 [0,1]（UI 显示为百分比）
  final double confidence;

  /// 推荐理由（中文短句，如「夜间光线，压暗提亮」）
  final String reason;

  @override
  List<Object?> get props => [filterId, confidence, reason];
}
