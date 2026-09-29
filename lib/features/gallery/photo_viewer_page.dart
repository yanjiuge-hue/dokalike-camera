import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/enums.dart';
import '../../../models/photo.dart';
import '../../../providers/gallery_provider.dart';
import '../../../providers/service_providers.dart';

/// 大图查看页（PRD §5.6 / P1-4）：左右滑动切换、双指缩放、
/// 信息查看、分享、删除（二次确认 + 撤销 Snackbar）。
class PhotoViewerPage extends ConsumerStatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<Photo> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends ConsumerState<PhotoViewerPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        leading: const BackButton(color: Colors.white),
        title: const Text('照片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white24, size: 56),
                  );
                },
              ),
            ),
          );
        },
      ),
      // 底部悬浮操作条：分享 / 删除
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.share_outlined,
                label: '分享',
                onTap: _shareCurrent,
              ),
              _ActionButton(
                icon: Icons.delete_outline,
                label: '删除',
                onTap: _confirmDeleteCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Photo get _currentPhoto {
    final index = _pageController.page?.round() ?? widget.initialIndex;
    return widget.photos[index.clamp(0, widget.photos.length - 1)];
  }

  /// 系统分享面板（P1-4）。
  Future<void> _shareCurrent() async {
    await ref.read(shareServiceProvider).sharePhoto(_currentPhoto.filePath);
  }

  /// 删除：二次确认（Dialog）→ 删除 → Snackbar 撤销（P1-4）。
  Future<void> _confirmDeleteCurrent() async {
    final photo = _currentPhoto;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17181C),
        title: const Text('删除这张照片？'),
        content: const Text('删除后可在几秒内撤销，之后将从本 App 相册移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(galleryProvider.notifier);
    await notifier.delete(photo);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已删除'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => notifier.undoDelete(photo),
        ),
      ),
    );
  }

  /// 照片信息底部浮层（拍摄时间 / 模式 / 滤镜 / 尺寸）。
  void _showInfoSheet(BuildContext context) {
    final photo = _currentPhoto;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('照片信息',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _infoRow('拍摄时间', dateFormat.format(photo.capturedAt)),
                _infoRow('拍摄模式', photo.shootMode.label),
                _infoRow('滤镜', photo.filterId),
                _infoRow('滤镜强度', '${(photo.filterStrength * 100).round()}%'),
                _infoRow('尺寸', '${photo.width} × ${photo.height}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
