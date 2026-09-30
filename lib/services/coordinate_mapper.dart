import 'dart:ui' show Rect;

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/utils/geometry.dart';
import '../models/detection_result.dart';

/// 坐标映射器：图像帧坐标 → 预览归一化坐标（共享知识 #1）。
///
/// 职责单一：
/// 1. 传感器方向（quarterTurns）→ ML Kit 旋转参数；
/// 2. 检测框（竖直方向像素坐标）→ 归一化 [0,1]；
/// 3. 前摄镜像；
/// 4. 预览 aspect-fill 裁剪（居中裁切）。
///
/// 构图引擎/引导层只见归一化坐标，绝不直接接触 CameraImage。
class CoordinateMapper {
  CoordinateMapper({this.description});

  cam.CameraDescription? description;

  /// 更新相机描述（初始化 / 切换前后摄后调用）
  void updateDescription(cam.CameraDescription? desc) {
    description = desc;
  }

  /// ML Kit InputImageRotation（Android = sensorOrientation；iOS 恒 0，
  /// 因为 camera 插件在 iOS 上输出的帧已按设备方向旋转）。
  InputImageRotation get currentRotation {
    final desc = description;
    if (desc == null) return InputImageRotation.rotation0deg;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return InputImageRotation.values.firstWhere(
        (r) => r.rawValue == desc.sensorOrientation,
        orElse: () => InputImageRotation.rotation0deg,
      );
    }
    return InputImageRotation.rotation0deg;
  }

  /// 竖直方向（旋转校正后）像素矩形 → 预览归一化矩形。
  ///
  /// [imageRect] 的坐标系：与预览同向（已按 [FrameMeta.quarterTurns] 旋转
  /// 校正）的像素坐标；[meta.width]/[meta.height] 为旋转校正后的宽高。
  Rect01 mapRect(Rect imageRect, FrameMeta meta) {
    final w = meta.width <= 0 ? 1 : meta.width;
    final h = meta.height <= 0 ? 1 : meta.height;
    return mapNormalized(
      Rect01.fromLTWH(
        imageRect.left / w,
        imageRect.top / h,
        imageRect.width / w,
        imageRect.height / h,
      ),
      meta,
    );
  }

  /// 归一化矩形（竖直方向坐标）→ 预览归一化矩形（镜像 + 裁剪）。
  Rect01 mapNormalized(Rect01 rect, FrameMeta meta) {
    var mapped = rect;

    // 1) 前摄镜像（预览所见为镜像画面）
    if (meta.isFrontCamera) {
      mapped = Rect01(
        left: 1 - mapped.right,
        top: mapped.top,
        right: 1 - mapped.left,
        bottom: mapped.bottom,
      );
    }

    // 2) aspect-fill 居中裁剪：把图像裁到与预览相同的宽高比
    final imageAspect = meta.imageAspect;
    final previewAspect = meta.previewAspect <= 0 ? imageAspect : meta.previewAspect;
    if (imageAspect > previewAspect) {
      // 图像更宽：水平方向裁掉两侧
      final visible = previewAspect / imageAspect;
      final margin = (1 - visible) / 2;
      mapped = Rect01(
        left: (mapped.left - margin) / visible,
        top: mapped.top,
        right: (mapped.right - margin) / visible,
        bottom: mapped.bottom,
      );
    } else if (imageAspect < previewAspect) {
      // 图像更高：垂直方向裁掉上下
      final visible = imageAspect / previewAspect;
      final margin = (1 - visible) / 2;
      mapped = Rect01(
        left: mapped.left,
        top: (mapped.top - margin) / visible,
        right: mapped.right,
        bottom: (mapped.bottom - margin) / visible,
      );
    }

    return mapped.clamp01();
  }

  /// 归一化矩形按 quarterTurns 顺时针旋转（绕画面中心）。
  /// 委托给纯函数 [rotateQuarterTurns]（geometry.dart）。
  static Rect01 rotateNormalized(Rect01 rect, int quarterTurns) {
    return rotateQuarterTurns(rect, quarterTurns);
  }
}
