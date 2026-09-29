/// 模型 / LUT 等资源文件路径常量。
class AssetPaths {
  AssetPaths._();

  /// 量化物体检测模型（SSD MobileNetV1，约 4MB）
  static const String modelFile = 'assets/models/ssd_mobilenet_v1_quant.tflite';

  /// COCO 标签表（91 槽位，第 i 行对应类别 id=i）
  static const String labelsFile = 'assets/models/labels.txt';

  /// LUT 资源目录
  static const String lutDir = 'assets/luts/';

  // ===== 8 款原创滤镜对应的 LUT 文件（可选精修资源） =====
  static const String lutTealDawn = '${lutDir}teal_dawn.png'; // 晨雾
  static const String lutStreet200 = '${lutDir}street_200.png'; // 街拍 200
  static const String lutWarmSun = '${lutDir}warm_sun.png'; // 暖阳
  static const String lutNightPort = '${lutDir}night_port.png'; // 夜港
  static const String lutAgfaSoft = '${lutDir}agfa_soft.png'; // 柔调
  static const String lutFujiGreen = '${lutDir}fuji_green.png'; // 青野
  static const String lutKodakGold = '${lutDir}kodak_gold.png'; // 金岸
  static const String lutMonoFilm = '${lutDir}mono_film.png'; // 墨影
}
