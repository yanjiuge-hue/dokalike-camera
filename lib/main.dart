import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';

/// 应用入口（P0-1：冷启动 ≤1s）。
///
/// 启动路径刻意最短：
/// 1. 仅做 Hive 初始化与两个 Box 的打开（同步缓存读取，毫秒级）；
/// 2. 相机控制器在首帧渲染后异步初始化（见 [CameraPage]）；
/// 3. TFLite 解释器懒加载：首次启用构图辅助时才 spawn Isolate（见
///    [DetectionPipeline.start]）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.settingsBoxName);
  await Hive.openBox(AppConstants.photosBoxName);
  runApp(const ProviderScope(child: DokaLikeApp()));
}
