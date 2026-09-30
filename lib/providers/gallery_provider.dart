import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/photo.dart';
import 'service_providers.dart';

/// 相册状态（P1-4：网格浏览、分页懒加载、删除可撤销）。
class GalleryState {
  const GalleryState({
    this.photos = const [],
    this.hasMore = false,
    this.loading = false,
  });

  /// 当前可见照片（按时间倒序，分页切片）
  final List<Photo> photos;

  /// 是否还有更多页
  final bool hasMore;

  final bool loading;
}

/// 相册 Notifier：分页列表、删除（二次确认 + 撤销窗口）、分享入口数据。
class GalleryNotifier extends Notifier<GalleryState> {
  List<Photo> _all = const [];
  int _visibleCount = AppConstants.galleryPageSize;

  /// 删除撤销窗口：photoId → 待清理 Timer
  final Map<String, Timer> _pendingPurge = {};

  @override
  GalleryState build() {
    final repo = ref.watch(photoRepositoryProvider);
    _all = const [];
    _visibleCount = AppConstants.galleryPageSize;

    final sub = repo.watchAll().listen((photos) {
      _all = photos;
      _updateVisible();
    });
    ref.onDispose(() {
      sub.cancel();
      for (final timer in _pendingPurge.values) {
        timer.cancel();
      }
      _pendingPurge.clear();
    });

    return const GalleryState(loading: true);
  }

  void _updateVisible() {
    state = GalleryState(
      photos: _all.take(_visibleCount).toList(growable: false),
      hasMore: _all.length > _visibleCount,
      loading: false,
    );
  }

  /// 加载下一页（滚动到底部触发）。
  void loadMore() {
    if (!state.hasMore) return;
    _visibleCount += AppConstants.galleryPageSize;
    _updateVisible();
  }

  /// 全量照片快照（大图页 PageView 需要）。
  Future<List<Photo>> allPhotos() {
    return ref.read(photoRepositoryProvider).all();
  }

  /// 删除照片：先移除索引（可撤销），[AppConstants.galleryUndoWindow]
  /// 后真正删除文件。
  Future<void> delete(Photo photo) async {
    final repo = ref.read(photoRepositoryProvider);
    await repo.deleteFromIndex(photo.id);
    _pendingPurge[photo.id]?.cancel();
    _pendingPurge[photo.id] = Timer(AppConstants.galleryUndoWindow, () {
      _pendingPurge.remove(photo.id);
      repo.purgeFiles(photo);
    });
  }

  /// 撤销删除：恢复索引记录（文件仍在撤销窗口内保留）。
  Future<void> undoDelete(Photo photo) async {
    final timer = _pendingPurge.remove(photo.id);
    timer?.cancel();
    await ref.read(photoRepositoryProvider).restore(photo);
  }
}

final galleryProvider =
    NotifierProvider<GalleryNotifier, GalleryState>(GalleryNotifier.new);
