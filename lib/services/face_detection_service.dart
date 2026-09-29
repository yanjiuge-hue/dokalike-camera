import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/utils/geometry.dart';
import '../models/detection_result.dart';

/// ML Kit 人脸检测封装（P0-5）。
///
/// ML Kit 推理运行在平台原生线程，直接 async 调用即可，不进 Isolate
/// （架构 §1.1）。检测输入复用 DetectionPipeline 的当前采样帧。
class FaceDetectionService {
  FaceDetectionService({FaceDetector? detector})
      : _detector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                performanceMode: PerformanceMode.fast,
                enableLandmarks: false,
                enableContours: false,
                enableClassification: true, // 微笑概率（FaceBox.smilingProbability）
                enableTracking: false,
                minFaceSize: 0.1,
              ),
            );

  final FaceDetector _detector;

  /// 检测一帧中的人脸。
  ///
  /// 返回的 [FaceBox.rect] 为**竖直方向（旋转校正后）归一化坐标**——
  /// 由调用方（DetectionPipeline）经 CoordinateMapper 完成镜像与裁剪。
  ///
  /// 假设说明：ML Kit 在携带 rotation 元数据时返回的人脸框位于旋转
  /// 校正后的坐标系；若真机验证发现坐标系相反，仅需调整此处
  /// width/height 交换逻辑，其余模块不受影响。
  Future<List<FaceBox>> detect(
    cam.CameraImage frame,
    InputImageRotation rotation,
  ) async {
    final inputImage = _buildInputImage(frame, rotation);
    if (inputImage == null) return const <FaceBox>[];

    try {
      final faces = await _detector.processImage(inputImage);
      // 旋转校正后的宽高（90/270 度时交换）
      final rotated =
          rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg;
      final w = (rotated ? frame.height : frame.width).toDouble();
      final h = (rotated ? frame.width : frame.height).toDouble();

      return faces
          .map((face) => FaceBox(
                rect: Rect01.fromLTWH(
                  face.boundingBox.left / w,
                  face.boundingBox.top / h,
                  face.boundingBox.width / w,
                  face.boundingBox.height / h,
                ),
                smilingProbability: face.smilingProbability,
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('人脸检测失败（丢帧）: $e');
      return const <FaceBox>[];
    }
  }

  /// CameraImage → InputImage（拼接各平面字节 + 元数据）。
  InputImage? _buildInputImage(cam.CameraImage frame, InputImageRotation rotation) {
    try {
      // 拼接所有平面字节（NV21 / YUV_420_888 均按顺序拼接）
      final totalBytes = frame.planes.fold<int>(
        0,
        (sum, plane) => sum + plane.bytes.length,
      );
      final bytes = Uint8List(totalBytes);
      var offset = 0;
      for (final plane in frame.planes) {
        bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format == null) return null;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('构造 InputImage 失败（丢帧）: $e');
      return null;
    }
  }

  /// 释放检测器
  void dispose() {
    _detector.close();
  }
}
