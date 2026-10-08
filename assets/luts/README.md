# assets/luts 资源说明

本目录用于存放 8 款原创命名胶片滤镜对应的 LUT PNG（可选精修资源）。

## 文件名约定（与 `FilterCatalog` 中 `lutAsset` 一一对应）
| 文件名 | 滤镜 id | 中文名 |
|---|---|---|
| teal_dawn.png | teal_dawn | 晨雾 |
| street_200.png | street_200 | 街拍 200 |
| warm_sun.png | warm_sun | 暖阳 |
| night_port.png | night_port | 夜港 |
| agfa_soft.png | agfa_soft | 柔调 |
| fuji_green.png | fuji_green | 青野 |
| kodak_gold.png | kodak_gold | 金岸 |
| mono_film.png | mono_film | 墨影 |

## LUT 格式约定（MVP：1D 色调条）
- 尺寸：`256×1` PNG，第 x 列像素表示「亮度 = x/255」映射后的目标 RGB。
- 滤镜管线会以约 `0.4 × 强度` 的权重与颜色矩阵结果混合（见 `FilterPipeline`）。
- 后续可升级为标准 33³ 3D LUT，仅需替换 `FilterPipeline` 中的采样逻辑。

## 合规红线
- 所有 LUT 必须为**原创制作**或**开源授权**资源，禁止使用任何商业相机 App 的
  商标、素材或私有 LUT（本项目为独立原创实现）。
- 每款 LUT 应小于 200KB（首发 8 款总计 < 2MB，满足包体积红线）。

## 缺失时的行为
LUT 为可选资源：文件缺失时滤镜仅由 4×5 颜色矩阵实现（预览与落盘仍保持一致），
`FilterPipeline` 会在加载失败时静默降级为纯矩阵模式。

---

## 启用前必读：LUT 会破坏「所见即所得」

**本目录当前没有任何 PNG，这是推荐状态。**

原因：`lib/services/filter_pipeline.dart` 里的 LUT **只在落盘时生效**——
按亮度采样 256×1 色调条，以 `AppConstants.lutBlendWeight (0.4) × strength`
的权重与颜色矩阵结果混合；而**预览端**只是
`ColorFiltered(matrixAt(strength))` 的纯颜色矩阵，根本不经过 LUT。

于是放入 LUT 后会出现：

| 环节 | 是否走 LUT | 观感 |
|---|---|---|
| 预览 | ✗ 纯颜色矩阵 | 滤镜效果偏弱 |
| 落盘 | ✓ 矩阵 + LUT 混合（权重 `0.4 × strength`） | 滤镜效果明显更强 |

→ **预览与成片不一致，直接违背本项目「所见即所得」的承诺。**

### 若确实要启用 LUT，必须同时改造预览端

1. 用 `FragmentProgram`（Flutter GLSL shader）对预览纹理采样**同一张
   LUT**，混合权重与落盘端严格一致；或
2. 让预览端也走与 `FilterPipeline` 完全相同的像素处理路径
   （代价是预览帧率，需重新评估 30fps 性能预算）。

在预览端改造完成并通过真机比对之前，**不要往本目录放任何 PNG**。
