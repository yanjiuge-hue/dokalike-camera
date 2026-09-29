import 'dart:async';

/// 节流器：判断当前时刻是否允许执行（帧采样用，P0-4）。
///
/// 用法：`if (throttler.shouldCall()) { doSample(); }`
/// 纯同步实现，主 Isolate 每帧回调中调用开销极小。
class Throttler {
  Throttler({required this.interval});

  /// 最小执行间隔。
  final Duration interval;

  DateTime? _lastCall;

  /// 距上次执行是否已超过 [interval]。
  bool shouldCall() {
    final now = DateTime.now();
    final last = _lastCall;
    if (last == null || now.difference(last) >= interval) {
      _lastCall = now;
      return true;
    }
    return false;
  }

  /// 重置计时（例如停止/重启采样后立即允许一次）。
  void reset() => _lastCall = null;
}

/// 通用防抖器：停止输入 [delay] 后才执行回调。
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  /// 提交一次待执行回调（会取消之前未触发的回调）。
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 取消未触发的回调。
  void cancel() => _timer?.cancel();

  /// 释放资源。
  void dispose() => cancel();
}
