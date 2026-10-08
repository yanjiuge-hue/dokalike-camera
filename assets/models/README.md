# assets/models 资源说明

## 文件
- `ssd_mobilenet_v1_quant.tflite`：量化物体检测模型（约 4MB，实际
  4,183,312 bytes）。**该文件不随仓库分发**（`.gitignore` 已排除
  `assets/models/*.tflite`），构建前由脚本自动获取，见下节。
- `labels.txt`：COCO 91 槽位标签表（第 i 行对应类别 id=i，未使用的 id 填 `placeholder`）。

## 模型获取方式（合规来源，Apache-2.0 授权）

**不需要手动下载**，两条途径都是同一份脚本：

- **云端构建（GitHub Actions）**：workflow 的「准备 AI 检测模型」步骤
  会自动执行本仓库的 `scripts/fetch_model.sh`。脚本从 TensorFlow 官方
  detection zoo 下载 *SSD MobileNet V1 quantized (COCO, TFLite)*
  压缩包，解压后做**双重校验**——体积下限 ≥3MB + 文件头必须是 `TFL3`
  （tflite flatbuffer 标识），校验通过才落位到本目录。无需人工干预。
- **本地开发**：仓库根目录执行

  ```bash
  bash scripts/fetch_model.sh            # 已存在则跳过
  bash scripts/fetch_model.sh --force    # 强制重新下载
  ```

仅在脚本也跑不通时，才手动按官方模型库地址取：
<https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/detection_model_zoo.md>
下载 *SSD MobileNet V1 quantized* 压缩包，解压后把其中的 `*.tflite`
重命名为 `ssd_mobilenet_v1_quant.tflite` 放入本目录。

## 模型输出约定（InferenceIsolate 按此解析）
- 输入：`1×300×300×3`（uint8 或 float32 自动适配）
- 输出 4 个张量，顺序固定为：
  - 0：`detection_boxes`，形状 `[1, N, 4]`（ymin/xmin/ymax/xmax，归一化）
  - 1：`detection_classes`，形状 `[1, N]`
  - 2：`detection_scores`，形状 `[1, N]`
  - 3：`num_detections`，形状 `[1]`

## 缺失时的行为
若模型文件缺失或加载失败，App 不会崩溃：构图辅助自动降级为
「仅 ML Kit 人脸检测」模式，并在日志中提示（见 `InferenceIsolate` / `DetectionPipeline`）。
