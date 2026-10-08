# DokaLike Camera

极简、轻量、无广告的 AI 相机 App（Flutter 3.x，iOS + Android）。

> 本项目为**独立原创实现**：不使用任何商业相机 App 的商标、素材或私有
> 代码；滤镜命名与 LUT 均为原创或开源授权资源（合规红线）。

## 功能概览

- **打开即拍**：启动直接进入相机预览，无首页 / 无广告 / 无强制登录
- **AI 构图辅助**：200ms 节流采样 + 后台 Isolate 推理（不阻塞主线程），
  三分法 / 黄金分割 / 水平校正 / 主体突出四类规则，引导线经 EMA 低通
  滤波稳定不漂移
- **8 款原创胶片滤镜**：`ColorFiltered` 颜色矩阵实时预览 + 落盘同矩阵
  处理（所见即所得），强度 0–100% 无级调节（恒等矩阵与滤镜矩阵插值）
- **AI 滤镜推荐**（规则版 MVP）：亮度 / 色温 / 人脸数 / 场景分类 →
  按置信度排序的推荐列表，一键应用
- **多拍摄模式**：夜景（曝光补偿 + 夜港滤镜联动）/ 人像（3 档基础美颜）/
  延时（定时连拍序列）/ 普通
- **相册**：3 列网格分页浏览、大图（滑动 / 缩放 / 信息）、分享（系统
  面板）、删除（二次确认 + 撤销）；仅展示本 App 拍摄的照片
- **隐私**：AI 全部本地推理，无任何网络上传行为

## 打包成手机 App（云端自动构建，推荐）

本机无需安装 Flutter / Android SDK。已内置 GitHub Actions workflow：

1. 把本工程推到 GitHub 仓库
2. 推送后自动触发云端构建
3. 在 Actions 页面下载 APK artifact，传到手机安装即可

详见 **[BUILD_GUIDE.md](BUILD_GUIDE.md)**（含图文步骤、iOS 说明、正式签名、故障排查）。

## 环境要求

- Flutter SDK ≥ 3.3（Dart ≥ 3.3）
- Android：minSdk 23；iOS：12.0+

## 运行

> **首次构建注意**：仓库中已提供全部 Dart 源码与关键平台配置
> （`pubspec.yaml`、`android/app/build.gradle`、`AndroidManifest.xml`、
> `ios/Podfile`、`Info.plist`）。Gradle Wrapper、`MainActivity.kt`、
> `res/` 资源等平台脚手架文件请用 Flutter 工具链补齐（已存在的文件
> 不会被覆盖）：
>
> ```bash
> flutter create --org com.dokalike --project-name dokalike_camera .
> ```

```bash
flutter pub get

# iOS 首次需安装 Pods
cd ios && pod install && cd ..

# 连接设备 / 模拟器后
flutter run

# Release（体积优化：R8 + split-per-abi）
flutter build apk --release --split-per-abi
flutter build ios --release
```

### 单元测试

```bash
flutter test
```

包含两类测试：

- `test/engine_smoke_test.dart`：纯逻辑引擎冒烟（EMA / 几何 / 颜色矩阵 /
  推荐规则 / 构图引擎），QA 可在此基础上补全覆盖
- `test/pure_logic_guard_test.dart`：**纯逻辑守护**——强制
  `core/utils`、`features/*/engine`、`models` 下的文件零平台依赖
  （禁止 import `package:flutter/*`、`package:camera/*`、`dart:io`）

## 模型文件与 LUT 放置位置

### 物体检测模型（不入库，构建前自动获取）

模型是 ~4MB 的二进制，**不进版本库**（`.gitignore` 已排除
`assets/models/*.tflite`），两条获取途径：

- **云端构建（GitHub Actions，推荐）**：workflow 的「准备 AI 检测模型」
  步骤会自动执行 `scripts/fetch_model.sh`。脚本下载后做**双重校验**——
  体积下限 ≥3MB（量化版实际 4,183,312 bytes）+ 文件头必须是 `TFL3`，
  校验通过才落位到 `assets/models/`。**全程无需人工干预。**
- **本地开发**：仓库根目录执行

  ```bash
  bash scripts/fetch_model.sh            # 已存在则跳过
  bash scripts/fetch_model.sh --force    # 强制重新下载
  ```

落位后的两个文件（`labels.txt` 已内置，COCO 91 槽位标签表）：

```
assets/models/ssd_mobilenet_v1_quant.tflite
assets/models/labels.txt
```

模型输出约定（`InferenceIsolate` 按此解析）：输入 `1×300×300×3`
（uint8 / float32 自动适配）；输出 4 张量顺序为
`detection_boxes [1,N,4]`、`detection_classes [1,N]`、
`detection_scores [1,N]`、`num_detections [1]`。
运行时会打印一行 `[TFLite] 模型契约：...`（含各张量的形状与类型）；
形状与上述约定不符时会输出警告，可在真机日志里据此核对模型是否匹配。

**模型缺失时的行为**：App 不崩溃，构图辅助自动降级为「仅 ML Kit 人脸
检测」模式（日志提示）。

> 产物校验：CI 的「APK 交付前自检」步骤会用 `unzip -l` 断言
> `assets/flutter_assets/assets/models/ssd_mobilenet_v1_quant.tflite`
> 与 `labels.txt` 确实打进了 APK，缺任一即让该步骤失败。

### LUT（可选精修资源，当前未提供 —— 启用前必读）

8 款滤镜对应的 8 个 LUT PNG **目前一个都没有提供**，`assets/luts/` 下
只有 README。因此当前滤镜走的是**纯颜色矩阵路径**：预览
`ColorFiltered(matrixAt(strength))` 与落盘 `FilterPipeline.applyToBytes`
共用同一矩阵结果，**预览与成片完全一致**。

LUT 只是可选的精修资源：只有当你把 PNG 放进 `assets/luts/`
（文件名见该目录 README，MVP 采用 **256×1 的 1D 色调条**格式）后，
落盘管线才会按 `AppConstants.lutBlendWeight (0.4) × strength` 的权重
把 LUT 与矩阵结果混合。

> ⚠️ **启用 LUT 会破坏「所见即所得」**
>
> LUT 目前**只在落盘时生效**——预览端是纯颜色矩阵，完全不采样 LUT。
> 也就是说，一旦放入 LUT 文件，预览（弱）与成片（强）就会出现偏差。
> 若要启用 LUT，必须同步改造预览端（例如用 `FragmentProgram` 写 GLSL
> shader，对预览纹理采样同一张 LUT，混合权重与落盘端保持一致），
> 否则请不要往 `assets/luts/` 放任何 PNG。

## tflite_flutter 双端配置注意事项

### Android（已配置）

- `android/app/build.gradle` 中已包含：
  - `aaptOptions { noCompress "tflite" }`（模型需可 mmap，不可压缩）
  - `minSdk 23`
  - `ndk { abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64' }` 与
    `splits.abi`（控制单包体积）
  - R8 混淆 + `proguard-rules.pro` 保留 TFLite/MLKit 符号
- FFI 库 `libtensorflowlite_c.so` 由插件自动随包分发，无需手动配置

### iOS（已配置）

- `ios/Podfile`：`platform :ios, '12.0'` +
  `use_frameworks! :linkage => :static`（避免 TensorFlowLiteC 与 MLKit
  静态库重复符号冲突）
- 若构建后 `Runner.app/Frameworks` 出现重复符号报错，保持上述 static
  linkage 即可

### Isolate 加载模型的约束（重要）

tflite_flutter 基于 FFI，可在后台 Isolate 直接运行（本项目关键前提），
但**后台 Isolate 不能访问 rootBundle 平台通道**。因此模型字节的加载路径为：

1. 主 Isolate `rootBundle.load()` 读出模型字节与标签；
2. 通过 `init` 消息一次性传入后台 Isolate（`InferenceIsolate.spawn`）；
3. 之后 detect 消息只传帧 RGB 字节。

## 依赖说明

| 包 | 用途 |
|---|---|
| `camera ^0.11` | 相机预览 / 拍照 / 帧流 |
| `flutter_riverpod ^2.5` | 状态管理 + DI（Service 以 Provider 注册） |
| `tflite_flutter ^0.11` | TFLite FFI 推理（后台 Isolate） |
| `google_mlkit_face_detection ^0.13` | 人脸检测（原生线程，模型随包内置） |
| `image ^4.2` | 落盘滤镜 / 美颜 / 缩略图（纯 Dart） |
| `hive` / `hive_flutter` | 设置与照片元数据（只存 Map，无代码生成） |
| `permission_handler ^11` | 相机 / 相册权限 |
| `gal ^2.3` | 写入系统相册（轻量） |
| `share_plus ^10` | 系统分享面板 |
| `sensors_plus ^6` | 水平仪（加速度计横滚角） |

## 架构速览

```
UI (features/*/widgets) → Providers (providers/) → Services (services/) → Models (models/)
                                              ↘ 纯逻辑引擎 (composition/engine, filters/engine)
```

- 帧流水线：`CameraImage` → Throttler(200ms + busy 丢帧) →
  ML Kit 人脸（原生线程）‖ TFLite 物体（后台 Isolate）→
  CoordinateMapper 归一化 → CompositionEngine（纯 Dart）→
  EMA 滤波 → 引导层重绘
- 滤镜管线：预览 `ColorFiltered(matrixAt(strength))` 与落盘
  `FilterPipeline.applyToBytes` 共用同一矩阵结果（所见即所得）
- 详细设计见架构文档与 `dokalike-class-diagram.mermaid`

## 性能与包体积

- 性能预算：预览 30fps；单帧构图链路端到端 ≤100ms；12MP 落盘滤镜 ≤1.5s
  （compute 隔离）
- 包体积预算 ≤150MB：模型 ~4MB + 8 款 LUT <2MB + 无大型 UI 库 /
  无 FFmpeg；Release 开启 R8 + split-per-abi（基线数据待真机构建后
  记录于此）

## 合规声明

- 滤镜命名（晨雾 / 街拍 200 / 暖阳 / 夜港 / 柔调 / 青野 / 金岸 / 墨影）
  均为原创，风格对标经典胶片但**不含任何商标名**
- 物体检测模型来自 TensorFlow 官方 detection zoo（Apache-2.0）
- 全部 AI 推理本地完成，无网络数据上传
