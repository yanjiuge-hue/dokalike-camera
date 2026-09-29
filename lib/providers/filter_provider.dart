import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/filters/data/filter_catalog.dart';
import '../features/filters/engine/filter_recommender.dart';
import '../models/detection_result.dart' show SceneFeatures;
import '../models/enums.dart' show SceneType;
import '../models/filter_recommendation.dart';
import '../services/settings_repository.dart';
import 'detection_provider.dart';
import 'service_providers.dart';

/// 滤镜状态（P0-8 / P0-9 / P1-3）。
class FilterState {
  const FilterState({
    required this.currentId,
    required this.strength,
    this.recommendations = const [],
  });

  /// 当前滤镜 id（'original' = 直出）
  final String currentId;

  /// 强度 [0,1]（UI 显示 0–100%）
  final double strength;

  /// AI 推荐列表（打开推荐面板时生成，按置信度降序）
  final List<FilterRecommendation> recommendations;

  bool get isOriginal => currentId == FilterCatalog.original.id;
}

/// 滤镜 Notifier：当前滤镜/强度/推荐列表状态。
///
/// 强度调节 = 恒等矩阵与滤镜矩阵按强度插值（FilterPreset.matrixAt），
/// 预览与落盘共用同一结果（共享知识 #2）。
class FilterNotifier extends Notifier<FilterState> {
  final FilterRecommender _recommender = const FilterRecommender();

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  FilterState build() {
    // P2-4 轻记忆：冷启动恢复上次滤镜
    final saved = _repo.loadFilterSelection();
    return FilterState(
      currentId: saved?['id'] as String? ?? FilterCatalog.original.id,
      strength: (saved?['strength'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Future<void> _persist() async {
    await _repo.saveFilterSelection(state.currentId, state.strength);
  }

  /// 切换滤镜（实时预览即时生效）。
  Future<void> setFilter(String id) async {
    if (state.currentId == id) return;
    state = FilterState(
      currentId: id,
      strength: state.strength,
      recommendations: state.recommendations,
    );
    await _persist();
  }

  /// 设置强度 [0,1]（0-100% 无级调节，实时生效）。
  Future<void> setStrength(double strength) async {
    final clamped = strength.clamp(0.0, AppConstants.filterStrengthMax);
    state = FilterState(
      currentId: state.currentId,
      strength: clamped,
      recommendations: state.recommendations,
    );
    await _persist();
  }

  /// 一键应用 AI 推荐（P1-3）：应用并重置强度为 100%。
  Future<void> applyRecommendation(FilterRecommendation recommendation) async {
    state = FilterState(
      currentId: recommendation.filterId,
      strength: 1.0,
      recommendations: state.recommendations,
    );
    await _persist();
  }

  /// 生成 AI 推荐（规则版 MVP）：基于最近场景特征打分排序。
  void generateRecommendations() {
    final features = ref.read(sceneFeaturesProvider);
    final catalog = ref.read(filterCatalogProvider);
    // 无检测数据时使用中性默认特征（首次打开相机即点推荐的场景）
    const fallback = SceneFeatures(
      luminance: 0.5,
      colorTemperature: 0.5,
      faceCount: 0,
      sceneType: SceneType.other,
    );
    state = FilterState(
      currentId: state.currentId,
      strength: state.strength,
      recommendations: _recommender.recommend(features ?? fallback, catalog),
    );
  }
}

final filterProvider =
    NotifierProvider<FilterNotifier, FilterState>(FilterNotifier.new);
