/// 4×5 颜色矩阵工具（纯 Dart，零平台依赖）。
///
/// 矩阵布局（行主序，20 个元素，与 Flutter `ColorFilter.matrix` 一致）：
/// ```text
/// [ R' ]   [ m0  m1  m2  m3  m4  ] [ R ]
/// [ G' ] = [ m5  m6  m7  m8  m9  ] [ G ]
/// [ B' ]   [ m10 m11 m12 m13 m14 ] [ B ]
/// [ A' ]   [ m15 m16 m17 m18 m19 ] [ A ]
/// ```
/// 偏移量（m4/m9/m14/m19）按 0–255 亮度尺度计算。
class ColorMatrixKit {
  ColorMatrixKit._();

  static const int matrixLength = 20;

  /// 单位矩阵（原图）。
  static List<double> identity() {
    return const <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ].toList();
  }

  /// 两矩阵线性插值（滤镜强度实现方式，共享知识 #2）。
  ///
  /// t=0 返回 a，t=1 返回 b；长度必须一致且为 20。
  static List<double> lerp(List<double> a, List<double> b, double t) {
    assert(a.length == matrixLength && b.length == matrixLength,
        '颜色矩阵必须为 4x5（20 个元素）');
    final clamped = t.clamp(0.0, 1.0);
    return List<double>.generate(
      matrixLength,
      (i) => a[i] + (b[i] - a[i]) * clamped,
    );
  }

  /// 对单个像素应用矩阵。
  static Rgba apply(List<double> m, Rgba pixel) {
    assert(m.length == matrixLength);
    final a01 = pixel.a / 255.0;
    final r = m[0] * pixel.r +
        m[1] * pixel.g +
        m[2] * pixel.b +
        m[3] * a01 * 255 +
        m[4] * 255;
    final g = m[5] * pixel.r +
        m[6] * pixel.g +
        m[7] * pixel.b +
        m[8] * a01 * 255 +
        m[9] * 255;
    final b = m[10] * pixel.r +
        m[11] * pixel.g +
        m[12] * pixel.b +
        m[13] * a01 * 255 +
        m[14] * 255;
    final a = m[15] * pixel.r +
        m[16] * pixel.g +
        m[17] * pixel.b +
        m[18] * a01 * 255 +
        m[19] * 255;
    return Rgba(
      r: _clamp255(r),
      g: _clamp255(g),
      b: _clamp255(b),
      a: _clamp255(a),
    );
  }

  static int _clamp255(double v) => v.clamp(0, 255).round();
}

/// RGBA 像素值（纯数据类）。
class Rgba {
  const Rgba({required this.r, required this.g, required this.b, this.a = 255});

  final int r;
  final int g;
  final int b;
  final int a;
}
