import '../../core/constants/app_constants.dart';
import 'geometry.dart';

/// EMA（指数移动平均）低通滤波器（P0-6：引导线防漂移核心）。
///
/// 约定（共享知识）：
/// - α = 0.3（新值权重）；
/// - 目标丢失（输入 null）时**保持上一状态**（引导线不跳变），
///   连续丢失 [missLimit] 次后内部状态置空，触发 UI 淡出。
///
/// 纯 Dart、零平台依赖，QA 可直接用 `dart test` 覆盖。
class EmaFilter {
  EmaFilter({double? alpha, int? missLimit})
      : alpha = (alpha ?? AppConstants.emaAlpha).clamp(0.0, 1.0),
        missLimit = missLimit ?? AppConstants.emaMissLimit;

  /// 平滑系数：新值权重（0=完全保持旧值，1=不滤波）。
  final double alpha;

  /// 连续丢失多少次后清空状态。
  final int missLimit;

  Offset01? _point;
  Rect01? _rect;
  int _missCount = 0;

  /// 当前平滑后的点（只读快照）。
  Offset01? get point => _point;

  /// 当前平滑后的矩形（只读快照）。
  Rect01? get rect => _rect;

  /// 是否处于「丢失保持」阶段（状态尚未清空但已连续丢帧）。
  bool get isHolding => _missCount > 0;

  /// 对点做 EMA 滤波；输入 null 表示目标丢失。
  Offset01? update(Offset01? value) {
    if (value == null) {
      _missCount++;
      if (_missCount >= missLimit) {
        _point = null;
      }
      return _point;
    }
    _missCount = 0;
    final prev = _point;
    if (prev == null) {
      _point = value;
    } else {
      _point = Offset01(
        _lerp(prev.x, value.x),
        _lerp(prev.y, value.y),
      );
    }
    return _point;
  }

  /// 对矩形做 EMA 滤波（四边各自独立插值）；输入 null 表示目标丢失。
  Rect01? updateRect(Rect01? value) {
    if (value == null) {
      _missCount++;
      if (_missCount >= missLimit) {
        _rect = null;
      }
      return _rect;
    }
    _missCount = 0;
    final prev = _rect;
    if (prev == null) {
      _rect = value;
    } else {
      _rect = Rect01(
        left: _lerp(prev.left, value.left),
        top: _lerp(prev.top, value.top),
        right: _lerp(prev.right, value.right),
        bottom: _lerp(prev.bottom, value.bottom),
      );
    }
    return _rect;
  }

  double _lerp(double a, double b) => a + (b - a) * alpha;

  /// 清空全部内部状态。
  void reset() {
    _point = null;
    _rect = null;
    _missCount = 0;
  }
}
