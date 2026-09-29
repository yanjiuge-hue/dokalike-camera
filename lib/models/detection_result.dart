import 'package:equatable/equatable.dart';

import '../core/utils/geometry.dart';
import 'enums.dart';

/// 检测到的人脸框（rect 为归一化坐标）。
class FaceBox extends Equatable {
  const FaceBox({required this.rect, this.smilingProbability});

  final Rect01 rect;
  final double? smilingProbability;

  @override
  List<Object?> get props => [rect];
}

/// 检测到的物体框（rect 为归一化坐标）。
class ObjectBox extends Equatable {
  const ObjectBox({
    required this.rect,
    required this.label,
    required this.confidence,
  });

  final Rect01 rect;

  /// COCO 标签（英文，如 person / dog / pizza）
  final String label;

  /// 置信度 [0,1]
  final double confidence;

  @override
  List<Object?> get props => [rect, label, confidence];
}

/// 场景特征（AI 滤镜推荐输入，P1-3 规则版）。
class SceneFeatures extends Equatable {
  const SceneFeatures({
    required this.luminance,
    required this.colorTemperature,
    required this.faceCount,
    required this.sceneType,
  });

  /// 平均亮度 [0,1]
  final double luminance;

  /// 色温指数 [0,1]：0 偏冷、0.5 中性、1 偏暖
  final double colorTemperature;

  final int faceCount;
  final SceneType sceneType;

  @override
  List<Object?> get props => [luminance, colorTemperature, faceCount, sceneType];
}

/// 帧元信息：检测结果随帧携带，供构图引擎与坐标换算使用。
class FrameMeta extends Equatable {
  const FrameMeta({
    required this.width,
    required this.height,
    required this.quarterTurns,
    required this.isFrontCamera,
    required this.previewAspect,
    this.rollAngleDeg = 0,
  });

  /// 旋转校正后（竖直方向）图像宽（像素）
  final int width;

  /// 旋转校正后（竖直方向）图像高（像素）
  final int height;

  /// 图像相对预览方向的旋转（0/1/2/3 × 90°顺时针）
  final int quarterTurns;

  /// 是否前摄（前摄预览默认镜像）
  final bool isFrontCamera;

  /// 预览区域宽高比（宽/高）
  final double previewAspect;

  /// 设备横滚角（度，来自加速度计，水平仪用；A-8 假设）
  final double rollAngleDeg;

  /// 旋转校正后图像的宽高比
  double get imageAspect => height == 0 ? 1 : width / height;

  FrameMeta copyWith({
    int? width,
    int? height,
    int? quarterTurns,
    bool? isFrontCamera,
    double? previewAspect,
    double? rollAngleDeg,
  }) {
    return FrameMeta(
      width: width ?? this.width,
      height: height ?? this.height,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      previewAspect: previewAspect ?? this.previewAspect,
      rollAngleDeg: rollAngleDeg ?? this.rollAngleDeg,
    );
  }

  @override
  List<Object?> get props =>
      [width, height, quarterTurns, isFrontCamera, previewAspect, rollAngleDeg];
}

/// 单帧检测结果（人脸 + 物体 + 场景特征合流后的产物）。
class DetectionResult extends Equatable {
  const DetectionResult({
    required this.faces,
    required this.objects,
    required this.features,
    required this.meta,
    required this.timestamp,
  });

  final List<FaceBox> faces;
  final List<ObjectBox> objects;
  final SceneFeatures features;

  /// 产生该结果的帧元信息（构图引擎需要）
  final FrameMeta meta;

  final DateTime timestamp;

  /// 用平滑后的框替换原始框（EMA 滤波在 CompositionNotifier 中做）。
  DetectionResult withBoxes({
    required List<FaceBox> faces,
    required List<ObjectBox> objects,
  }) {
    return DetectionResult(
      faces: faces,
      objects: objects,
      features: features,
      meta: meta,
      timestamp: timestamp,
    );
  }

  @override
  List<Object?> get props => [timestamp];
}
