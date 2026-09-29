import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/camera/camera_page.dart';
import 'features/gallery/gallery_page.dart';

/// App 根组件：深色极简主题 + 路由表。
///
/// 无首页、无登录、无广告（P0-1）：默认路由即相机页。
class DokaLikeApp extends StatelessWidget {
  const DokaLikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DokaLike 相机',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const CameraPage(),
        '/gallery': (context) => const GalleryPage(),
      },
    );
  }
}
