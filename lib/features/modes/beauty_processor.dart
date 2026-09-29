import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../models/enums.dart';

/// 基础美颜（P1-2 / A-2 假设：3 档，关/轻/中）。
///
/// 实现策略（磨皮保细节、不假白）：
/// 1. **只对肤色像素**做局部均值平滑（轻：3×3 一遍；中：3×3 两遍）；
/// 2. 平滑结果与原图按权重混合，保留皮肤纹理细节；
/// 3. 轻微提亮（+4/+8），不做美白（避免假白）。
///
/// 纯 Dart（image 包），在 compute 隔离中执行，不卡 UI。
class BeautyProcessor {
  BeautyProcessor._();

  /// 各档位参数表。
  static const Map<BeautyLevel, _BeautyParams> _params = {
    BeautyLevel.off: _BeautyParams(blend: 0, passes: 0, brighten: 0),
    BeautyLevel.light: _BeautyParams(blend: 0.35, passes: 1, brighten: 4),
    BeautyLevel.medium: _BeautyParams(blend: 0.6, passes: 2, brighten: 8),
  };

  /// 处理 JPEG 字节（顶层纯函数，compute 兼容）。
  static Uint8List processBytes(Uint8List jpeg, BeautyLevel level) {
    if (level == BeautyLevel.off) return jpeg;
    final decoded = img.decodeJpg(jpeg);
    if (decoded == null) return jpeg;
    final output = _process(decoded, _params[level]!);
    return img.encodeJpg(output, quality: AppConstants.jpegQuality);
  }

  static img.Image _process(img.Image src, _BeautyParams params) {
    final output = img.Image.from(src);
    final width = src.width;
    final height = src.height;

    // 多遍 3×3 肤色局部平滑（在输出副本上迭代，第二遍基于第一遍结果）
    for (var pass = 0; pass < params.passes; pass++) {
      final snapshot = img.Image.from(output);
      for (final pixel in output) {
        final x = pixel.x;
        final y = pixel.y;
        if (!_isSkin(snapshot.getPixel(x, y))) continue;

        // 修正：image 4.x 的 Pixel 通道访问器（r/g/b）静态类型是 num，
        // num 不能直接累加进 int（invalid_assignment）。改成以 double 累加，
        // 语义不变（8bit 通道值本身就是整数，求和结果完全一致），
        // 后续 (sumR / count) 本来就要走浮点除法。count 仍保持 int。
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            final n = snapshot.getPixel(nx, ny);
            sumR += n.r;
            sumG += n.g;
            sumB += n.b;
            count++;
          }
        }
        if (count == 0) continue;

        // 与原图按权重混合：保留细节，避免过度涂抹
        pixel
          ..r = (pixel.r * (1 - params.blend) + (sumR / count) * params.blend)
              .round()
              .clamp(0, 255)
          ..g = (pixel.g * (1 - params.blend) + (sumG / count) * params.blend)
              .round()
              .clamp(0, 255)
          ..b = (pixel.b * (1 - params.blend) + (sumB / count) * params.blend)
              .round()
              .clamp(0, 255);
      }
    }

    // 轻微提亮（不改变色相，避免假白）
    if (params.brighten > 0) {
      for (final pixel in output) {
        pixel
          ..r = (pixel.r + params.brighten).clamp(0, 255)
          ..g = (pixel.g + params.brighten).clamp(0, 255)
          ..b = (pixel.b + params.brighten).clamp(0, 255);
      }
    }

    return output;
  }

  /// 简易肤色判定：R>G>B 且红色分量适中。
  static bool _isSkin(img.Pixel p) {
    final r = p.r, g = p.g, b = p.b;
    return r > 95 && r >= g && g > b && (r - b) > 15 && (r - b) < 130;
  }
}

/// 美颜参数。
class _BeautyParams {
  const _BeautyParams({
    required this.blend,
    required this.passes,
    required this.brighten,
  });

  /// 平滑混合权重 [0,1]
  final double blend;

  /// 3×3 平滑遍数
  final int passes;

  /// 提亮量（0-255）
  final int brighten;
}
