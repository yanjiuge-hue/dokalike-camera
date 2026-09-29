import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import '../core/constants/app_constants.dart';
import '../features/modes/beauty_processor.dart';
import '../models/enums.dart';
import '../models/filter_preset.dart';

/// 落盘滤镜管线（P0-8/P0-9：所见即所得）。
///
/// 预览用 `ColorFiltered(matrixAt(strength))`，落盘用同一矩阵逐像素应用
/// （+ 可选 LUT 精修），JPEG quality=92 编码。全部在 `compute()` 隔离中
/// 执行，避免 12MP+ 大图卡顿 UI（性能预算：≤1.5s）。
class FilterPipeline {
  /// 对 JPEG 字节应用滤镜。
  ///
  /// - 原图或强度≈0：直接返回原字节；
  /// - LUT 资源缺失时自动降级为纯矩阵（不抛错）。
  Future<Uint8List> applyToBytes(
    Uint8List jpeg,
    FilterPreset preset,
    double strength,
  ) async {
    if (preset.isOriginal || strength <= AppConstants.filterStrengthMinEffective) {
      return jpeg;
    }
    final matrix = preset.matrixAt(strength);

    Uint8List? lutBytes;
    final lutAsset = preset.lutAsset;
    if (lutAsset != null) {
      try {
        lutBytes = (await rootBundle.load(lutAsset)).buffer.asUint8List();
      } catch (_) {
        // LUT 缺失：静默降级为纯矩阵
        lutBytes = null;
      }
    }

    return compute(
      _applyFilterJob,
      _FilterJob(jpeg: jpeg, matrix: matrix, lutBytes: lutBytes, strength: strength),
    );
  }

  /// 对 JPEG 字节应用美颜（人像模式 / 前摄，P1-2）。
  Future<Uint8List> applyBeauty(Uint8List jpeg, BeautyLevel level) async {
    if (level == BeautyLevel.off) return jpeg;
    return compute(_beautyJob, _BeautyJob(jpeg: jpeg, level: level));
  }
}

/// compute() 任务参数（必须为可跨 Isolate 传输的普通对象）。
class _FilterJob {
  const _FilterJob({
    required this.jpeg,
    required this.matrix,
    required this.strength,
    this.lutBytes,
  });

  final Uint8List jpeg;
  final List<double> matrix;
  final double strength;
  final Uint8List? lutBytes;
}

class _BeautyJob {
  const _BeautyJob({required this.jpeg, required this.level});

  final Uint8List jpeg;
  final BeautyLevel level;
}

/// 滤镜任务（顶层函数，供 compute 调用）。
Uint8List _applyFilterJob(_FilterJob job) {
  final decoded = img.decodeJpg(job.jpeg);
  if (decoded == null) return job.jpeg;

  // LUT 精修：256×1 色调条（见 assets/luts/README.md 格式约定）
  img.Image? lut;
  if (job.lutBytes != null) {
    lut = img.decodePng(job.lutBytes!);
    if (lut != null && (lut.width < 256 || lut.height != 1)) {
      lut = null; // 尺寸不符合约定则忽略
    }
  }
  final lutBlend = AppConstants.lutBlendWeight * job.strength;

  final m = job.matrix;
  final output = img.Image.from(decoded);

  for (final pixel in output) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final a01 = pixel.a / 255.0;

    var nr = m[0] * r + m[1] * g + m[2] * b + m[3] * a01 * 255 + m[4] * 255;
    var ng = m[5] * r + m[6] * g + m[7] * b + m[8] * a01 * 255 + m[9] * 255;
    var nb = m[10] * r + m[11] * g + m[12] * b + m[13] * a01 * 255 + m[14] * 255;

    // LUT 混合：按亮度采样色调条
    if (lut != null) {
      final lum = (0.299 * nr + 0.587 * ng + 0.114 * nb).clamp(0, 255);
      final lutPixel = lut.getPixel(lum.round(), 0);
      nr = nr * (1 - lutBlend) + lutPixel.r * lutBlend;
      ng = ng * (1 - lutBlend) + lutPixel.g * lutBlend;
      nb = nb * (1 - lutBlend) + lutPixel.b * lutBlend;
    }

    pixel
      ..r = nr.clamp(0, 255).round()
      ..g = ng.clamp(0, 255).round()
      ..b = nb.clamp(0, 255).round();
  }

  return img.encodeJpg(output, quality: AppConstants.jpegQuality);
}

/// 美颜任务（委托给 BeautyProcessor 的纯函数实现）。
Uint8List _beautyJob(_BeautyJob job) {
  return BeautyProcessor.processBytes(job.jpeg, job.level);
}
