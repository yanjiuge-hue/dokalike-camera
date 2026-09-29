import 'package:equatable/equatable.dart';

import '../features/filters/engine/color_matrix.dart';
import 'enums.dart';

/// 滤镜预设：预览与落盘共用的统一滤镜模型（共享知识 #2）。
///
/// - 预览层：`ColorFiltered(colorFilter: ColorFilter.matrix(matrixAt(strength)))`
/// - 落盘层：`FilterPipeline` 用同一 `matrixAt(strength)` 逐像素应用
/// 强度 = 矩阵与单位矩阵的线性插值，保证「所见即所得」。
class FilterPreset extends Equatable {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.matrix4x5,
    required this.category,
    this.lutAsset,
    this.isOriginal = false,
  }) : assert(matrix4x5.length == 20, '颜色矩阵必须为 4x5（20 个元素）');

  /// 滤镜 id（snake_case 英文）
  final String id;

  /// 展示名（2–4 字原创中文词，合规红线：不含任何商标名）
  final String name;

  /// 4×5 颜色矩阵（行主序：R 行 5 元素、G 行 5、B 行 5、A 行 5）
  final List<double> matrix4x5;

  /// 可选 LUT 资源路径（缺失时自动降级为纯矩阵）
  final String? lutAsset;

  final FilterCategory category;

  /// 是否为「原图」（恒等矩阵，直出）
  final bool isOriginal;

  /// 按强度 [0,1] 返回与单位矩阵插值后的矩阵。
  ///
  /// 预览与落盘必须共用本方法的结果，禁止 UI 侧另写矩阵。
  List<double> matrixAt(double strength) {
    final t = strength.clamp(0.0, 1.0);
    if (isOriginal || t <= 0) {
      return ColorMatrixKit.identity();
    }
    if (t >= 1) {
      return List<double>.of(matrix4x5);
    }
    return ColorMatrixKit.lerp(
      ColorMatrixKit.identity(),
      matrix4x5,
      t,
    );
  }

  @override
  List<Object?> get props => [id, name, category, isOriginal];
}
