import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
// 修正：Box.listenable() 不是 hive 核心库的方法，而是 hive_flutter 提供的
// 扩展方法（ValueListenable<BoxEvent>）。少了这条 import 会报
// "The method 'listenable' isn't defined for the type 'Box'"。
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../models/photo.dart';

/// 照片仓库：Photo CRUD（Hive）+ 文件读写 + 写入系统相册（P0-3）。
///
/// - Hive 只存 Map（共享知识 #7）；
/// - 元数据驱动 App 内相册（A-4：仅显示本 App 拍摄的照片）；
/// - 异步写入系统相册（gal），失败不影响 App 内相册。
class PhotoRepository {
  static const String _boxName = AppConstants.photosBoxName;
  static const String _photoDirName = 'photos';

  Box? _box;
  String? _photosDirPath;

  Future<Box> _openBox() async {
    return _box ??= await Hive.openBox(_boxName);
  }

  Future<String> _photosDir() async {
    if (_photosDirPath != null) return _photosDirPath!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _photoDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _photosDirPath = dir.path;
    return dir.path;
  }

  /// 保存照片：写文件 + 生成缩略图 + Hive 插入 + 写系统相册。
  Future<Photo> save(Uint8List bytes, PhotoMeta meta) async {
    final box = await _openBox();
    final dir = await _photosDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final filePath = p.join(dir, '$id.jpg');

    // 1) 写原图
    await File(filePath).writeAsBytes(bytes, flush: true);

    // 2) 生成缩略图（compute 隔离，避免大图卡顿）
    final thumbBytes = await compute(_makeThumbnail, bytes);
    final thumbPath = p.join(dir, '${id}_thumb.jpg');
    await File(thumbPath).writeAsBytes(thumbBytes, flush: true);

    // 3) Hive 元数据
    final photo = Photo(
      id: id,
      filePath: filePath,
      thumbnailPath: thumbPath,
      capturedAt: DateTime.now(),
      filterId: meta.filterId,
      filterStrength: meta.filterStrength,
      shootMode: meta.shootMode,
      width: meta.width,
      height: meta.height,
    );
    await box.put(id, photo.toMap());

    // 4) 异步写系统相册（失败不影响 App 内相册）
    unawaited(saveToSystemGallery(filePath));

    return photo;
  }

  /// 写入系统相册（gal，轻量平台通道封装）。
  Future<void> saveToSystemGallery(String filePath) async {
    try {
      await Gal.putImage(filePath, album: 'DokaLike');
    } catch (e) {
      debugPrint('写入系统相册失败（忽略）: $e');
    }
  }

  /// 全量照片流（按拍摄时间倒序）。Box 变化时自动重发。
  Stream<List<Photo>> watchAll() async* {
    final box = await _openBox();
    final controller = StreamController<List<Photo>>.broadcast();

    void emit() {
      final photos = _sortedPhotos(box);
      if (!controller.isClosed) controller.add(photos);
    }

    final listener = box.listenable();
    listener.addListener(emit);
    controller.onCancel = () {
      listener.removeListener(emit);
    };
    emit();

    yield* controller.stream;
  }

  /// 分页照片流（[page] 从 0 开始）。
  Stream<List<Photo>> watchPage(int page, int size) {
    return watchAll().map((all) {
      final start = page * size;
      if (start >= all.length) return const <Photo>[];
      return all.skip(start).take(size).toList(growable: false);
    });
  }

  /// 当前全量照片（快照，按时间倒序）。
  Future<List<Photo>> all() async {
    final box = await _openBox();
    return _sortedPhotos(box);
  }

  /// 仅删除索引记录（撤销窗口内文件保留，配合 [purgeFiles] / [restore]）。
  Future<void> deleteFromIndex(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  /// 恢复索引记录（撤销删除）。
  Future<void> restore(Photo photo) async {
    final box = await _openBox();
    await box.put(photo.id, photo.toMap());
  }

  /// 真正删除文件（原图 + 缩略图）。
  Future<void> purgeFiles(Photo photo) async {
    for (final path in [photo.filePath, photo.thumbnailPath]) {
      if (path == null) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('删除文件失败（忽略）: $e');
      }
    }
  }

  /// 删除照片（索引 + 文件，一步完成）。
  Future<void> delete(String id) async {
    final photo = await byId(id);
    await deleteFromIndex(id);
    if (photo != null) await purgeFiles(photo);
  }

  /// 按 id 查找。
  Future<Photo?> byId(String id) async {
    final box = await _openBox();
    final map = box.get(id);
    return map == null ? null : Photo.fromMap(Map<dynamic, dynamic>.from(map));
  }

  List<Photo> _sortedPhotos(Box box) {
    return box.values
        .map((raw) => Photo.fromMap(Map<dynamic, dynamic>.from(raw as Map)))
        .toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }
}

/// 缩略图生成（顶层函数，供 compute 调用）。
Uint8List _makeThumbnail(Uint8List jpeg) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) return jpeg;
  final thumb = img.copyResize(
    decoded,
    width: AppConstants.thumbnailWidth,
    maintainAspect: true,
  );
  return img.encodeJpg(thumb, quality: 80);
}
