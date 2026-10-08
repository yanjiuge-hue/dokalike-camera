# DokaLike Camera · 打包成手机 App 指引

本机环境（Windows）无法直接构建 APK（无 Flutter SDK / Android SDK / JDK），也无法构建 iOS（必须 macOS + Xcode + Apple Developer 账号）。

已为你配置好 **GitHub Actions 云端自动构建**：把代码推到 GitHub，云端自动编译出 Android APK，你下载即可安装到手机。

---

## 一、最快路径（5 分钟出 APK）

### 前提
- 一个 GitHub 账号（没有就注册一个，免费）
- 本机装一个 git 客户端（[Git for Windows](https://git-scm.com/download/win) 或 VS Code 内置 git 均可）

### 步骤

1. **在 GitHub 创建空仓库**
   - 访问 https://github.com/new
   - Repository name 填 `dokalike-camera`
   - 选 **Public**（免费账号 Private 也能用 Actions，但 Public 更省配额）
   - **不要**勾选 "Add a README"、不要选 .gitignore、不要选 license（避免冲突）
   - 点 Create repository

2. **把本工程推到 GitHub**

   打开终端（Git Bash / PowerShell / VS Code 终端），切到工程目录：

   ```bash
   cd C:\Users\Administrator\WorkBuddy\2026-09-28-15-36-25\dokalike_camera

   # 初始化 git（如果还没有）
   git init
   git branch -M main

   # 关联你的远程仓库（把 <你的用户名> 换成实际用户名）
   git remote add origin https://github.com/<你的用户名>/dokalike-camera.git

   # 提交全部代码
   git add .
   git commit -m "feat: DokaLike Camera 初始版本"

   # 推送
   git push -u origin main
   ```

3. **云端自动构建**
   - 推送后，GitHub 会自动触发 `.github/workflows/build-apk.yml`
   - 进入仓库页面 → 点顶部 **Actions** 标签 → 可看到名为「构建 Android APK」的运行任务
   - 等待约 10–20 分钟（首次需下载 Flutter SDK 与 Gradle 依赖，之后会缓存加快）

4. **下载 APK**
   - 任务完成后点进去 → 滚到底部 **Artifacts** 区域 → 点 `dokalike-camera-apk` 下载
   - 解压后得到 3 个 APK（按 CPU 架构拆分）：
     - `app-armeabi-v7a-release.apk` —— 老旧 32 位手机
     - `app-arm64-v8a-release.apk` —— **绝大多数现代手机用这个**
     - `app-x86_64-release.apk` —— 模拟器用

5. **安装到手机**
   - 把 APK 传到手机（微信/网盘/USB 均可）
   - 手机设置 → 安全 → 开启「未知来源应用安装」（各品牌路径不同）
   - 文件管理器点击 APK → 安装
   - 打开「DokaLike 相机」→ 首次会请求相机权限，允许即可

---

## 二、手动触发重新构建

代码没变也想重新打包？进入仓库 **Actions** → 左侧选「构建 Android APK」→ 右上角 **Run workflow** → 选 main 分支 → 点绿色按钮。

---

## 三、打版本标签（正式发版用）

想标记一个正式版本号？

```bash
git tag v1.0.0
git push origin v1.0.0
```

推 tag 会自动触发构建，APK artifact 会带版本号标识。

---

## 四、关于 iOS

iOS **无法**在 GitHub Actions 的免费 ubuntu runner 上构建（必须 macOS + Xcode + 证书 + Apple Developer 年费 $99）。如需 iOS 版本：

- 方案 A：在 Mac 上 `flutter create . && flutter build ipa`（需 Apple Developer 账号）
- 方案 B：用 [Codemagic](https://codemagic.io/) / [Bitrise](https://bitrise.io/) 等支持 macOS 的 CI（有免费额度）

本工程 iOS 配置（Podfile、Info.plist）已就绪，拷到 Mac 上 `flutter create .` 补脚手架即可继续。

---

## 五、APK 签名说明

`android/app/build.gradle` 实现了**「无密钥也能构建」**的签名策略：

- 四项签名配置齐全 → 用 release 正式签名（可上架）
- 任意一项缺失 → 自动回退 debug 签名（可安装自测，不可上架）

构建时会在日志里打印一行 `[signing] ...`，一眼就能看出用的是哪把钥匙。

### 5.1 配置方式（任选其一，环境变量优先）

**方式 A：本地 —— `android/key.properties`**（已在 `.gitignore` 中，不会入库）

```properties
storeFile=/abs/path/to/upload-keystore.jks
storePassword=***
keyAlias=dokalike
keyPassword=***
```

**方式 B：CI —— GitHub Secrets**

在仓库 **Settings → Secrets and variables → Actions** 添加 4 个 Secret：

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_PATH` | keystore 路径（CI 上建议放 `app/dokalike.keystore`） |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 别名 |
| `ANDROID_KEY_PASSWORD` | 别名对应私钥密码 |

### 5.2 生成 keystore

```bash
keytool -genkey -v -keystore dokalike.keystore -alias dokalike \
  -keyalg RSA -keysize 2048 -validity 10000
```

### 5.3 ⚠️ 安全约定

- **keystore / 密码一律不入库**：`.gitignore` 已忽略 `*.keystore`、`*.jks`、
  `key.properties`，提交前请确认 `git status` 里没有这些文件。
- 需要在 CI 上用密钥时，推荐把 keystore **base64 编码后存 Secret**，构建前解码，
  而不是直接把二进制文件放进仓库：
  ```bash
  # 本机：编码
  base64 -w 0 dokalike.keystore > keystore.b64
  # CI：解码（示例，按需加到 workflow）
  echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/dokalike.keystore
  ```
- 当前仓库**尚未配置任何密钥**，因此每次构建都是 debug 签名回退，属预期行为。

---

## 六、构建产物说明

| 文件 | 大小预估 | 适用设备 |
|------|----------|----------|
| app-arm64-v8a-release.apk | ~40–80MB | 现代手机（推荐） |
| app-armeabi-v7a-release.apk | ~30–60MB | 老 32 位手机 |
| app-x86_64-release.apk | ~40–80MB | 模拟器 |

> split-per-abi 已开启，单包体积小于 universal APK，满足「≤150MB」验收要求。
> 缺少 .tflite 模型与 LUT PNG 时，APK 仍可构建安装，运行时自动降级（仅人脸检测 + 纯矩阵滤镜，不崩溃）。

---

## 七、如何验证产物（推送后核对清单）

**构建绿灯 ≠ 产物可用。** 推送后按下面四步在 Actions 页面核对。

### 7.1 先看 `ci-logs` 分支的 `11b-apk-inspect.log`

这是「APK 交付前自检」步骤的输出。健康的结果应包含：

- 三个 APK 各自的 **包名**（`com.dokalike.dokalike_camera`）、
  **versionCode / versionName**（`1` / `1.0.0`）、**minSdk**（`23`）、
  **targetSdk**（`34`）以及声明的 **uses-permission** 列表
- 每个包里的
  `✓ assets/flutter_assets/assets/models/ssd_mobilenet_v1_quant.tflite`
  与 `✓ assets/flutter_assets/assets/models/labels.txt`
- arm64 包里的 `✓ lib/arm64-v8a/libtensorflowlite_c.so` 与
  `✓ lib/arm64-v8a/libc++_shared.so`
  （另两个包校验各自 ABI 目录下的同名库）
- 三个 APK 的字节大小与 MB 数

任一项打 `✗` → 该步骤直接失败，说明产物缺件，装到手机上会降级或崩溃。
（包名/版本/sdk 这几项是**参考项**，只打标记不阻断，避免 aapt 与 aapt2
输出格式差异造成误判。）

> 该文件由「导出日志到 ci-logs 分支」步骤按 `*.log` 通配收集，
> 因此会自动出现在 `ci-logs` 分支与 `ci-logs` 制品里。

### 7.2 再看 `08c-model.log` 确认模型下载成功

应看到类似一行：

```
  ✓ 已就位：.../assets/models/ssd_mobilenet_v1_quant.tflite（4183312 bytes）
```

若看到 `!! 下载失败` / `!! 模型体积异常（< 3MB）` / `!! 文件头不是 TFL3`，
说明模型没拿到：App 会降级为仅人脸检测，且 7.1 的 APK 自检会同步失败。

### 7.3 看 `11-build-apk.log` 里的 `[signing]` 一行

形如（二选一）：

```
[signing] release 使用正式签名：<keystore 路径> (alias=...)   ← 配齐了 4 个 Secret / key.properties
[signing] release 未配置正式密钥，回退 debug 签名（仅供自测，不可上架）
```

一眼确认这次产物用的是哪把钥匙，详见第五节。

### 7.4 下载 APK artifact 需要登录 GitHub

三个 APK 打包在 `dokalike-camera-apk` artifact 里。**匿名下载会返回 401**，
必须先登录 GitHub 账号（免费账号即可）再点下载；或在仓库页面
**Actions → 对应 run → Artifacts** 处下载。

---

## 八、本机直接构建（可选）

如果你后来在本机装了 Flutter SDK + Android Studio：

```bash
cd dokalike_camera
flutter create --org com.dokalike --project-name dokalike_camera .
flutter pub get
flutter run                 # 连接手机调试
flutter build apk --release # 构建 APK
```

---

## 九、故障排查

| 现象 | 原因 / 处理 |
|------|-------------|
| Actions 没触发 | 确认 `.github/workflows/build-apk.yml` 已推上去；仓库 Settings → Actions → 确认未禁用 |
| 构建失败在 `flutter create` | 检查 pubspec.yaml name 是否为 `dokalike_camera` |
| 构建失败在 `flutter pub get` | 依赖版本冲突，看日志调整 pubspec.yaml 版本约束 |
| APK 闪退 | 多半是缺少相机权限，或 .tflite 模型未放置（会降级，不应崩溃——若崩溃请提 issue） |
| 安装提示「解析包失败」 | 选错架构了，大多数手机用 arm64-v8a |
| Actions 配额用尽 | 免费账号 Public 仓库不限制，Private 仓库每月 2000 分钟 |
