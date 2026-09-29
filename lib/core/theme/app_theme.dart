import 'package:flutter/material.dart';

/// 深色极简主题（P0-10）。
///
/// 设计基调：
/// - 纯黑背景，配合相机全屏预览
/// - 半透明控件叠加于预览层之上
/// - 圆角适度、图标线性极简、无任何广告位
class AppTheme {
  AppTheme._();

  /// 主题色板
  static const Color seed = Color(0xFF3DDC97); // 原创青绿色，相机「就绪」语义
  static const Color surfaceDark = Color(0xFF0B0B0D);
  static const Color surfaceElevated = Color(0xFF17181C);
  static const Color overlay = Color(0xB3000000); // 70% 黑，用于半透明叠加控件
  static const Color guideLine = Color(0x61FFFFFF); // 引导线约 38% 白
  static const Color guideLineGood = Color(0xFFFFD54A); // 构图达成高亮（P2-1）
  static const Color horizonOk = Color(0xFF4ADE80);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceDark,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08)),
    );
  }
}
