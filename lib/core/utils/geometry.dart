import 'package:equatable/equatable.dart';

import '../constants/app_constants.dart';

/// 归一化点（[0,1] 坐标系，左上原点）。
class Offset01 extends Equatable {
  const Offset01(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(Offset01 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return _sqrt(dx * dx + dy * dy);
  }

  /// 牛顿迭代平方根（避免引入 dart:math 也可，但 dart:math 属核心库，可直接用）。
  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double r = v;
    for (var i = 0; i < 24; i++) {
      r = (r + v / r) / 2;
    }
    return r;
  }

  @override
  List<Object?> get props => [x, y];
}

/// 归一化矩形（[0,1] 坐标系，左上原点）。
///
/// 共享知识 #1：业务层一律使用 [Rect01]，只有 CoordinateMapper 与
/// InferenceIsolate 允许接触原始 CameraImage 坐标。
class Rect01 extends Equatable {
  const Rect01({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory Rect01.fromLTWH(double left, double top, double width, double height) {
    return Rect01(
      left: left,
      top: top,
      right: left + width,
      bottom: top + height,
    );
  }

  /// 全屏矩形
  static const Rect01 full = Rect01(left: 0, top: 0, right: 1, bottom: 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  Offset01 get center => Offset01((left + right) / 2, (top + bottom) / 2);

  /// 面积（裁剪到 [0,1] 后的可见面积，用于主体大小判定）。
  double get area {
    final w = (right.clamp(0, 1)) - (left.clamp(0, 1));
    final h = (bottom.clamp(0, 1)) - (top.clamp(0, 1));
    // 修正：clamp() 的静态返回类型是 num，w / h 参与运算后整体仍被推断为 num，
    // 与 double 返回类型冲突（return_of_invalid_type）。这里显式 toDouble()，
    // 并把整型字面量 0 写成 0.0，保证三元表达式两个分支类型一致。
    return w <= 0 || h <= 0 ? 0.0 : (w * h).toDouble();
  }

  bool get isEmpty => width <= 0 || height <= 0;

  /// 是否被画面边缘裁切（epsilon 为允许的越界余量）。
  bool isClippedByFrame([double? epsilon]) {
    final e = epsilon ?? AppConstants.clipEpsilon;
    return left < -e || top < -e || right > 1 + e || bottom > 1 + e;
  }

  /// 裁剪到 [0,1] 范围。
  Rect01 clamp01() {
    return Rect01(
      left: left.clamp(0.0, 1.0),
      top: top.clamp(0.0, 1.0),
      right: right.clamp(0.0, 1.0),
      bottom: bottom.clamp(0.0, 1.0),
    );
  }

  /// 整体平移（不裁剪，用于生成建议位置）。
  Rect01 translated(double dx, double dy) {
    return Rect01(
      left: left + dx,
      top: top + dy,
      right: right + dx,
      bottom: bottom + dy,
    );
  }

  Rect01 copyWith({double? left, double? top, double? right, double? bottom}) {
    return Rect01(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  List<Object?> get props => [left, top, right, bottom];
}

/// 与 [Rect01] 相关的场景辅助常量：食物类 COCO 标签（SceneType 分类用）。
const Set<String> kFoodLabels = {
  'banana', 'apple', 'orange', 'pizza', 'donut', 'cake', 'hot dog',
  'sandwich', 'broccoli', 'carrot', 'bowl', 'wine glass', 'cup',
};

/// 归一化矩形按 [quarterTurns] 顺时针旋转（绕画面中心，0/1/2/3 × 90°）。
/// 用于把「传感器方向坐标」转换为「竖直方向坐标」。
Rect01 rotateQuarterTurns(Rect01 rect, int quarterTurns) {
  var r = rect;
  final turns = ((quarterTurns % 4) + 4) % 4;
  for (var i = 0; i < turns; i++) {
    // 顺时针 90°： -> (1-y, x)
    r = Rect01(
      left: 1 - r.bottom,
      top: r.left,
      right: 1 - r.top,
      bottom: r.right,
    );
  }
  return r;
}
