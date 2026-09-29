import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// 延时摄影状态（A-1：MVP = 定时连拍序列 + App 内顺序回放）。
class TimelapseState {
  const TimelapseState({
    this.running = false,
    this.captured = 0,
    this.total = 0,
  });

  final bool running;
  final int captured;
  final int total;

  /// 进度 [0,1]
  double get progress => total == 0 ? 0 : (captured / total).clamp(0.0, 1.0);

  /// 剩余张数
  int get remaining => total - captured;

  static const TimelapseState idle = TimelapseState();
}

/// 延时摄影控制器：定时器连拍 + 进度状态 + 取消（P1-5 / A-1）。
///
/// 不做机内视频编码（避免引入 FFmpeg 撑爆包体积）；
/// 连拍出的照片序列在相册中按时间倒序天然成组。
class TimelapseController extends ChangeNotifier {
  TimelapseState _state = TimelapseState.idle;
  Timer? _timer;

  TimelapseState get state => _state;

  /// 是否正在延时拍摄
  bool get isRunning => _state.running;

  /// 启动延时连拍。
  ///
  /// [onCapture] 每个间隔触发一次（由 CameraNotifier 执行真正的拍照流程）；
  /// [onFinished] 全部完成后回调（UI 收起进度环等）。
  void start({
    required Future<void> Function() onCapture,
    VoidCallback? onFinished,
    int? total,
    Duration? interval,
  }) {
    if (isRunning) return;
    final count = total ?? AppConstants.timelapseDefaultCount;
    final gap = interval ?? AppConstants.timelapseDefaultInterval;

    _state = TimelapseState(running: true, captured: 0, total: count);
    notifyListeners();

    var captured = 0;
    _timer = Timer.periodic(gap, (timer) async {
      if (captured >= count) {
        _finish(onFinished);
        return;
      }
      try {
        await onCapture();
      } catch (e) {
        debugPrint('延时连拍单帧失败（继续）: $e');
      }
      captured++;
      _state = TimelapseState(running: true, captured: captured, total: count);
      notifyListeners();
      if (captured >= count) {
        _finish(onFinished);
      }
    });
  }

  /// 中途取消延时拍摄。
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _state = TimelapseState.idle;
    notifyListeners();
  }

  void _finish(VoidCallback? onFinished) {
    _timer?.cancel();
    _timer = null;
    _state = TimelapseState.idle;
    notifyListeners();
    onFinished?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
