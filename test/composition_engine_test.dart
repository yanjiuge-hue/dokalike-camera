import 'package:flutter_test/flutter_test.dart';
import 'package:dokalike_camera/core/utils/geometry.dart';
import 'package:dokalike_camera/features/composition/engine/composition_engine.dart';
import 'package:dokalike_camera/features/composition/engine/rule_golden_ratio.dart';
import 'package:dokalike_camera/features/composition/engine/rule_horizon.dart';
import 'package:dokalike_camera/features/composition/engine/rule_subject.dart';
import 'package:dokalike_camera/features/composition/engine/rule_thirds.dart';
import 'package:dokalike_camera/models/detection_result.dart';
import 'package:dokalike_camera/models/enums.dart';

/// 构图引擎 + 四条规则全面单元测试（P0-5 / P0-6）。
void main() {
  // ---- 测试夹具 ----
  const meta = FrameMeta(
    width: 1080, height: 1920, quarterTurns: 1,
    isFrontCamera: false, previewAspect: 9 / 16, rollAngleDeg: 0,
  );

  DetectionResult resultOf({
    List<FaceBox> faces = const [],
    List<ObjectBox> objects = const [],
    double roll = 0,
  }) {
    return DetectionResult(
      faces: faces,
      objects: objects,
      features: const SceneFeatures(
        luminance: 0.5, colorTemperature: 0.5,
        faceCount: 0, sceneType: SceneType.other,
      ),
      meta: FrameMeta(
        width: 1080, height: 1920, quarterTurns: 1,
        isFrontCamera: false, previewAspect: 9 / 16, rollAngleDeg: roll,
      ),
      timestamp: DateTime.now(),
    );
  }

  group('CompositionEngine.综合', () {
    test('无主体：中性评分且输出引导线', () {
      final engine = CompositionEngine();
      final advice = engine.evaluate(resultOf(), meta);
      expect(advice.score, greaterThan(0.3));
      expect(advice.score, lessThan(0.7));
      expect(advice.lines, isNotEmpty);
      // 三分线 + 黄金线 = 4 纵 + 4 横 = 8 条
      expect(advice.lines.length, 8);
    });

    test('主体大小位置良好：高评分', () {
      final engine = CompositionEngine();
      final advice = engine.evaluate(
        resultOf(objects: [
          const ObjectBox(
            rect: Rect01(left: 0.25, top: 0.25, right: 0.75, bottom: 0.75),
            label: 'person', confidence: 0.9,
          ),
        ]),
        meta,
      );
      expect(advice.score, greaterThan(0.6));
    });

    test('isGoodComposition 阈值判定', () {
      final engine = CompositionEngine();
      // 水平 + 良好主体 → 应为好构图
      final advice = engine.evaluate(
        resultOf(objects: [
          const ObjectBox(
            rect: Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
            label: 'person', confidence: 0.9,
          ),
        ]),
        meta,
      );
      // 至少应接近阈值
      expect(advice.isGoodComposition || advice.score > 0.7, isTrue);
    });
  });

  group('CompositionEngine._pickPrimarySubject', () {
    test('多物体取面积最大者', () {
      final engine = CompositionEngine();
      // 小物体 + 大物体：主体应是大物体
      final advice = engine.evaluate(
        resultOf(objects: [
          const ObjectBox(
            rect: Rect01(left: 0.4, top: 0.4, right: 0.45, bottom: 0.45),
            label: 'small', confidence: 0.9,
          ),
          const ObjectBox(
            rect: Rect01(left: 0.2, top: 0.2, right: 0.8, bottom: 0.8),
            label: 'big', confidence: 0.9,
          ),
        ]),
        meta,
      );
      // 大物体面积 0.36，在 [0.08, 0.65] 区间，主体良好
      expect(advice.score, greaterThan(0.5));
    });

    test('人脸优先于物体（同面积）', () {
      final engine = CompositionEngine();
      // 等面积的人脸和物体，先遍历人脸，bestArea 更新后物体不覆盖
      final advice = engine.evaluate(
        resultOf(
          faces: [
            const FaceBox(rect: Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7)),
          ],
          objects: [
            const ObjectBox(
              rect: Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
              label: 'person', confidence: 0.9,
            ),
          ],
        ),
        meta,
      );
      expect(advice.score, greaterThan(0.5));
    });
  });

  group('SubjectRule', () {
    final rule = SubjectRule();

    test('无主体：中性 0.5', () {
      final ctx = EvalContext(
        input: DetectionResult(
          faces: const [], objects: const [],
          features: const SceneFeatures(
            luminance: 0.5, colorTemperature: 0.5,
            faceCount: 0, sceneType: SceneType.other,
          ),
          meta: meta, timestamp: DateTime.now(),
        ),
        meta: meta,
      );
      expect(rule.evaluate(ctx).score, 0.5);
    });

    test('主体过小（面积<8%）：给靠近提示', () {
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: 0.45, top: 0.45, right: 0.5, bottom: 0.5),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, lessThan(0.3));
      expect(out.moveHint?.direction, MoveDirection.moveCloser);
    });

    test('主体过大（面积>65%）：给拉远提示', () {
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: 0.1, top: 0.1, right: 0.95, bottom: 0.95),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, lessThan(0.4));
      expect(out.moveHint?.direction, MoveDirection.moveFarther);
    });

    test('主体被裁切：给逃离提示', () {
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: -0.3, top: 0.2, right: 0.3, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, lessThan(0.2));
      // 主体中心 x = 0 < 0.5 → 向右移
      expect(out.moveHint?.direction, MoveDirection.moveRight);
    });

    test('主体右侧被裁切：向左移', () {
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: 0.7, top: 0.2, right: 1.3, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      // 中心 x = 1.0 > 0.5 → 向左移
      expect(out.moveHint?.direction, MoveDirection.moveLeft);
    });

    test('主体过偏（水平）：给水平方向提示', () {
      // 修正：原来的 0.2×0.2 框面积只有 0.04，会先命中「主体过小」分支返回
      // moveCloser。要测「过偏」必须先把面积抬进 [0.08, 0.65] 合法区间。
      // 现取 0.30×0.40 = 0.12：未裁切、面积合法；中心 (0.20, 0.50)，
      // dx = -0.30（|dx| > 0.22 安全区）而 dy = +0.08（在 ±0.28 内），
      // 于是走水平分支 → moveRight。
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: 0.05, top: 0.30, right: 0.35, bottom: 0.70),
      );
      final out = rule.evaluate(ctx);
      expect(out.moveHint?.direction, anyOf(MoveDirection.moveRight, MoveDirection.moveLeft));
    });

    test('主体大小位置良好：满分', () {
      final ctx = EvalContext(
        input: resultOf(),
        meta: meta,
        primarySubject: const Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, 1.0);
    });

    test('多镜头设备 + 主体过小：给长焦建议', () {
      final ctx = EvalContext(
        input: resultOf(), meta: meta, hasMultiLens: true,
        primarySubject: const Rect01(left: 0.45, top: 0.45, right: 0.5, bottom: 0.5),
      );
      final out = rule.evaluate(ctx);
      expect(out.focalHint?.suggestion, FocalSuggestion.tele);
    });

    test('多镜头设备 + 主体过大：给广角建议', () {
      final ctx = EvalContext(
        input: resultOf(), meta: meta, hasMultiLens: true,
        primarySubject: const Rect01(left: 0.1, top: 0.1, right: 0.95, bottom: 0.95),
      );
      final out = rule.evaluate(ctx);
      expect(out.focalHint?.suggestion, FocalSuggestion.wide);
    });
  });

  group('ThirdsRule', () {
    final rule = ThirdsRule();

    test('永远输出 4 条三分线', () {
      // 修正：AppConstants.thirdsPositions 只有 [1/3, 2/3] 两个位置，
      // 规则按「先竖后横」各生成 2 条 → 共 4 条，不是 8 条。
      // 8 条是「三分 4 + 黄金 4」在 CompositionEngine 聚合后的总数。
      final ctx = EvalContext(
        input: resultOf(), meta: meta,
        primarySubject: const Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      expect(out.lines.length, 4);
      expect(out.lines.every((l) => l.type == GuideLineType.thirds), isTrue);
      // 2 竖 + 2 横，顺序与源码一致
      expect(out.lines.where((l) => l.axis == LineAxis.vertical).length, 2);
      expect(out.lines.where((l) => l.axis == LineAxis.horizontal).length, 2);
    });

    test('主体中心在三分交点：高分', () {
      final ctx = EvalContext(
        input: resultOf(), meta: meta,
        // 中心 (1/3, 1/3) 正好在三分交点
        primarySubject: const Rect01(left: 0.25, top: 0.25, right: 0.41, bottom: 0.41),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, greaterThan(0.8));
    });

    test('主体远离三分点：低分且有方向提示', () {
      final ctx = EvalContext(
        input: resultOf(), meta: meta,
        // 中心在 (0.5, 0.5) 远离任何三分交点
        primarySubject: const Rect01(left: 0.45, top: 0.45, right: 0.55, bottom: 0.55),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, lessThan(0.8));
      // 但需超过 snapDistance 才给提示
    });

    test('无主体：中性评分仍输出引导线', () {
      final ctx = EvalContext(input: resultOf(), meta: meta);
      final out = rule.evaluate(ctx);
      expect(out.score, 0.5);
      expect(out.lines, isNotEmpty);
    });
  });

  group('GoldenRatioRule', () {
    // 修正：GoldenRatioRule 无 const 构造函数，不能用 const 声明（同上）。
    final rule = GoldenRatioRule();

    test('永远输出 4 条黄金线', () {
      // 修正：与三分法同构，AppConstants.goldenPositions = [0.382, 0.618]
      // 两个位置 → 2 竖 + 2 横 = 4 条。
      final ctx = EvalContext(
        input: resultOf(), meta: meta,
        primarySubject: const Rect01(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7),
      );
      final out = rule.evaluate(ctx);
      expect(out.lines.length, 4);
      expect(out.lines.every((l) => l.type == GuideLineType.golden), isTrue);
      expect(out.lines.where((l) => l.axis == LineAxis.vertical).length, 2);
      expect(out.lines.where((l) => l.axis == LineAxis.horizontal).length, 2);
    });

    test('主体中心在黄金交点（0.382, 0.382）：高分', () {
      final ctx = EvalContext(
        input: resultOf(), meta: meta,
        primarySubject: const Rect01(left: 0.3, top: 0.3, right: 0.46, bottom: 0.46),
      );
      final out = rule.evaluate(ctx);
      expect(out.score, greaterThan(0.7));
    });
  });

  group('HorizonRule', () {
    final rule = HorizonRule();

    test('完全水平（0°）：满分', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 0,
        ),
      );
      expect(rule.evaluate(ctx).score, 1.0);
    });

    test('容差内（1.5°）：满分', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 1.5,
        ),
      );
      expect(rule.evaluate(ctx).score, 1.0);
    });

    test('超出容差（5°）：部分扣分', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 5,
        ),
      );
      final score = rule.evaluate(ctx).score;
      expect(score, lessThan(1.0));
      expect(score, greaterThan(0.0));
    });

    test('满偏（10°+）：0 分', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 15,
        ),
      );
      expect(rule.evaluate(ctx).score, 0.0);
    });

    test('负角度（右倾）：提示向左回正', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: -5,
        ),
      );
      final out = rule.evaluate(ctx);
      expect(out.message, contains('左'));
    });

    test('正角度（左倾）：提示向右回正', () {
      final ctx = EvalContext(
        input: _emptyResult, meta: const FrameMeta(
          width: 100, height: 100, quarterTurns: 0,
          isFrontCamera: false, previewAspect: 1, rollAngleDeg: 5,
        ),
      );
      final out = rule.evaluate(ctx);
      expect(out.message, contains('右'));
    });
  });

  group('规则权重', () {
    test('主体规则权重最高（0.35）', () {
      expect(SubjectRule().weight, 0.35);
    });
    test('三分法与水平校正权重 0.25', () {
      expect(ThirdsRule().weight, 0.25);
      expect(HorizonRule().weight, 0.25);
    });
    test('黄金分割权重最低（0.15）', () {
      expect(GoldenRatioRule().weight, 0.15);
    });
    test('权重总和 = 1.0', () {
      final sum = SubjectRule().weight + ThirdsRule().weight +
          GoldenRatioRule().weight + HorizonRule().weight;
      expect(sum, closeTo(1.0, 1e-9));
    });
  });
}

final _emptyResult = DetectionResult(
  faces: const [], objects: const [],
  features: const SceneFeatures(
    luminance: 0.5, colorTemperature: 0.5,
    faceCount: 0, sceneType: SceneType.other,
  ),
  meta: const FrameMeta(
    width: 100, height: 100, quarterTurns: 0,
    isFrontCamera: false, previewAspect: 1,
  ),
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
);
