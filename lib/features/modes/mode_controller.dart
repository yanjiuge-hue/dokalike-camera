import '../../core/constants/app_constants.dart';
import '../../models/enums.dart';
import '../../services/camera_service.dart';

/// 拍摄模式编排（P1-5 / T05）。
///
/// 职责：把抽象的 [ShootMode] 翻译成相机硬件参数变化：
/// - 夜景：曝光补偿 +0.7 EV（A-7：不做多帧合成，多帧策略接口预留
///   [NightModeStrategy]）+「夜港」滤镜联动（联动在 CameraNotifier 中编排）；
/// - 人像：美颜管线（FilterPipeline.applyBeauty，档位来自设置）；
/// - 延时：定时连拍（TimelapseController 编排）；
/// - 普通：恢复默认曝光。
class ModeController {
  ModeController({required CameraService cameraService})
      : _cameraService = cameraService;

  final CameraService _cameraService;

  /// 应用模式相关的相机硬件参数。
  Future<void> apply(ShootMode mode) async {
    switch (mode) {
      case ShootMode.night:
        // 夜景：提升曝光补偿（A-7）
        await _cameraService.setExposureOffset(
          AppConstants.nightExposureOffset,
        );
      case ShootMode.portrait:
      case ShootMode.normal:
      case ShootMode.timelapse:
        // 其余模式恢复默认曝光
        await _cameraService.setExposureOffset(0);
    }
  }
}

/// 夜景多帧合成策略接口（A-7 预留，MVP 不实现）。
abstract interface class NightModeStrategy {
  /// 多帧合成入口：输入连拍字节序列，输出合成后的 JPEG。
  Future<List<int>> mergeFrames(List<List<int>> frames);
}
