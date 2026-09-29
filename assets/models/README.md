# assets/models 资源说明

## 文件
- `ssd_mobilenet_v1_quant.tflite`：量化物体检测模型（约 4MB）。**该文件不随仓库分发**，需要手动下载放置到本目录。
- `labels.txt`：COCO 91 槽位标签表（第 i 行对应类别 id=i，未使用的 id 填 `placeholder`）。

## 模型获取指引（合规来源，Apache-2.0 授权）
1. 打开 TensorFlow Object Detection API 模型库：
   https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/detection_model_zoo.md
2. 下载 **SSD MobileNet V1 quantized (COCO, TFLite)** 版本压缩包。
3. 解压后将其中的 `*.tflite` 重命名为 `ssd_mobilenet_v1_quant.tflite`，放入本目录。

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
