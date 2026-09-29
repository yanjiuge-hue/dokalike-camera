import 'dart:typed_data' show Uint8List;

import 'package:equatable/equatable.dart';

import 'enums.dart';

/// 照片元数据（Hive 持久化，共享知识 #7：只存 Map，不做 TypeAdapter）。
class Photo extends Equatable {
  const Photo({
    required this.id,
    required this.filePath,
    required this.capturedAt,
    required this.filterId,
    required this.filterStrength,
    required this.shootMode,
    required this.width,
    required this.height,
    this.thumbnailPath,
  });

  final String id;

  /// 原图绝对路径（App 文档目录内）
  final String filePath;

  /// 缩略图绝对路径（相册网格用，可为空）
  final String? thumbnailPath;

  final DateTime capturedAt;

  /// 拍摄时使用的滤镜 id（'original' 表示直出）
  final String filterId;

  /// 拍摄时滤镜强度 [0,1]
  final double filterStrength;

  final ShootMode shootMode;
  final int width;
  final int height;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'capturedAt': capturedAt.millisecondsSinceEpoch,
      'filterId': filterId,
      'filterStrength': filterStrength,
      'shootMode': shootMode.index,
      'width': width,
      'height': height,
    };
  }

  static Photo fromMap(Map<dynamic, dynamic> map) {
    return Photo(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      thumbnailPath: map['thumbnailPath'] as String?,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['capturedAt'] as num).toInt(),
      ),
      filterId: map['filterId'] as String? ?? 'original',
      filterStrength: (map['filterStrength'] as num?)?.toDouble() ?? 1.0,
      shootMode: ShootMode.values[map['shootMode'] as int? ?? 0],
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
    );
  }

  Photo copyWith({
    String? id,
    String? filePath,
    String? thumbnailPath,
    DateTime? capturedAt,
    String? filterId,
    double? filterStrength,
    ShootMode? shootMode,
    int? width,
    int? height,
  }) {
    return Photo(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      capturedAt: capturedAt ?? this.capturedAt,
      filterId: filterId ?? this.filterId,
      filterStrength: filterStrength ?? this.filterStrength,
      shootMode: shootMode ?? this.shootMode,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  List<Object?> get props => [id, filePath, capturedAt];
}

/// 拍照落盘时随字节传入的拍摄上下文。
class PhotoMeta {
  const PhotoMeta({
    required this.width,
    required this.height,
    required this.filterId,
    required this.filterStrength,
    required this.shootMode,
    this.bytes,
  });

  final int width;
  final int height;
  final String filterId;
  final double filterStrength;
  final ShootMode shootMode;

  /// 原始 JPEG 字节（仅保存流程内部传递，不持久化）。
  final Uint8List? bytes;
}
