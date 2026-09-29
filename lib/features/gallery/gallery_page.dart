import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/photo.dart';
import '../../../providers/gallery_provider.dart';
import 'photo_viewer_page.dart';
import 'widgets/photo_grid_item.dart';

/// 相册页（PRD §5.6 / P1-4）：3 列网格、按时间倒序、分页懒加载。
///
/// A-4：仅展示本 App 拍摄的照片（Hive 元数据驱动）。
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  /// 滚动到底部前 200px 触发分页加载。
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(galleryProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text('相册'),
      ),
      body: gallery.photos.isEmpty
          ? _buildEmpty()
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: gallery.photos.length + (gallery.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= gallery.photos.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final photo = gallery.photos[index];
                return PhotoGridItem(
                  photo: photo,
                  onTap: () => _openViewer(context, photo),
                );
              },
            ),
    );
  }

  /// 打开大图查看页（传入全量列表，支持左右滑动切换）。
  Future<void> _openViewer(BuildContext context, Photo photo) async {
    final all = await ref.read(galleryProvider.notifier).allPhotos();
    if (!mounted) return;
    final index = all.indexWhere((p) => p.id == photo.id);
    if (index < 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PhotoViewerPage(
          photos: all,
          initialIndex: index,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_outlined, size: 56, color: Colors.white24),
          SizedBox(height: 12),
          Text('还没有照片，去拍一张吧', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
