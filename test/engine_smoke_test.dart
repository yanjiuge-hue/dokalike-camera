import 'package:flutter_test/flutter_test.dart';

import 'package:dokalike_camera/core/utils/debouncer.dart';
import 'package:dokalike_camera/core/utils/ema_filter.dart';
import 'package:dokalike_camera/core/utils/geometry.dart';
import 'package:dokalike_camera/features/composition/engine/composition_engine.dart';
import 'package:dokalike_camera/features/composition/engine/rule_horizon.dart';
import 'package:dokalike_camera/features/composition/engine/rule_subject.dart';
import 'package:dokalike_camera/features/filters/data/filter_catalog.dart';
import 'package:dokalike_camera/features/filters/engine/color_matrix.dart';
import 'package:dokalike_camera/features/filters/engine/filter_recommender.dart';
import 'package:dokalike_camera/models/detection_result.dart';
import 'package:dokalike_camera/models/enums.dart';
import 'package:dokalike_camera/models/filter_preset.dart';

/// 纯逻辑引擎冒烟测试（QA 后续在此基础上补全覆盖）。
void main() {
  group('EmaFilter', () {
    test('平滑：连续输入逐步收敛', () {
      final ema = EmaFilter(alpha: 0.3);
      var point = ema.update(const Offset01(0, 0));
      point = ema.update(const Offset01(1, 1))!;
      expect(point.x, closeTo(0.3, 1e-9));
      point = ema.update(const Offset01(1, 1))!;
      expect(point.x, greaterThan(0.3));
      expect(point.x, lessThan(1));
    });

    test('丢失保持：missLimit 内保持上一状态，超限后置空', () {
      final ema = EmaFilter(alpha: 0.3, missLimit: 5);
      ema.updateRect(const Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5));
      // 连续 4 次丢失：保持
      for (var i = 0; i < 4; i++) {
        expect(ema.updateRect(null), isNotNull);
      }
      // 第 5 次：置空（淡出）
      expect(ema.updateRect(null), isNull);
    });

    test('reset 清空状态', () {
      final ema = EmaFilter();
      ema.update(const Offset01(0.5, 0.5));
      ema.reset();
      expect(ema.point, isNull);
    });
  });

  group('Rect01 / geometry', () {
    test('area 裁剪到 [0,1]', () {
      const r = Rect01(left: -0.5, top: 0, right: 0.5, bottom: 1);
      expect(r.area, closeTo(0.5, 1e-9));
    });

    test('isClippedByFrame 越界检测', () {
      const clipped = Rect01(left: -0.1, top: 0, right: 0.5, bottom: 0.5);
      const ok = Rect01(left: 0.1, top: 0.1, right: 0.5, bottom: 0.5);
      expect(clipped.isClippedByFrame(), isTrue);
      expect(ok.isClippedByFrame(), isFalse);
    });

    test('rotateQuarterTurns 顺时针 90°', () {
      const r = Rect01(left: 0, top: 0, right: 0.2, bottom: 0.4);
      final rotated = rotateQuarterTurns(r, 1);
      expect(rotated.left, closeTo(0.6, 1e-9));
      expect(rotated.top, closeTo(0, 1e-9));
      expect(rotated.right, closeTo(1.0, 1e-9));
      expect(rotated.bottom, closeTo(0.2, 1e-9));
    });
  });

  group('Throttler', () {
    test('间隔内不允许执行', () {
      final throttler = Throttler(interval: const Duration(milliseconds: 200));
      expect(throttler.shouldCall(), isTrue);
      expect(throttler.shouldCall(), isFalse);
      throttler.reset();
      expect(throttler.shouldCall(), isTrue);
    });
  });

  group('ColorMatrixKit', () {
    test('identity 不改变像素', () {
      const pixel = Rgba(r: 100, g: 150, b: 200);
      final out = ColorMatrixKit.apply(ColorMatrixKit.identity(), pixel);
      expect(out.r, 100);
      expect(out.g, 150);
      expect(out.b, 200);
    });

    test('lerp t=0/1 端点', () {
      final a = ColorMatrixKit.identity();
      final b = List<double>.generate(20, (i) => i.toDouble());
      expect(ColorMatrixKit.lerp(a, b, 0), a);
      expect(ColorMatrixKit.lerp(a, b, 1), b);
    });

    test('FilterPreset.matrixAt 强度插值', () {
      final preset = FilterCatalog.byId('warm_sun');
      final half = preset.matrixAt(0.5);
      final full = preset.matrixAt(1.0);
      expect(half[0], lessThan(full[0]));
      expect(FilterCatalog.original.matrixAt(1.0), ColorMatrixKit.identity());
    });
  });

  group('FilterRecommender', () {
    const recommender = FilterRecommender();
    final catalog = FilterCatalog.all;

    test('夜景场景推荐夜港/墨影且按置信度降序', () {
      const features = SceneFeatures(
        luminance: 0.15,
        colorTemperature: 0.5,
        faceCount: 0,
        sceneType: SceneType.night,
      );
      final result = recommender.recommend(features, catalog);
      expect(result, isNotEmpty);
      expect(result.first.filterId, anyOf('night_port', 'mono_film'));
      for (var i = 1; i < result.length; i++) {
        expect(result[i - 1].confidence,
            greaterThanOrEqualTo(result[i].confidence));
      }
    });

    test('人像场景推荐人像滤镜', () {
      const features = SceneFeatures(
        luminance: 0.6,
        colorTemperature: 0.5,
        faceCount: 2,
        sceneType: SceneType.portrait,
      );
      final result = recommender.recommend(features, catalog);
      expect(
        result.take(2).map((r) => r.filterId),
        contains(anyOf('agfa_soft', 'street_200')),
      );
    });

    test('原图不参与推荐', () {
      const features = SceneFeatures(
        luminance: 0.5,
        colorTemperature: 0.5,
        faceCount: 0,
        sceneType: SceneType.other,
      );
      final result = recommender.recommend(features, catalog);
      expect(result.any((r) => r.filterId == 'original'), isFalse);
    });
  });

  group('CompositionEngine', () {
    final meta = const FrameMeta(
      width: 1080,
      height: 1920,
      quarterTurns: 1,
      isFrontCamera: false,
      previewAspect: 9 / 16,
      rollAngleDeg: 0,
    );

    DetectionResult resultOf({
      List<FaceBox> faces = const [],
      List<ObjectBox> objects = const [],
    }) {
      return DetectionResult(
        faces: faces,
        objects: objects,
        features: const SceneFeatures(
          luminance: 0.5,
          colorTemperature: 0.5,
          faceCount: 0,
          sceneType: SceneType.other,
        ),
        meta: meta,
        timestamp: DateTime.now(),
      );
    }

    test('无主体：中性评分且输出引导线', () {
      final engine = CompositionEngine();
      final advice = engine.evaluate(resultOf(), meta);
      expect(advice.score, greaterThan(0.3));
      expect(advice.score, lessThan(0.7));
      expect(advice.lines, isNotEmpty);
    });

    test('主体过小：给出靠近提示', () {
      final engine = CompositionEngine();
      final advice = engine.evaluate(
        resultOf(objects: [
          ObjectBox(
            rect: const Rect01(
                left: 0.45, top: 0.4, right: 0.55, bottom: 0.5),
            label: 'person',
            confidence: 0.9,
          ),
        ]),
        meta,
      );
      expect(advice.moveHint?.direction, MoveDirection.moveCloser);
      expect(advice.isGoodComposition, isFalse);
    });

    test('主体大小位置良好：高评分', () {
      final engine = CompositionEngine();
      final advice = engine.evaluate(
        resultOf(objects: [
          ObjectBox(
            rect: const Rect01(
                left: 0.25, top: 0.25, right: 0.75, bottom: 0.75),
            label: 'person',
            confidence: 0.9,
          ),
        ]),
        meta,
      );
      expect(advice.score, greaterThan(0.6));
    });

    test('HorizonRule 水平/倾斜评分', () {
      const rule = HorizonRule();
      const levelMeta = FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 0);
      const tiltedMeta = FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 8);
      final level = EvalContext(input: _emptyResult, meta: levelMeta);
      final tilted = EvalContext(input: _emptyResult, meta: tiltedMeta);
      expect(rule.evaluate(level).score, 1.0);
      expect(rule.evaluate(tilted).score, lessThan(0.5));
    });

    test('SubjectRule 被裁切判定', () {
      const rule = SubjectRule();
      final ctx = EvalContext(
        input: _emptyResult,
        meta: const FrameMeta(width: 100, height: 100, quarterTurns: 0,
            isFrontCamera: false, previewAspect: 1),
        primarySubject: const Rect01(
            left: -0.2, top: 0.2, right: 0.3, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, lessThan(0.2));
      expect(out.moveHint, isNotNull);
    });
  });
}

/// HorizonRule/SubjectRule 测试用的空检测结果常量。
final _emptyResult = DetectionResult(
  faces: const [],
  objects: const [],
  features: const SceneFeatures(
    luminance: 0.5,
    colorTemperature: 0.5,
    faceCount: 0,
    sceneType: SceneType.other,
  ),
  meta: const FrameMeta(
    width: 100,
    height: 100,
    quarterTurns: 0,
    isFrontCamera: false,
    previewAspect: 1,
  ),
  timestamp: _epoch,
);

/// 固定时间戳（保证 const 上下文可用）。
// ignore: avoid_dynamic_calls
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
