import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 纯逻辑守护测试（架构 §2 约定的强制执行）。
///
/// 规则：以下目录中的文件禁止 import `package:flutter/`、`package:camera/`、
/// `dart:io`（models 目录例外：允许 `dart:typed_data`）：
/// - lib/core/utils/
/// - lib/features/composition/engine/
/// - lib/features/filters/engine/
/// - lib/models/
const List<String> _guardedDirs = [
  'lib/core/utils',
  'lib/features/composition/engine',
  'lib/features/filters/engine',
  'lib/models',
];

const List<String> _forbiddenPatterns = [
  "import 'package:flutter/",
  'import "package:flutter/',
  "import 'package:camera/",
  'import "package:camera/',
  "import 'dart:io'",
  'import "dart:io"',
];

void main() {
  test('纯逻辑模块零平台依赖（禁止 flutter/camera/dart:io import）', () {
    final violations = <String>[];

    for (final dirPath in _guardedDirs) {
      final dir = Directory(dirPath);
      expect(dir.existsSync(), isTrue, reason: '目录不存在: $dirPath');
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final pattern in _forbiddenPatterns) {
          if (content.contains(pattern)) {
            violations.add('${entity.path}: $pattern');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '以下文件违反纯逻辑约束（含平台依赖 import）：\n'
          '${violations.join('\n')}\n'
          '注意：本测试应从项目根目录运行（flutter test）。',
    );
  });
}
