import 'package:equatable/equatable.dart';

import 'enums.dart';

/// 相机设置（P0-2 / P0-7 / P2-4：轻记忆，冷启动恢复）。
class CameraSettings extends Equatable {
  const CameraSettings({
    this.flashMode = FlashMode3.auto,
    this.gridStyle = GridStyle.thirds,
    this.resolution = ResolutionPreset.high,
    this.compositionAssistEnabled = true,
    this.shootMode = ShootMode.normal,
    this.beautyLevel = BeautyLevel.light,
  });

  final FlashMode3 flashMode;
  final GridStyle gridStyle;
  final ResolutionPreset resolution;

  /// 构图辅助开关（默认开启，P0-7）
  final bool compositionAssistEnabled;

  final ShootMode shootMode;
  final BeautyLevel beautyLevel;

  static const CameraSettings defaults = CameraSettings();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'flashMode': flashMode.index,
      'gridStyle': gridStyle.index,
      'resolution': resolution.index,
      'compositionAssistEnabled': compositionAssistEnabled,
      'shootMode': shootMode.index,
      'beautyLevel': beautyLevel.index,
    };
  }

  static CameraSettings fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;
    return CameraSettings(
      flashMode: FlashMode3.values[map['flashMode'] as int? ?? 0],
      gridStyle: GridStyle.values[map['gridStyle'] as int? ?? 1],
      resolution: ResolutionPreset.values[map['resolution'] as int? ?? 1],
      compositionAssistEnabled: map['compositionAssistEnabled'] as bool? ?? true,
      shootMode: ShootMode.values[map['shootMode'] as int? ?? 0],
      beautyLevel: BeautyLevel.values[map['beautyLevel'] as int? ?? 1],
    );
  }

  CameraSettings copyWith({
    FlashMode3? flashMode,
    GridStyle? gridStyle,
    ResolutionPreset? resolution,
    bool? compositionAssistEnabled,
    ShootMode? shootMode,
    BeautyLevel? beautyLevel,
  }) {
    return CameraSettings(
      flashMode: flashMode ?? this.flashMode,
      gridStyle: gridStyle ?? this.gridStyle,
      resolution: resolution ?? this.resolution,
      compositionAssistEnabled:
          compositionAssistEnabled ?? this.compositionAssistEnabled,
      shootMode: shootMode ?? this.shootMode,
      beautyLevel: beautyLevel ?? this.beautyLevel,
    );
  }

  @override
  List<Object?> get props => [
        flashMode,
        gridStyle,
        resolution,
        compositionAssistEnabled,
        shootMode,
        beautyLevel,
      ];
}
