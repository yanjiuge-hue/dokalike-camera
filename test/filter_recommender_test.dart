import 'package:flutter_test/flutter_test.dart';
import 'package:dokalike_camera/features/filters/engine/filter_recommender.dart';
import 'package:dokalike_camera/features/filters/data/filter_catalog.dart';
import 'package:dokalike_camera/models/detection_result.dart';
import 'package:dokalike_camera/models/enums.dart';

/// AI 滤镜推荐规则版单元测试（P1-3）。
void main() {
  const recommender = FilterRecommender();
  final catalog = FilterCatalog.all;

  SceneFeatures features({
    double luminance = 0.5,
    double colorTemperature = 0.5,
    int faceCount = 0,
    SceneType sceneType = SceneType.other,
  }) {
    return SceneFeatures(
      luminance: luminance,
      colorTemperature: colorTemperature,
      faceCount: faceCount,
      sceneType: sceneType,
    );
  }

  group('FilterRecommender.基础', () {
    test('结果非空且不超过上限 5', () {
      final r = recommender.recommend(features(), catalog);
      expect(r, isNotEmpty);
      expect(r.length, lessThanOrEqualTo(5));
    });

    test('原图不参与推荐', () {
      final r = recommender.recommend(features(), catalog);
      expect(r.any((x) => x.filterId == 'original'), isFalse);
    });

    test('按置信度降序排列', () {
      final r = recommender.recommend(features(), catalog);
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].confidence,
            greaterThanOrEqualTo(r[i].confidence));
      }
    });

    test('置信度 ∈ [0, 0.98]', () {
      final r = recommender.recommend(features(), catalog);
      for (final rec in r) {
        expect(rec.confidence, greaterThanOrEqualTo(0));
        expect(rec.confidence, lessThanOrEqualTo(0.98));
      }
    });

    test('每项 reason 非空', () {
      final r = recommender.recommend(features(), catalog);
      for (final rec in r) {
        expect(rec.reason, isNotEmpty);
      }
    });

    test('空 catalog 返回空列表（不崩溃）', () {
      final r = recommender.recommend(features(), const []);
      expect(r, isEmpty);
    });
  });

  group('FilterRecommender.场景匹配', () {
    test('夜景 + 暗光：夜港/墨影置顶', () {
      final r = recommender.recommend(
        features(luminance: 0.15, sceneType: SceneType.night),
        catalog,
      );
      expect(r.first.filterId, anyOf('night_port', 'mono_film'));
    });

    test('人像 + 有人脸：人像滤镜加分', () {
      final r = recommender.recommend(
        features(faceCount: 2, sceneType: SceneType.portrait),
        catalog,
      );
      expect(r.take(2).map((x) => x.filterId),
          contains(anyOf('agfa_soft', 'street_200')));
    });

    test('食物场景：暖调滤镜优先', () {
      final r = recommender.recommend(
        features(sceneType: SceneType.food),
        catalog,
      );
      expect(r.first.filterId, anyOf('warm_sun', 'kodak_gold'));
    });

    test('风景场景：冷暖滤镜均可推荐', () {
      final r = recommender.recommend(
        features(sceneType: SceneType.landscape),
        catalog,
      );
      final topIds = r.take(2).map((x) => x.filterId).toSet();
      expect(
        topIds.intersection({'teal_dawn', 'fuji_green', 'warm_sun', 'kodak_gold'}),
        isNotEmpty,
      );
    });
  });

  group('FilterRecommender.亮度边界', () {
    test('极暗 luminance=0：夜景滤镜仍推荐', () {
      final r = recommender.recommend(
        features(luminance: 0.0, sceneType: SceneType.night),
        catalog,
      );
      expect(r, isNotEmpty);
    });

    test('极亮 luminance=1.0：冷调滤镜加分', () {
      final r = recommender.recommend(
        features(luminance: 1.0, colorTemperature: 0.3, sceneType: SceneType.landscape),
        catalog,
      );
      expect(r.first.filterId, anyOf('teal_dawn', 'fuji_green'));
    });

    test('中等亮度 0.5：不触发亮度加分', () {
      final r1 = recommender.recommend(
        features(luminance: 0.5, sceneType: SceneType.other),
        catalog,
      );
      final r2 = recommender.recommend(
        features(luminance: 0.6, sceneType: SceneType.other),
        catalog,
      );
      // 亮度在阈值附近时置信度接近
      expect((r1.first.confidence - r2.first.confidence).abs(), lessThan(0.3));
    });
  });

  group('FilterRecommender.色温边界', () {
    test('暖光 colorTemperature=1.0：暖调滤镜置顶', () {
      final r = recommender.recommend(
        features(colorTemperature: 1.0, sceneType: SceneType.food),
        catalog,
      );
      expect(r.first.filterId, anyOf('warm_sun', 'kodak_gold'));
    });

    test('冷光 colorTemperature=0.0：冷调滤镜置顶', () {
      final r = recommender.recommend(
        features(colorTemperature: 0.0, sceneType: SceneType.landscape),
        catalog,
      );
      expect(r.first.filterId, anyOf('teal_dawn', 'fuji_green'));
    });

    test('中性色温 0.5：不触发色温加分', () {
      final r = recommender.recommend(
        features(colorTemperature: 0.5, sceneType: SceneType.other),
        catalog,
      );
      expect(r.first.confidence, lessThan(0.5));
    });
  });

  group('FilterRecommender.人脸数量', () {
    test('无人脸：人像滤镜不额外加分', () {
      final r0 = recommender.recommend(
        features(faceCount: 0, sceneType: SceneType.portrait),
        catalog,
      );
      final r2 = recommender.recommend(
        features(faceCount: 2, sceneType: SceneType.portrait),
        catalog,
      );
      // 有人脸时人像滤镜置信度应更高
      final p0 = r0.firstWhere((x) => x.filterId == 'agfa_soft').confidence;
      final p2 = r2.firstWhere((x) => x.filterId == 'agfa_soft').confidence;
      expect(p2, greaterThan(p0));
    });
  });
}
