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
