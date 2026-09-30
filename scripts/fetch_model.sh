#!/usr/bin/env bash
#
# 下载 COCO SSD MobileNet V1 量化物体检测模型到 assets/models/。
#
# 为什么不把模型直接提交进仓库：
#   - 它是 ~4MB 的二进制，会让仓库体积翻倍且难以 diff；
#   - assets/models/README.md 已声明「模型不随仓库分发」。
# 因此 CI 与本地构建前都跑一次本脚本；下载失败时 App 会自动降级为
# 「仅 ML Kit 人脸检测」（见 DetectionPipeline._ensureModelLoaded），不会崩溃。
#
# 用法：
#   bash scripts/fetch_model.sh           # 缺失时才下载
#   bash scripts/fetch_model.sh --force   # 强制重新下载
#
set -u

MODEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/models"
MODEL_FILE="${MODEL_DIR}/ssd_mobilenet_v1_quant.tflite"
MODEL_URL="https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip"
MIN_SIZE=$((3 * 1024 * 1024))   # 量化版约 4MB，小于 3MB 一定是下载不全

force=0
[ "${1:-}" = "--force" ] && force=1

if [ -f "${MODEL_FILE}" ] && [ "${force}" -eq 0 ]; then
  echo "  模型已存在，跳过下载：${MODEL_FILE}（$(stat -c '%s' "${MODEL_FILE}" 2>/dev/null || wc -c < "${MODEL_FILE}") bytes）"
  exit 0
fi

echo "  下载模型：${MODEL_URL}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

if ! curl -sSL --fail --max-time 300 -o "${tmpdir}/ssd.zip" "${MODEL_URL}"; then
  echo "  !! 下载失败，构图辅助将降级为仅人脸检测"
  exit 1
fi

# 官方压缩包里模型文件名为 detect.tflite
if ! unzip -o -j "${tmpdir}/ssd.zip" -d "${tmpdir}/x" >/dev/null 2>&1; then
  echo "  !! 解压失败"
  exit 1
fi

src="$(find "${tmpdir}/x" -name '*.tflite' | head -n 1)"
if [ -z "${src}" ]; then
  echo "  !! 压缩包里没有 .tflite 文件"
  exit 1
fi

size=$(stat -c '%s' "${src}" 2>/dev/null || wc -c < "${src}")
echo "  解压得到：$(basename "${src}")（${size} bytes）"
if [ "${size}" -lt "${MIN_SIZE}" ]; then
  echo "  !! 模型体积异常（< 3MB），疑似下载不完整，放弃"
  exit 1
fi

# tflite 是 flatbuffer，文件头 4 字节为 uint32 偏移，紧接着是标识 "TFL3"
magic=$(head -c 8 "${src}" | tail -c 4)
if [ "${magic}" != "TFL3" ]; then
  echo "  !! 文件头不是 TFL3（实际为 '${magic}'），不是合法 tflite 模型，放弃"
  exit 1
fi

mkdir -p "${MODEL_DIR}"
cp "${src}" "${MODEL_FILE}"
echo "  ✓ 已就位：${MODEL_FILE}（${size} bytes）"
