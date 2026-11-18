#!/usr/bin/env bash
# 打包 firmware-xiaomi-sheng（设备固件与配置：ath12k/WCN7850、QCA 蓝牙、Cirrus DSP 等）
#
# 对应上游 debian-sheng 的 “Package firmware-xiaomi-sheng” 步骤：
#   克隆 firmware 仓库 → 全部内容装到 /usr/lib/firmware → dpkg-deb
# control 里保留 Debian 语义的 Conflicts/Replaces: linux-firmware
#
# 需要环境变量：
#   FIRMWARE_REPO   固件仓库 URL（默认 https://github.com/ianchb/sheng-firmware）
#   FIRMWARE_BRANCH 分支（默认 master）
#
# 用法: scripts/packages/build-firmware.sh
set -euo pipefail

PKG=firmware-xiaomi-sheng
FIRMWARE_REPO="${FIRMWARE_REPO:-https://github.com/ianchb/sheng-firmware}"
FIRMWARE_BRANCH="${FIRMWARE_BRANCH:-master}"
OUT="${PWD}/${PKG}.deb"
BUILD="${PWD}/build/${PKG}"
SRC="${PWD}/build/firmware-src"

rm -rf "$BUILD" "$SRC"
mkdir -p "$BUILD/usr/lib/firmware"

echo "[build-firmware] 克隆 $FIRMWARE_REPO ($FIRMWARE_BRANCH)"
git clone --depth 1 --branch "$FIRMWARE_BRANCH" "$FIRMWARE_REPO" "$SRC"

cp -a "$PKG/DEBIAN" "$BUILD/"
cp -a "$SRC/." "$BUILD/usr/lib/firmware/"
rm -rf "$BUILD/usr/lib/firmware/.git" \
       "$BUILD/usr/lib/firmware/.github" \
       "$BUILD/usr/lib/firmware/.gitignore"

# WCN7850 WiFi 修复：sheng-firmware 仓嘅 amss.bin 系错版本（BHI Image transfer
# failed / ERROR_CODE 0xef0a0104 / failed to power up -110）。用官方 linux-firmware
# 嘅 WCN7850/hw2.0 固件覆盖（amss.bin ~6.09MB、board-2.bin ~2.4MB 全量）。
WCN_DIR="$BUILD/usr/lib/firmware/ath12k/WCN7850/hw2.0"
if [ -d "$WCN_DIR" ]; then
  for f in amss.bin board-2.bin m3.bin; do
    if curl -fsSL --retry 3 --max-time 120 -o "$WCN_DIR/$f" \
        "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/ath12k/WCN7850/hw2.0/$f"; then
      echo "[build-firmware] 官方 WCN7850 $f 已覆盖 ($(du -h "$WCN_DIR/$f" | cut -f1))"
    else
      echo "[build-firmware] 警告：官方 $f 下载失败，保留 sheng-firmware 原版" >&2
    fi
  done
fi

# 固件 blob 必须保持原样：不做 strip、不压缩
find "$BUILD" -type d -exec chmod 755 {} +
find "$BUILD" -type f -exec chmod 644 {} +

dpkg-deb --build --root-owner-group "$BUILD" "$OUT"
echo "[build-firmware] 产出 $OUT ($(du -h "$OUT" | cut -f1))"
find "$BUILD/usr/lib/firmware" -maxdepth 1 -mindepth 1 -printf '    %f\n' | sort
