import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/camera_settings.dart';
import '../models/enums.dart';
import '../services/settings_repository.dart';
import 'service_providers.dart';

/// 设置状态：读写 + 持久化副作用（P0-7 / P2-4）。
class SettingsNotifier extends Notifier<CameraSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  CameraSettings build() {
    // 同步读取（Box 已在 main() 打开），冷启动恢复上次设置（P2-4）
    return _repo.load();
  }

  Future<void> _update(CameraSettings settings) async {
    state = settings;
    await _repo.save(settings);
  }

  /// 循环切换闪光灯三态
  Future<void> cycleFlashMode() async {
    final next = switch (state.flashMode) {
      FlashMode3.auto => FlashMode3.on,
      FlashMode3.on => FlashMode3.off,
      FlashMode3.off => FlashMode3.auto,
    };
    await setFlashMode(next);
  }

  Future<void> setFlashMode(FlashMode3 mode) {
    return _update(state.copyWith(flashMode: mode));
  }

  /// 循环切换网格样式：三分 → 黄金 → 关
  Future<void> cycleGridStyle() async {
    final next = switch (state.gridStyle) {
      GridStyle.thirds => GridStyle.golden,
      GridStyle.golden => GridStyle.none,
      GridStyle.none => GridStyle.thirds,
    };
    return _update(state.copyWith(gridStyle: next));
  }

  Future<void> setGridStyle(GridStyle style) {
    return _update(state.copyWith(gridStyle: style));
  }

  /// 构图辅助一键开关（默认开启，状态持久化，P0-7）
  Future<void> toggleCompositionAssist() {
    return _update(
      state.copyWith(compositionAssistEnabled: !state.compositionAssistEnabled),
    );
  }

  Future<void> setResolution(ResolutionPreset preset) {
    return _update(state.copyWith(resolution: preset));
  }

  Future<void> setShootMode(ShootMode mode) {
    return _update(state.copyWith(shootMode: mode));
  }

  Future<void> setBeautyLevel(BeautyLevel level) {
    return _update(state.copyWith(beautyLevel: level));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, CameraSettings>(SettingsNotifier.new);
