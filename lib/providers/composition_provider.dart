import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/ema_filter.dart';
import '../features/composition/engine/composition_engine.dart';
import '../models/composition_advice.dart';
import '../models/detection_result.dart';
import 'detection_provider.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

/// 构图辅助状态（P0-6：引导线经 EMA 滤波后的稳定输出）。
class CompositionState {
  const CompositionState({
    required this.enabled,
    this.advice,
    this.rollAngle = 0,
  });

  /// 构图辅助总开关（P0-7，持久化于 settings）
  final bool enabled;

  /// 最近一次构图评估（含平滑后的引导线/提示）
  final CompositionAdvice? advice;

  /// 传感器横滚角（度，水平仪实时指示）
  final double rollAngle;

  static const CompositionState initial = CompositionState(enabled: true);

  CompositionState copyWith({
    bool? enabled,
    CompositionAdvice? advice,
    double? rollAngle,
    bool clearAdvice = false,
  }) {
    return CompositionState(
      enabled: enabled ?? this.enabled,
      advice: clearAdvice ? null : (advice ?? this.advice),
      rollAngle: rollAngle ?? this.rollAngle,
    );
  }
}

/// 构图 Notifier：检测结果流 → EMA 滤波 → 规则引擎 → 引导层状态。
///
/// EMA 槽位策略（MVP）：人脸/物体各自按面积排序后取前 5 个，槽位 =
/// 排序后索引。目标丢失时 EmaFilter 保持上一状态（防跳变），连续
/// 5 次丢失后淡出（见 EmaFilter）。
class CompositionNotifier extends Notifier<CompositionState> {
  static const int _slotCount = 5;

  final CompositionEngine _engine = CompositionEngine();
  final List<EmaFilter> _faceSlots =
      List.generate(_slotCount, (_) => EmaFilter());
  final List<EmaFilter> _objectSlots =
      List.generate(_slotCount, (_) => EmaFilter());

  @override
  CompositionState build() {
    final enabled = ref.watch(settingsProvider).compositionAssistEnabled;

    // 订阅检测结果流（时序图 4.2：NP 汇聚点）
    ref.listen<AsyncValue<DetectionResult>>(
      detectionResultStreamProvider,
      (_, next) {
        final result = next.valueOrNull;
        if (result != null) _onResult(result);
      },
    );

    // 订阅水平仪横滚角（A-8：加速度计来源）
    ref.listen<AsyncValue<double>>(rollAngleStreamProvider, (_, next) {
      final angle = next.valueOrNull;
      if (angle != null && state.rollAngle != angle) {
        state = state.copyWith(rollAngle: angle);
      }
    });

    return CompositionState(enabled: enabled);
  }

  /// 开关切换时清理引导层显示。
  void onEnabledChanged(bool enabled) {
    if (!enabled) {
      state = state.copyWith(enabled: false, clearAdvice: true);
      for (final slot in [..._faceSlots, ..._objectSlots]) {
        slot.reset();
      }
    } else {
      state = state.copyWith(enabled: true);
    }
  }

  void _onResult(DetectionResult raw) {
    if (!state.enabled) return;

    // 1) 主体框逐槽位 EMA 滤波（防漂移，P0-6）
    final smoothed = _smooth(raw);

    // 2) 传感器横滚角注入 FrameMeta（覆盖管线默认 0 值）
    final meta = raw.meta.copyWith(rollAngleDeg: state.rollAngle);

    // 3) 规则引擎评估（纯 Dart 同步，快路径）
    final advice = _engine.evaluate(smoothed, meta);

    state = state.copyWith(advice: advice);
  }

  /// 人脸/物体框平滑：按面积排序取前 5，槽位索引对应 EmaFilter。
  DetectionResult _smooth(DetectionResult raw) {
    final faces = [...raw.faces]..sort((a, b) => b.rect.area.compareTo(a.rect.area));
    final objects = [...raw.objects]
      ..sort((a, b) => b.rect.area.compareTo(a.rect.area));

    final smoothedFaces = <FaceBox>[];
    for (var i = 0; i < faces.length && i < _slotCount; i++) {
      final rect = _faceSlots[i].updateRect(faces[i].rect);
      if (rect != null) {
        smoothedFaces.add(FaceBox(
          rect: rect,
          smilingProbability: faces[i].smilingProbability,
        ));
      }
    }
    // 未使用的槽位喂 null，驱动丢失计数/淡出
    for (var i = faces.length; i < _slotCount; i++) {
      _faceSlots[i].updateRect(null);
    }

    final smoothedObjects = <ObjectBox>[];
    for (var i = 0; i < objects.length && i < _slotCount; i++) {
      final rect = _objectSlots[i].updateRect(objects[i].rect);
      if (rect != null) {
        smoothedObjects.add(ObjectBox(
          rect: rect,
          label: objects[i].label,
          confidence: objects[i].confidence,
        ));
      }
    }
    for (var i = objects.length; i < _slotCount; i++) {
      _objectSlots[i].updateRect(null);
    }

    return raw.withBoxes(faces: smoothedFaces, objects: smoothedObjects);
  }
}

final compositionProvider =
    NotifierProvider<CompositionNotifier, CompositionState>(
        CompositionNotifier.new);
