/// 全局枚举定义（纯 Dart，零平台依赖）。

/// 闪光灯三态：自动 / 开 / 关
enum FlashMode3 { auto, on, off }

/// 网格样式：无 / 三分线 / 黄金分割线
enum GridStyle { none, thirds, golden }

/// 拍摄模式：普通 / 夜景 / 人像 / 延时
enum ShootMode { normal, night, portrait, timelapse }

/// 分辨率档位（A-3：iOS 端 UI 仅暴露 standard/high 两档）
enum ResolutionPreset { standard, high, veryHigh, max }

/// 美颜档位（A-2：关 / 轻 / 中，默认「轻」）
enum BeautyLevel { off, light, medium }

/// 滤镜分类
enum FilterCategory { original, portrait, film, landscape, night, food, mono }

/// 场景分类（AI 滤镜推荐 / SceneFeatures 用）
enum SceneType { portrait, landscape, food, night, other }

/// 引导线类型：三分线 / 黄金分割线
enum GuideLineType { thirds, golden }

/// 引导线方向：横向 / 纵向
enum LineAxis { horizontal, vertical }

/// 移动方向提示：左移 / 右移 / 靠近 / 拉远
enum MoveDirection { moveLeft, moveRight, moveCloser, moveFarther }

/// 建议焦段：广角 / 中焦 / 长焦（A-5：仅多镜头设备显示）
enum FocalSuggestion { wide, standard, tele }

/// 枚举扩展：中文显示名（首发仅中文，l10n 预留见 P2-5）
extension ShootModeX on ShootMode {
  String get label => switch (this) {
        ShootMode.normal => '普通',
        ShootMode.night => '夜景',
        ShootMode.portrait => '人像',
        ShootMode.timelapse => '延时',
      };
}

extension FlashMode3X on FlashMode3 {
  String get label => switch (this) {
        FlashMode3.auto => '自动',
        FlashMode3.on => '开',
        FlashMode3.off => '关',
      };
}

extension GridStyleX on GridStyle {
  String get label => switch (this) {
        GridStyle.none => '关',
        GridStyle.thirds => '三分',
        GridStyle.golden => '黄金',
      };
}

extension ResolutionPresetX on ResolutionPreset {
  String get label => switch (this) {
        ResolutionPreset.standard => '标准',
        ResolutionPreset.high => '高',
        ResolutionPreset.veryHigh => '超高',
        ResolutionPreset.max => '最大',
      };
}

extension BeautyLevelX on BeautyLevel {
  String get label => switch (this) {
        BeautyLevel.off => '关',
        BeautyLevel.light => '轻',
        BeautyLevel.medium => '中',
      };
}

extension MoveDirectionX on MoveDirection {
  String get label => switch (this) {
        MoveDirection.moveLeft => '向左移动',
        MoveDirection.moveRight => '向右移动',
        MoveDirection.moveCloser => '靠近一点',
        MoveDirection.moveFarther => '拉远一点',
      };
}

extension FocalSuggestionX on FocalSuggestion {
  String get label => switch (this) {
        FocalSuggestion.wide => '建议使用广角',
        FocalSuggestion.standard => '建议使用中焦',
        FocalSuggestion.tele => '建议使用长焦',
      };
}
