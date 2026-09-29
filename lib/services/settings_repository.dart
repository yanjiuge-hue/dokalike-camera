import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';
import '../models/camera_settings.dart';

/// 设置仓库：CameraSettings 读写（Hive）+ 轻记忆扩展项（P2-4）。
///
/// 共享知识 #7：只存 Map，不做 TypeAdapter。
/// Box 在 main() 中已打开，[load] 可同步读取；未打开时返回默认值。
class SettingsRepository {
  static const String _boxName = AppConstants.settingsBoxName;
  static const String _settingsKey = 'camera_settings';
  static const String _filterSelectionKey = 'filter_selection';

  Box? _box;

  Future<Box> _openBox() async {
    return _box ??= await Hive.openBox(_boxName);
  }

  /// 同步读取设置（Box 未打开时返回默认值）。
  CameraSettings load() {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
    if (box == null) return CameraSettings.defaults;
    final map = box.get(_settingsKey);
    if (map is Map) {
      return CameraSettings.fromMap(Map<dynamic, dynamic>.from(map));
    }
    return CameraSettings.defaults;
  }

  /// 异步保存设置。
  Future<void> save(CameraSettings settings) async {
    final box = await _openBox();
    await box.put(_settingsKey, settings.toMap());
  }

  /// 读取上次选中的滤镜（P2-4 轻记忆）。返回 {id, strength} 或 null。
  Map<String, dynamic>? loadFilterSelection() {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
    final map = box?.get(_filterSelectionKey);
    if (map is Map) {
      return Map<String, dynamic>.from(map);
    }
    return null;
  }

  /// 保存滤镜选择。
  Future<void> saveFilterSelection(String filterId, double strength) async {
    final box = await _openBox();
    await box.put(_filterSelectionKey, <String, dynamic>{
      'id': filterId,
      'strength': strength,
    });
    debugPrint('滤镜选择已持久化: $filterId @ $strength');
  }
}
