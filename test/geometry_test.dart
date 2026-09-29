import 'package:flutter_test/flutter_test.dart';
import 'package:dokalike_camera/core/utils/geometry.dart';

/// geometry 纯逻辑单元测试（Offset01 / Rect01 / rotateQuarterTurns）。
void main() {
  group('Offset01', () {
    test('distanceTo 同点为 0', () {
      const p = Offset01(0.3, 0.7);
      expect(p.distanceTo(p), 0);
    });

    test('distanceTo 对角点 ≈ √2', () {
      const a = Offset01(0, 0);
      const b = Offset01(1, 1);
      expect(a.distanceTo(b), closeTo(1.41421356, 1e-5));
    });

    test('Equatable：相同坐标相等', () {
      expect(const Offset01(0.1, 0.2), const Offset01(0.1, 0.2));
    });
  });

  group('Rect01.fromLTWH', () {
    test('正确计算 right/bottom', () {
      final r = Rect01.fromLTWH(0.1, 0.2, 0.3, 0.4);
      expect(r.right, closeTo(0.4, 1e-9));
      expect(r.bottom, closeTo(0.6, 1e-9));
      expect(r.width, closeTo(0.3, 1e-9));
      expect(r.height, closeTo(0.4, 1e-9));
    });
  });

  group('Rect01.full', () {
    test('全屏矩形', () {
      expect(Rect01.full.left, 0);
      expect(Rect01.full.right, 1);
      expect(Rect01.full.area, closeTo(1.0, 1e-9));
    });
  });

  group('Rect01.area 裁剪到 [0,1]', () {
    test('完全在画面内', () {
      const r = Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5);
      expect(r.area, closeTo(0.09, 1e-9));
    });

    test('左侧越界：裁剪后面积正确', () {
      const r = Rect01(left: -0.3, top: 0, right: 0.5, bottom: 1);
      // 宽度按 left.clamp(0,1)=0 → right.clamp(0,1)=0.5 → w=0.5；h=1
      expect(r.area, closeTo(0.5, 1e-9));
    });

    test('完全越界：面积为 0', () {
      const r = Rect01(left: -2, top: -2, right: -1, bottom: -1);
      expect(r.area, 0);
    });

    test('右侧/下侧越界裁剪', () {
      const r = Rect01(left: 0.8, top: 0.8, right: 1.5, bottom: 1.5);
      // w = 1 - 0.8 = 0.2；h = 0.2
      expect(r.area, closeTo(0.04, 1e-9));
    });
  });

  group('Rect01.isEmpty', () {
    test('零宽为空', () {
      const r = Rect01(left: 0.5, top: 0.2, right: 0.5, bottom: 0.5);
      expect(r.isEmpty, isTrue);
    });

    test('负高为空', () {
      const r = Rect01(left: 0.1, top: 0.6, right: 0.5, bottom: 0.4);
      expect(r.isEmpty, isTrue);
    });

    test('正常矩形非空', () {
      const r = Rect01(left: 0.1, top: 0.1, right: 0.5, bottom: 0.5);
      expect(r.isEmpty, isFalse);
    });
  });

  group('Rect01.isClippedByFrame', () {
    test('默认 epsilon=0.02：微越界不算裁切', () {
      const r = Rect01(left: -0.01, top: 0, right: 0.5, bottom: 0.5);
      expect(r.isClippedByFrame(), isFalse);
    });

    test('默认 epsilon：明显越界算裁切', () {
      const r = Rect01(left: -0.1, top: 0, right: 0.5, bottom: 0.5);
      expect(r.isClippedByFrame(), isTrue);
    });

    test('自定义 epsilon=0：任何越界都算裁切', () {
      const r = Rect01(left: -0.001, top: 0, right: 0.5, bottom: 0.5);
      expect(r.isClippedByFrame(0), isTrue);
    });

    test('右侧越界', () {
      const r = Rect01(left: 0.5, top: 0, right: 1.1, bottom: 0.5);
      expect(r.isClippedByFrame(), isTrue);
    });

    test('完全在画面内不裁切', () {
      const r = Rect01(left: 0.1, top: 0.1, right: 0.5, bottom: 0.5);
      expect(r.isClippedByFrame(), isFalse);
    });
  });

  group('Rect01.clamp01', () {
    test('越界四边全部裁剪到 [0,1]', () {
      const r = Rect01(left: -0.2, top: -0.1, right: 1.3, bottom: 1.5);
      final c = r.clamp01();
      expect(c.left, 0);
      expect(c.top, 0);
      expect(c.right, 1);
      expect(c.bottom, 1);
    });

    test('画面内不变', () {
      const r = Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5);
      expect(r.clamp01().left, closeTo(0.2, 1e-9));
    });
  });

  group('Rect01.translated', () {
    test('整体平移不裁剪', () {
      const r = Rect01(left: 0.2, top: 0.2, right: 0.5, bottom: 0.5);
      final t = r.translated(0.1, 0.2);
      expect(t.left, closeTo(0.3, 1e-9));
      expect(t.right, closeTo(0.6, 1e-9));
      expect(t.bottom, closeTo(0.7, 1e-9));
    });
  });

  group('Rect01.copyWith', () {
    test('部分字段覆盖', () {
      const r = Rect01(left: 0.1, top: 0.1, right: 0.5, bottom: 0.5);
      final c = r.copyWith(right: 0.9);
      expect(c.right, 0.9);
      expect(c.left, 0.1);
    });
  });

  group('Rect01.center', () {
    test('中心点正确', () {
      const r = Rect01(left: 0.2, top: 0.2, right: 0.6, bottom: 0.6);
      expect(r.center.x, closeTo(0.4, 1e-9));
      expect(r.center.y, closeTo(0.4, 1e-9));
    });
  });

  group('rotateQuarterTurns', () {
    test('0 圈：不变', () {
      const r = Rect01(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      expect(rotateQuarterTurns(r, 0), r);
    });

    test('4 圈等价 0 圈', () {
      const r = Rect01(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      expect(rotateQuarterTurns(r, 4), r);
    });

    test('顺时针 90°：左下角变左上', () {
      // 原矩形 left=0 top=0 right=0.2 bottom=0.4
      // 顺时针 90° 后 left=0.6 top=0 right=1.0 bottom=0.2
      const r = Rect01(left: 0, top: 0, right: 0.2, bottom: 0.4);
      final out = rotateQuarterTurns(r, 1);
      expect(out.left, closeTo(0.6, 1e-9));
      expect(out.top, closeTo(0, 1e-9));
      expect(out.right, closeTo(1.0, 1e-9));
      expect(out.bottom, closeTo(0.2, 1e-9));
    });

    test('180°：左右上下翻转', () {
      const r = Rect01(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      final out = rotateQuarterTurns(r, 2);
      // 两次 90°：先 (left=1-0.4=0.6, top=0.1, right=1-0.2=0.8, bottom=0.3)
      // 再 (left=1-0.3=0.7, top=0.6, right=1-0.1=0.9, bottom=0.8)
      expect(out.left, closeTo(0.7, 1e-9));
      expect(out.top, closeTo(0.6, 1e-9));
      expect(out.right, closeTo(0.9, 1e-9));
      expect(out.bottom, closeTo(0.8, 1e-9));
    });

    test('负数 turns 归一化（-1 ≡ 3）', () {
      const r = Rect01(left: 0, top: 0, right: 0.2, bottom: 0.4);
      expect(rotateQuarterTurns(r, -1), rotateQuarterTurns(r, 3));
    });

    test('大数 turns 归一化（5 ≡ 1）', () {
      const r = Rect01(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      expect(rotateQuarterTurns(r, 5), rotateQuarterTurns(r, 1));
    });
  });
}
