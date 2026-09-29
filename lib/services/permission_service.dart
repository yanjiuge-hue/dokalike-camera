import 'package:permission_handler/permission_handler.dart';

/// 权限服务：相机 / 相册保存权限的请求与降级引导。
class PermissionService {
  /// 确保相机权限。返回是否已授权。
  Future<bool> ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }

  /// 确保保存到系统相册的权限（iOS 为「添加照片」有限权限；
  /// Android 10+ 由 MediaStore 自动处理，无需权限）。
  Future<bool> ensureGallerySavePermission() async {
    final status = await Permission.photosAddOnly.status;
    if (status.isGranted) return true;
    final result = await Permission.photosAddOnly.request();
    return result.isGranted;
  }

  /// 跳转系统设置页（权限被永久拒绝时的降级引导）。
  Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
