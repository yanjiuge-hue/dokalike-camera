import 'package:share_plus/share_plus.dart';

/// 系统分享封装（P1-4：分享走系统分享面板）。
class ShareService {
  /// 分享单张照片。
  Future<void> sharePhoto(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/jpeg')],
      subject: 'DokaLike 相机',
    );
  }
}
