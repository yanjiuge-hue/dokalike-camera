import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/detection_result.dart';
import 'service_providers.dart';

/// 检测结果流 Provider（时序图 4.2 的合流输出）。
final detectionResultStreamProvider =
    StreamProvider<DetectionResult>((ref) {
  return ref.watch(detectionPipelineProvider).results;
});

/// 最近一次场景特征（AI 滤镜推荐输入，时序图 4.4）。
final sceneFeaturesProvider = Provider<SceneFeatures?>((ref) {
  return ref.watch(detectionResultStreamProvider).valueOrNull?.features;
});
