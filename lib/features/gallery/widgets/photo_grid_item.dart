import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/photo.dart';

/// 相册网格项：缩略图 + 点击进入大图。
///
/// 缩略图为落盘时生成的 360px 小图（PhotoRepository），内存友好；
/// 加载失败时显示占位图标（文件被外部删除等场景）。
class PhotoGridItem extends StatelessWidget {
  const PhotoGridItem({super.key, required this.photo, required this.onTap});

  final Photo photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbPath = photo.thumbnailPath ?? photo.filePath;
    return GestureDetector(
      onTap: onTap,
      child: Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Colors.white10,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white24, size: 28),
            ),
          );
        },
      ),
    );
  }
}
