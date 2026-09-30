import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/composition_advice.dart';
import '../../../models/enums.dart';
import '../../../providers/composition_provider.dart';
import '../../../providers/settings_provider.dart';

/// 构图引导层（PRD §5.2 / P0-6）：引导线 + 水平仪 + 箭头 + 提示气泡。
///
/// - 引导线坐标经 EMA 低通滤波（CompositionNotifier 内完成），
///   稳定不漂移（连续预览 30 秒无可感知抖动）；
/// - 构图达标时线条短暂高亮（P2-1）；
/// - 焦段建议仅在多镜头设备显示（A-5）。
class CompositionOverlay extends ConsumerWidget {
  const CompositionOverlay({super.key, required this.hasMultiLens});

  /// 设备是否有多镜头（决定焦段建议显示）
  final bool hasMultiLens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composition = ref.watch(compositionProvider);
    final settings = ref.watch(settingsProvider);

    if (!composition.enabled) return const SizedBox.shrink();

    final advice = composition.advice;
    final lines = _filterLines(advice?.lines ?? const [], settings.gridStyle);

    return IgnorePointer(
      child: Stack(
        children: [
          // ===== 引导线 + 箭头（CustomPainter，30fps 渲染循环）=====
          Positioned.fill(
            child: CustomPaint(
              painter: _CompositionPainter(
                lines: lines,
                advice: advice,
                isGood: advice?.isGoodComposition ?? false,
              ),
            ),
          ),

          // ===== 提示气泡（屏幕上边缘中性灰胶囊）=====
          if (advice?.message != null && !advice!.isGoodComposition)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    advice.message!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

          // ===== 焦段建议（A-5：仅多镜头设备显示）=====
          if (hasMultiLens && advice?.focalHint != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 210),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    advice!.focalHint!.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 按用户网格样式设置过滤引导线。
  List<GuideLine> _filterLines(List<GuideLine> lines, GridStyle style) {
    return switch (style) {
      GridStyle.none => const [],
      GridStyle.thirds => lines
          .where((l) => l.type == GuideLineType.thirds)
          .toList(growable: false),
      GridStyle.golden => lines
          .where((l) => l.type == GuideLineType.golden)
          .toList(growable: false),
    };
  }
}

/// 构图绘制器。
class _CompositionPainter extends CustomPainter {
  _CompositionPainter({
    required this.lines,
    required this.advice,
    required this.isGood,
  });

  final List<GuideLine> lines;
  final CompositionAdvice? advice;
  final bool isGood;

  @override
  void paint(Canvas canvas, Size size) {
    // ===== 1) 引导线（30-40% 透明度白色细线；达标时高亮 P2-1）=====
    final linePaint = Paint()
      ..color = isGood ? AppTheme.guideLineGood : AppTheme.guideLine
      ..strokeWidth = isGood ? 1.6 : 1.0;

    for (final line in lines) {
      switch (line.axis) {
        case LineAxis.vertical:
          final x = line.position * size.width;
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            linePaint,
          );
        case LineAxis.horizontal:
          final y = line.position * size.height;
          canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y),
            linePaint,
          );
      }
    }

    // ===== 2) 水平仪（预览顶部边缘指示条）=====
    _paintHorizonBar(canvas, size);

    // ===== 3) 方向箭头（主体旁半透明箭头，随 EMA 平滑移动）=====
    final hint = advice?.moveHint;
    if (hint != null && !isGood) {
      _paintDirectionHint(canvas, size, hint);
    }
  }

  /// 水平仪：顶部居中横条，倾斜时指示条偏移，水平时变绿。
  void _paintHorizonBar(Canvas canvas, Size size) {
    final angle = advice?.horizonAngle ?? 0;
    final isLevel = angle.abs() <= 2.0;
    final barWidth = size.width * 0.3;
    const trackY = 64.0;
    final center = Offset(size.width / 2, trackY);

    // 轨道
    final trackPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-barWidth / 2, 0),
      center.translate(barWidth / 2, 0),
      trackPaint,
    );

    // 指示条：偏移量与横滚角成正比（满偏 10°）
    final offset =
        (angle / 10.0).clamp(-1.0, 1.0) * (barWidth / 2 - 14);
    final indicatorPaint = Paint()
      ..color = isLevel ? AppTheme.horizonOk : Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(offset - 14, 0),
      center.translate(offset + 14, 0),
      indicatorPaint,
    );
  }

  /// 方向箭头：在主体锚点旁绘制 ←/→/靠近(↑双箭头)/拉远(↓双箭头)。
  void _paintDirectionHint(Canvas canvas, Size size, DirectionHint hint) {
    final anchor = Offset(
      hint.anchor.x.clamp(0.08, 0.92) * size.width,
      hint.anchor.y.clamp(0.08, 0.92) * size.height,
    );

    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const arrowSize = 14.0;

    switch (hint.direction) {
      case MoveDirection.moveLeft:
        // ←
        _drawArrow(canvas, paint, anchor, const Offset(-1, 0), arrowSize);
      case MoveDirection.moveRight:
        // →
        _drawArrow(canvas, paint, anchor, const Offset(1, 0), arrowSize);
      case MoveDirection.moveCloser:
        // ↑↑（靠近）
        _drawArrow(canvas, paint, anchor.translate(0, 10), const Offset(0, -1), arrowSize);
        _drawArrow(canvas, paint, anchor.translate(0, 26), const Offset(0, -1), arrowSize);
      case MoveDirection.moveFarther:
        // ↓↓（拉远）
        _drawArrow(canvas, paint, anchor.translate(0, -10), const Offset(0, 1), arrowSize);
        _drawArrow(canvas, paint, anchor.translate(0, -26), const Offset(0, 1), arrowSize);
    }
  }

  /// 绘制单个箭头（起点 anchor，朝向 direction）。
  void _drawArrow(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset dir,
    double length,
  ) {
    final end = start.translate(dir.dx * length, dir.dy * length);
    canvas.drawLine(start, end, paint);

    // 箭头两翼
    const wingAngle = 0.5; // 弧度
    final base = -dir;
    for (final sign in [1.0, -1.0]) {
      final wx = base.dx * 6 * 1.2 + (base.dy * sign * 6 * 1.2) * 0;
      // 简单几何：翼向量 = 基向量旋转 ±wingAngle
      final bx = base.dx, by = base.dy;
      final cosW = _cos(wingAngle), sinW = _sin(wingAngle);
      final wx2 = bx * cosW - by * sign * sinW;
      final wy2 = bx * sign * sinW + by * cosW;
      canvas.drawLine(
        end,
        end.translate(wx2 * 7 + (wx * 0), wy2 * 7),
        paint,
      );
    }
  }

  double _cos(double rad) {
    var x = 1.0, term = 1.0;
    for (var i = 1; i < 10; i++) {
      term *= -rad * rad / ((2 * i - 1) * (2 * i));
      x += term;
    }
    return x;
  }

  double _sin(double rad) {
    var x = 0.0, term = rad;
    x += term;
    for (var i = 1; i < 10; i++) {
      term *= -rad * rad / ((2 * i) * (2 * i + 1));
      x += term;
    }
    return x;
  }

  @override
  bool shouldRepaint(_CompositionPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.advice != advice ||
        oldDelegate.isGood != isGood;
  }
}
