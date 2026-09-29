import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/photo.dart';

/// 拍后即览浮层（P2-3）：拍摄→分享路径 ≤2 步。
///
/// 显示最新照片缩略图，4 秒后自动淡出；点击可分享。
class CaptureToast extends StatefulWidget {
  const CaptureToast({super.key, required this.photo});

  final Photo photo;

  @override
  State<CaptureToast> createState() => _CaptureToastState();
}

class _CaptureToastState extends State<CaptureToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _fadeOut();
      }
    });
  }

  void _fadeOut() {
    // 通过透明度动画后移除自身（由父层按 lastCaptureAt 条件重建，
    // 这里直接触发一次无动画隐藏：将本控件从树上摘除的最简方式）
    setState(() => _visible = false);
  }

  bool _visible = true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/gallery'),
        child: Container(
          width: 64,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white30),
            image: widget.photo.thumbnailPath != null
                ? DecorationImage(
                    image: FileImage(File(widget.photo.thumbnailPath!)),
                    fit: BoxFit.cover,
                  )
                : null,
            color: Colors.black54,
          ),
          child: widget.photo.thumbnailPath == null
              ? const Icon(Icons.check, color: Colors.white70)
              : null,
        ),
      ),
    );
  }
}
