// 修正：本文件位于 lib/features/filters/data/，要回到 lib/ 需要三级 `../`
// （data → filters → features → lib）。原来只写了两级，解析成
// lib/features/core/... 与 lib/features/models/...，两个目录都不存在，
// 于是 AssetPaths / FilterCategory / FilterPreset 全部未定义（约 200 处报错）。
import '../../../core/constants/asset_paths.dart';
import '../../../models/enums.dart';
import '../../../models/filter_preset.dart';

/// 滤镜目录：首发 8 款原创命名胶片滤镜 + 原图（A-6 假设）。
///
/// 合规红线（共享知识 #9）：
/// - 滤镜命名全部为 2–4 字原创中文词，风格对标经典胶片但**不使用任何
///   商标名**；
/// - LUT 均为可选的原创/开源授权资源（缺失时自动降级为纯矩阵）。
///
/// 新增滤镜只需：① 在 [all] 中追加预设；② 可选地在 assets/luts/ 放置
/// 同名 LUT PNG（共享知识 #2）。
///
/// ⚠️ 为什么本目录的预设必须用 `static final` 而不是 `static const`：
/// [FilterPreset] 的构造函数带 `assert(matrix4x5.length == 20, ...)`。
/// 常量上下文（`static const`）要求 CFE 在**编译期**求值整个构造，
/// 而 Dart 的常量表达式不允许对 List 做 `.length` 属性访问，于是报
/// "Constant evaluation error ... The property 'length' can't be accessed
/// on '<double>[...]' in a constant expression"。
/// 改为 `static final` 后构造退化为**首次访问时**的运行期调用：
/// - `FilterPreset` 的 const 构造函数与 assert 本身保持不动；
/// - assert 变回运行期断言（debug 模式生效），20 元素校验能力完整保留。
class FilterCatalog {
  FilterCatalog._();

  /// 原图（恒等矩阵直出）
  static final FilterPreset original = FilterPreset(
    id: 'original',
    name: '原图',
    matrix4x5: [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.original,
    isOriginal: true,
  );

  /// 晨雾：青调晨光，轻柔对比，微降饱和
  static final FilterPreset tealDawn = FilterPreset(
    id: 'teal_dawn',
    name: '晨雾',
    matrix4x5: [
      0.92, 0.02, 0.06, 0, -0.01, //
      0.02, 0.98, 0.05, 0, 0.01, //
      0.06, 0.05, 1.05, 0, 0.02, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.film,
    lutAsset: AssetPaths.lutTealDawn,
  );

  /// 街拍 200：高对比、去饱和、街头纪实感
  static final FilterPreset street200 = FilterPreset(
    id: 'street_200',
    name: '街拍 200',
    matrix4x5: [
      1.15, 0.05, -0.05, 0, -0.06, //
      0.05, 1.10, -0.02, 0, -0.05, //
      -0.05, -0.02, 1.05, 0, -0.03, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.portrait,
    lutAsset: AssetPaths.lutStreet200,
  );

  /// 暖阳：金暖色温，适合顺光人像与日常
  static final FilterPreset warmSun = FilterPreset(
    id: 'warm_sun',
    name: '暖阳',
    matrix4x5: [
      1.10, 0.05, -0.02, 0, 0.05, //
      0.03, 1.00, 0.00, 0, 0.02, //
      -0.02, 0.00, 0.88, 0, 0.03, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.landscape,
    lutAsset: AssetPaths.lutWarmSun,
  );

  /// 夜港：深青夜色，压暗提纯，夜景专属
  static final FilterPreset nightPort = FilterPreset(
    id: 'night_port',
    name: '夜港',
    matrix4x5: [
      0.95, 0.00, 0.05, 0, -0.04, //
      0.02, 1.00, 0.05, 0, -0.02, //
      0.10, 0.08, 1.10, 0, -0.02, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.night,
    lutAsset: AssetPaths.lutNightPort,
  );

  /// 柔调：低反差柔肤，人像直出
  static final FilterPreset agfaSoft = FilterPreset(
    id: 'agfa_soft',
    name: '柔调',
    matrix4x5: [
      0.92, 0.06, 0.04, 0, 0.06, //
      0.05, 0.92, 0.05, 0, 0.05, //
      0.04, 0.05, 0.94, 0, 0.05, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.portrait,
    lutAsset: AssetPaths.lutAgfaSoft,
  );

  /// 青野：绿意通透，户外风光
  static final FilterPreset fujiGreen = FilterPreset(
    id: 'fuji_green',
    name: '青野',
    matrix4x5: [
      0.95, 0.04, 0.03, 0, -0.02, //
      0.04, 1.05, 0.03, 0, 0.02, //
      0.02, 0.06, 1.00, 0, 0.00, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.landscape,
    lutAsset: AssetPaths.lutFujiGreen,
  );

  /// 金岸：金饱和暖调，经典负片质感
  static final FilterPreset kodakGold = FilterPreset(
    id: 'kodak_gold',
    name: '金岸',
    matrix4x5: [
      1.12, 0.02, -0.04, 0, 0.03, //
      0.04, 1.05, -0.01, 0, 0.01, //
      -0.01, 0.02, 0.92, 0, 0.04, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.film,
    lutAsset: AssetPaths.lutKodakGold,
  );

  /// 墨影：黑白高反差，微暖黑
  static final FilterPreset monoFilm = FilterPreset(
    id: 'mono_film',
    name: '墨影',
    matrix4x5: [
      0.40, 0.42, 0.14, 0, -0.02, //
      0.40, 0.42, 0.14, 0, -0.02, //
      0.40, 0.42, 0.14, 0, -0.01, //
      0, 0, 0, 1, 0,
    ],
    category: FilterCategory.mono,
    lutAsset: AssetPaths.lutMonoFilm,
  );

  /// 全部滤镜（顺序即滤镜栏展示顺序）
  // 与上面 9 个预设同理：列表元素是 FilterPreset，若声明为 const，
  // CFE 会尝试对整个列表做常量求值，进而触发 FilterPreset 构造函数里
  // assert(matrix4x5.length == 20) 的编译期求值失败。
  static final List<FilterPreset> all = [
    original,
    tealDawn,
    street200,
    warmSun,
    nightPort,
    agfaSoft,
    fujiGreen,
    kodakGold,
    monoFilm,
  ];

  /// 按 id 查找预设，找不到时回退原图。
  static FilterPreset byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return original;
  }
}
