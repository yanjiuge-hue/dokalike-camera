import '../../../core/constants/app_constants.dart';
import '../../../models/detection_result.dart' show SceneFeatures;
import '../../../models/enums.dart';
import '../../../models/filter_preset.dart';
import '../../../models/filter_recommendation.dart';

/// AI 滤镜推荐（P1-3 规则版 MVP）。
///
/// 规则：亮度 + 色温指数 + 人脸数量 + 场景类型 → 对每款滤镜打分 →
/// 按置信度降序输出 Top N。接口形态与未来「模型版」保持兼容：
/// 调用方只需把 `recommend(features, catalog)` 换成模型推理结果即可。
class FilterRecommender {
  const FilterRecommender();

  /// 暖调滤镜（适合暖光 / 食物 / 人像）
  static const Set<String> _warmIds = {'warm_sun', 'kodak_gold'};

  /// 冷调滤镜（适合冷光 / 风景 / 夜景）
  static const Set<String> _coolIds = {'teal_dawn', 'fuji_green'};

  /// 人像滤镜
  static const Set<String> _portraitIds = {'agfa_soft', 'street_200'};

  /// 夜景滤镜
  static const Set<String> _nightIds = {'night_port', 'mono_film'};

  /// 冷光判定阈值（colorTemperature 低于该值）
  static const double coolThreshold = 0.42;

  /// 暖光判定阈值
  static const double warmThreshold = 0.58;

  /// 暗光判定阈值（luminance）
  static const double darkThreshold = 0.3;

  /// 亮光判定阈值
  static const double brightThreshold = 0.75;

  /// 对全部预设打分并输出推荐列表（置信度降序，最多 [AppConstants.recommendationLimit] 项）。
  List<FilterRecommendation> recommend(
    SceneFeatures features,
    List<FilterPreset> catalog,
  ) {
    final scored = <_ScoredRecommendation>[];
    for (final preset in catalog) {
      if (preset.isOriginal) continue; // 原图不参与推荐
      final (score, reason) = _score(preset, features);
      scored.add(_ScoredRecommendation(
        FilterRecommendation(
          filterId: preset.id,
          confidence: score.clamp(0.0, 0.98),
          reason: reason,
        ),
        rank: score,
      ));
    }
    scored.sort((a, b) => b.rank.compareTo(a.rank));
    return scored
        .take(AppConstants.recommendationLimit)
        .map((s) => s.recommendation)
        .toList();
  }

  /// 单款滤镜打分，返回 (分数, 推荐理由)。
  (double, String) _score(FilterPreset p, SceneFeatures f) {
    var score = 0.35; // 基础分
    final reasons = <String>[];

    // --- 场景类型匹配 ---
    switch (f.sceneType) {
      case SceneType.portrait:
        if (_portraitIds.contains(p.id)) {
          score += 0.4;
          reasons.add('人像场景');
        }
      case SceneType.food:
        if (_warmIds.contains(p.id)) {
          score += 0.4;
          reasons.add('食物更诱人');
        }
      case SceneType.night:
        if (_nightIds.contains(p.id)) {
          score += 0.4;
          reasons.add('夜间光线');
        }
      case SceneType.landscape:
        if (_coolIds.contains(p.id) || _warmIds.contains(p.id)) {
          score += 0.25;
          reasons.add('风景色彩层次');
        }
      case SceneType.other:
        break;
    }

    // --- 人脸数量 ---
    if (f.faceCount > 0 && _portraitIds.contains(p.id)) {
      score += 0.15;
      reasons.add('肤色友好');
    }

    // --- 亮度 ---
    if (f.luminance < darkThreshold) {
      if (_nightIds.contains(p.id)) {
        score += 0.25;
        reasons.add('暗光提氛围');
      }
    } else if (f.luminance > brightThreshold && _coolIds.contains(p.id)) {
      score += 0.1;
      reasons.add('高光更通透');
    }

    // --- 色温 ---
    if (f.colorTemperature > warmThreshold) {
      if (_warmIds.contains(p.id)) {
        score += 0.2;
        reasons.add('顺应当前暖光');
      } else if (_coolIds.contains(p.id)) {
        score -= 0.1;
      }
    } else if (f.colorTemperature < coolThreshold) {
      if (_coolIds.contains(p.id)) {
        score += 0.2;
        reasons.add('顺应当前冷光');
      } else if (_warmIds.contains(p.id)) {
        score -= 0.1;
      }
    }

    final reason = reasons.isEmpty ? '通用百搭' : reasons.take(2).join('，');
    return (score, reason);
  }
}

/// 打分排序用的内部包装。
class _ScoredRecommendation {
  const _ScoredRecommendation(this.recommendation, {required this.rank});

  final FilterRecommendation recommendation;
  final double rank;
}
