import 'package:flutter_test/flutter_test.dart';
import 'package:dokalike_camera/features/filters/engine/color_matrix.dart';
import 'package:dokalike_camera/features/filters/data/filter_catalog.dart';

/// ColorMatrixKit + FilterPreset.matrixAt 单元测试。
///
/// 关键验证点：apply 与 Flutter ColorFilter.matrix 行为一致（0-1 归一化），
/// 保证「预览所见即落盘所得」（共享知识 #2）。
void main() {
  group('ColorMatrixKit.identity', () {
    test('长度 20', () {
      expect(ColorMatrixKit.identity().length, 20);
    });

    test('对任意像素不变', () {
      const pixel = Rgba(r: 0, g: 128, b: 255, a: 255);
      final out = ColorMatrixKit.apply(ColorMatrixKit.identity(), pixel);
      expect(out.r, 0);
      expect(out.g, 128);
      expect(out.b, 255);
      expect(out.a, 255);
    });
  });

  group('ColorMatrixKit.lerp', () {
    final a = ColorMatrixKit.identity();
    final b = List<double>.generate(20, (i) => i.toDouble());

    test('t=0 返回 a', () {
      expect(ColorMatrixKit.lerp(a, b, 0), a);
    });

    test('t=1 返回 b', () {
      expect(ColorMatrixKit.lerp(a, b, 1), b);
    });

    test('t=0.5 中点插值', () {
      final mid = ColorMatrixKit.lerp(a, b, 0.5);
      expect(mid[0], closeTo(0.5, 1e-9));
      expect(mid[4], closeTo(2.0, 1e-9));
    });

    test('t<0 clamp 到 0', () {
      expect(ColorMatrixKit.lerp(a, b, -0.5), a);
    });

    test('t>1 clamp 到 1', () {
      expect(ColorMatrixKit.lerp(a, b, 1.5), b);
    });
  });

  group('ColorMatrixKit.apply', () {
    test('纯偏移矩阵：offset=0.1 对 R 通道 +25.5', () {
      // offset m[4]=0.1，在 0-1 归一化下等价于 0-255 尺度的 +25.5
      final m = ColorMatrixKit.identity();
      m[4] = 0.1;
      const pixel = Rgba(r: 100, g: 100, b: 100);
      final out = ColorMatrixKit.apply(m, pixel);
      expect(out.r, closeTo(126, 1)); // 100 + 25.5 = 125.5 → round 126
      expect(out.g, 100);
      expect(out.b, 100);
    });

    test('负 offset 压暗', () {
      final m = ColorMatrixKit.identity();
      m[4] = -0.2;
      const pixel = Rgba(r: 200, g: 200, b: 200);
      final out = ColorMatrixKit.apply(m, pixel);
      expect(out.r, lessThan(200));
    });

    test('clamp255：结果不超出 [0,255]', () {
      // 极端矩阵：R = 255*255 + 255 offset
      final m = List<double>.filled(20, 0);
      m[0] = 255; // R 系数 255
      m[4] = 255; // R offset 满偏
      const pixel = Rgba(r: 255, g: 255, b: 255);
      final out = ColorMatrixKit.apply(m, pixel);
      expect(out.r, 255);
    });

    test('clamp255：负结果 clamp 到 0', () {
      final m = List<double>.filled(20, 0);
      m[4] = -1; // R offset -1（0-1 尺度 = -255）
      const pixel = Rgba(r: 100, g: 0, b: 0);
      final out = ColorMatrixKit.apply(m, pixel);
      expect(out.r, 0);
    });

    test('alpha 通道：m[18] 系数生效', () {
      final m = ColorMatrixKit.identity();
      m[18] = 0.5; // alpha 系数 0.5
      const pixel = Rgba(r: 0, g: 0, b: 0, a: 200);
      final out = ColorMatrixKit.apply(m, pixel);
      expect(out.a, 100); // 200 * 0.5
    });

    test('预览/落盘一致性：identity 对黑白灰三像素均不变', () {
      // 这是共享知识 #2 的核心断言：apply 必须与 Flutter ColorFilter.matrix 一致。
      // identity 矩阵下两者都不改变像素。
      for (final px in const [
        Rgba(r: 0, g: 0, b: 0),
        Rgba(r: 128, g: 128, b: 128),
        Rgba(r: 255, g: 255, b: 255),
      ]) {
        final out = ColorMatrixKit.apply(ColorMatrixKit.identity(), px);
        expect(out.r, px.r);
        expect(out.g, px.g);
        expect(out.b, px.b);
      }
    });
  });

  group('FilterPreset.matrixAt', () {
    test('original 任意强度都返回 identity', () {
      final m = FilterCatalog.original.matrixAt(1.0);
      expect(m, ColorMatrixKit.identity());
    });

    test('强度 0 返回 identity', () {
      final preset = FilterCatalog.byId('warm_sun');
      expect(preset.matrixAt(0), ColorMatrixKit.identity());
    });

    test('强度 1 返回完整滤镜矩阵', () {
      final preset = FilterCatalog.byId('warm_sun');
      final m = preset.matrixAt(1.0);
      expect(m[0], preset.matrix4x5[0]);
    });

    test('强度 0.5 为中点插值', () {
      final preset = FilterCatalog.byId('warm_sun');
      final half = preset.matrixAt(0.5);
      final id = ColorMatrixKit.identity();
      expect(half[0], closeTo((id[0] + preset.matrix4x5[0]) / 2, 1e-9));
    });

    test('强度 >1 clamp 到 1', () {
      final preset = FilterCatalog.byId('teal_dawn');
      expect(preset.matrixAt(1.5), preset.matrixAt(1.0));
    });

    test('强度 <0 clamp 到 0', () {
      final preset = FilterCatalog.byId('teal_dawn');
      expect(preset.matrixAt(-0.5), preset.matrixAt(0));
    });

    test('每款滤镜矩阵长度均为 20', () {
      for (final preset in FilterCatalog.all) {
        expect(preset.matrix4x5.length, 20, reason: '${preset.id} 矩阵长度非 20');
      }
    });
  });

  group('FilterCatalog', () {
    test('共 9 款（含原图）', () {
      expect(FilterCatalog.all.length, 9);
    });

    test('byId 找不到回退原图', () {
      expect(FilterCatalog.byId('not_exist').id, 'original');
    });

    test('每款 id 唯一', () {
      final ids = FilterCatalog.all.map((p) => p.id).toSet();
      expect(ids.length, FilterCatalog.all.length);
    });

    test('original 的 isOriginal=true，其余 false', () {
      expect(FilterCatalog.original.isOriginal, isTrue);
      for (final p in FilterCatalog.all.where((p) => !p.isOriginal)) {
        expect(p.isOriginal, isFalse);
      }
    });

    test('合规：名称不含商标（Doka/Kodak/Agfa/Fuji 等）', () {
      const trademarks = ['Doka', 'Kodak', 'Agfa', 'Fuji', '柯达', '阿克发', '富士'];
      for (final p in FilterCatalog.all) {
        for (final tm in trademarks) {
          expect(p.name.contains(tm), isFalse, reason: '${p.name} 含商标 $tm');
        }
      }
    });
  });
}
