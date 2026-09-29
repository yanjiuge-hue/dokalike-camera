import 'package:flutter_test/flutter_test.dart';
import 'package:dokalike_camera/core/utils/ema_filter.dart';
import 'package:dokalike_camera/core/utils/geometry.dart';

/// EMA 低通滤波器全面单元测试（P0-6 引导线防漂移核心）。
///
/// 覆盖：α 边界（0/1）、首帧、收敛、丢失保持与超限置空、reset、
/// 矩形四边独立插值、missCount 共享行为文档化。
void main() {
  group('EmaFilter.alpha 边界', () {
    test('α=0：完全保持旧值（输入被忽略）', () {
      final ema = EmaFilter(alpha: 0.0);
      ema.update(const Offset01(0.2, 0.2));
      final out = ema.update(const Offset01(0.9, 0.9));
      expect(out!.x, closeTo(0.2, 1e-9));
      expect(out.y, closeTo(0.2, 1e-9));
    });

    test('α=1：不滤波，直接采用新值', () {
      final ema = EmaFilter(alpha: 1.0);
      ema.update(const Offset01(0.2, 0.2));
      final out = ema.update(const Offset01(0.9, 0.9))!;
      expect(out.x, closeTo(0.9, 1e-9));
      expect(out.y, closeTo(0.9, 1e-9));
    });

    test('α 被 clamp 到 [0,1]（传入 1.5 等价 1.0）', () {
      final ema = EmaFilter(alpha: 1.5);
      expect(ema.alpha, 1.0);
    });

    test('α 被 clamp 到 [0,1]（传入 -0.5 等价 0.0）', () {
      final ema = EmaFilter(alpha: -0.5);
      expect(ema.alpha, 0.0);
    });
  });

  group('EmaFilter.点滤波', () {
    test('首帧：直接采用输入（无旧值可插值）', () {
      final ema = EmaFilter(alpha: 0.3);
      final out = ema.update(const Offset01(0.5, 0.5));
      expect(out, isNotNull);
      expect(out!.x, closeTo(0.5, 1e-9));
    });

    test('连续输入逐步收敛到目标', () {
      final ema = EmaFilter(alpha: 0.3);
      Offset01? p;
      for (var i = 0; i < 30; i++) {
        p = ema.update(const Offset01(1.0, 1.0));
      }
      expect(p!.x, greaterThan(0.95));
      expect(p.y, greaterThan(0.95));
    });

    test('收敛过程单调递增（向更大目标值）', () {
      final ema = EmaFilter(alpha: 0.3);
      ema.update(const Offset01(0, 0));
      var prev = ema.point!.x;
      for (var i = 0; i < 10; i++) {
        ema.update(const Offset01(1, 1));
        expect(ema.point!.x, greaterThan(prev));
        prev = ema.point!.x;
      }
    });
  });

  group('EmaFilter.矩形滤波', () {
    test('首帧直接采用', () {
      final ema = EmaFilter(alpha: 0.3);
      final out = ema.updateRect(
        const Rect01(left: 0.1, top: 0.1, right: 0.4, bottom: 0.4),
      );
      expect(out, isNotNull);
      expect(out!.left, closeTo(0.1, 1e-9));
      expect(out.bottom, closeTo(0.4, 1e-9));
    });

    test('四边各自独立插值', () {
      final ema = EmaFilter(alpha: 0.5);
      ema.updateRect(const Rect01(left: 0, top: 0, right: 0, bottom: 0));
      final out = ema.updateRect(
        const Rect01(left: 0.2, top: 0.4, right: 0.6, bottom: 0.8),
      )!;
      expect(out.left, closeTo(0.1, 1e-9));
      expect(out.top, closeTo(0.2, 1e-9));
      expect(out.right, closeTo(0.3, 1e-9));
      expect(out.bottom, closeTo(0.4, 1e-9));
    });
  });

  group('EmaFilter.丢失保持与超限置空', () {
    test('点：missLimit-1 次丢失保持，第 missLimit 次置空', () {
      final ema = EmaFilter(alpha: 0.3, missLimit: 3);
      ema.update(const Offset01(0.5, 0.5));
      expect(ema.update(null), isNotNull); // miss=1
      expect(ema.update(null), isNotNull); // miss=2
      expect(ema.update(null), isNull); // miss=3 → 置空
    });

    test('矩形：超限置空后 isHolding 仍可恢复', () {
      final ema = EmaFilter(alpha: 0.3, missLimit: 2);
      ema.updateRect(const Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5));
      expect(ema.updateRect(null), isNotNull); // miss=1 holding
      expect(ema.isHolding, isTrue);
      expect(ema.updateRect(null), isNull); // miss=2 置空
      // 恢复
      final out = ema.updateRect(
        const Rect01(left: 0.3, top: 0.3, right: 0.6, bottom: 0.6),
      );
      expect(out, isNotNull);
      expect(ema.isHolding, isFalse);
    });

    test('丢失后重新获得目标：missCount 重置', () {
      final ema = EmaFilter(alpha: 0.3, missLimit: 5);
      ema.update(const Offset01(0.5, 0.5));
      ema.update(null); // miss=1
      ema.update(null); // miss=2
      ema.update(const Offset01(0.5, 0.5)); // 恢复
      expect(ema.isHolding, isFalse);
      // 再丢失应从 miss=1 重新计数
      expect(ema.update(null), isNotNull);
    });
  });

  group('EmaFilter.reset', () {
    test('reset 清空点与矩形状态', () {
      final ema = EmaFilter();
      ema.update(const Offset01(0.5, 0.5));
      ema.updateRect(const Rect01(left: 0.1, top: 0.1, right: 0.4, bottom: 0.4));
      ema.reset();
      expect(ema.point, isNull);
      expect(ema.rect, isNull);
      expect(ema.isHolding, isFalse);
    });

    test('reset 后首帧等同全新滤波器', () {
      final ema = EmaFilter(alpha: 0.3);
      ema.update(const Offset01(0.9, 0.9));
      ema.reset();
      final out = ema.update(const Offset01(0.2, 0.2));
      expect(out!.x, closeTo(0.2, 1e-9));
    });
  });

  group('EmaFilter.设计文档化（非 bug）', () {
    test('update 与 updateRect 共享 missCount：点流丢失会加速矩形置空', () {
      // 文档化行为：_missCount 为点/矩形共用。
      // 实际调用方（CompositionNotifier）只用 updateRect，不会混用。
      // 此测试记录该共享行为：updateRect 设矩形后，连续 update(null)
      // 会累加共享 missCount，使后续 updateRect(null) 提前达到 missLimit。
      final ema = EmaFilter(alpha: 0.3, missLimit: 3);
      ema.updateRect(const Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5));
      expect(ema.rect, isNotNull);
      ema.update(null); // missCount=1（点流，_point 本就 null）
      ema.update(null); // missCount=2
      // 此时矩形仍在（updateRect 未被调用，_rect 不变）
      expect(ema.rect, isNotNull);
      // 再调 updateRect(null)：missCount=3>=3 → _rect 置空
      expect(ema.updateRect(null), isNull);
    });
  });
}
