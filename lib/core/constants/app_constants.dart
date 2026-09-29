/// 全局常量集中定义（共享知识 #8：禁止魔法数字散落）。
///
/// 本文件为纯 Dart，禁止 import 任何平台/UI 依赖。
class AppConstants {
  AppConstants._();

  // ===== 帧采样与推理 =====
  /// 预览帧采样间隔（P0-4：约 200ms 一帧）
  static const Duration frameSampleInterval = Duration(milliseconds: 200);

  /// 物体检测置信度阈值
  static const double objectConfidenceThreshold = 0.5;

  // ===== EMA 低通滤波 =====
  /// EMA 平滑系数：新值权重 α=0.3（共享知识约定）
  static const double emaAlpha = 0.3;

  /// 目标连续丢失 N 帧后内部状态置空（触发 UI 淡出而非跳变）
  static const int emaMissLimit = 5;

  // ===== 构图规则 =====
  /// 构图良好阈值：score ≥ 0.8 视为优秀构图（P2-1 达成反馈）
  static const double goodCompositionThreshold = 0.8;

  /// 主体最小面积占比：小于 8% 判定「主体过小」
  static const double subjectMinAreaRatio = 0.08;

  /// 主体最大面积占比：大于 65% 判定「主体过大」
  static const double subjectMaxAreaRatio = 0.65;

  /// 主体中心安全区半径（水平方向，归一化）
  static const double subjectCenterMarginX = 0.22;

  /// 主体中心安全区半径（垂直方向，归一化）
  static const double subjectCenterMarginY = 0.28;

  /// 主体理想中心点（略高于画面中心，符合视觉习惯）
  static const double subjectIdealCenterX = 0.5;
  static const double subjectIdealCenterY = 0.42;

  /// 三分法/黄金分割吸附判定距离（归一化距离）
  static const double snapDistance = 0.08;

  /// 三分线位置
  static const List<double> thirdsPositions = [1 / 3, 2 / 3];

  /// 黄金分割线位置（φ ≈ 0.618）
  static const List<double> goldenPositions = [0.382, 0.618];

  /// 水平校正容差角度（度）：|roll| ≤ 2° 视为水平
  static const double horizonToleranceDeg = 2.0;

  /// 水平仪满偏角度（度）：超出该角度评分为 0
  static const double horizonFullScaleDeg = 10.0;

  /// 主体被裁切判定余量（归一化，框越界超过该值视为被裁切）
  static const double clipEpsilon = 0.02;

  // ===== 滤镜 =====
  /// 滤镜强度上限（内部 [0,1]，UI 显示 0–100%）
  static const double filterStrengthMax = 1.0;

  /// 滤镜强度下限（低于该值视为原图直出）
  static const double filterStrengthMinEffective = 0.01;

  /// LUT 与颜色矩阵结果的混合权重上限
  static const double lutBlendWeight = 0.4;

  /// 落盘 JPEG 编码质量
  static const int jpegQuality = 92;

  /// AI 推荐列表最大条数
  static const int recommendationLimit = 5;

  // ===== 相册 =====
  /// 相册分页大小
  static const int galleryPageSize = 30;

  /// 相册删除撤销保留时长（超时后真正删除文件）
  static const Duration galleryUndoWindow = Duration(seconds: 6);

  /// 缩略图宽度（像素）
  static const int thumbnailWidth = 360;

  // ===== 延时摄影（MVP = 定时连拍，A-1 假设） =====
  /// 延时默认连拍张数
  static const int timelapseDefaultCount = 10;

  /// 延时默认拍摄间隔
  static const Duration timelapseDefaultInterval = Duration(seconds: 2);

  // ===== 夜景模式（A-7 假设：曝光补偿，非多帧合成） =====
  /// 夜景模式曝光补偿值（EV）
  static const double nightExposureOffset = 0.7;

  // ===== Hive 存储约定（共享知识 #5） =====
  /// 设置 Box 名
  static const String settingsBoxName = 'settings';

  /// 照片元数据 Box 名
  static const String photosBoxName = 'photos';
}
