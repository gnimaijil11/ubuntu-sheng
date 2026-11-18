#!/usr/bin/env bash
# 45-mesa-a740.sh — 安装 ir3 补丁版 Mesa（Adreno 740 硬件 GL），覆盖 40 的软件渲染兜底。
# 在 40-system-config.sh 之后、90-verify.sh 之前执行。
# patched debs 来自 GitHub Release mesa-a740-patched（dpkg-buildpackage 精确 ABI）。
# 在 chroot 内执行:
#   chroot "$MOUNT" /root/sheng-build/in-chroot/45-mesa-a740.sh
set -euo pipefail

# 只在 7.3.x 内核上安装（debs 系 7.3.4 ABI 编译，其他内核跳过）
if ! ls /lib/modules/7.3.* >/dev/null 2>&1; then
    echo "[mesa-a740] 跳过：目标内核非 7.3.x（debs ABI 唔匹配）"
    exit 0
fi

BUILD_DIR="${BUILD_DIR:-/root/sheng-build}"
# shellcheck source=/dev/null
source "$BUILD_DIR/common/distro-env.sh"
# shellcheck source=/dev/null
source "$BUILD_DIR/in-chroot/lib-apt.sh"

URL="https://github.com/gnimaijil11/ubuntu-sheng/releases/download/mesa-a740-patched/mesa-a740-debs.zip"
echo "[mesa-a740] 下载 patched Mesa debs..."
command -v curl >/dev/null 2>&1 || apt-get install -y curl
command -v unzip >/dev/null 2>&1 || apt-get install -y unzip
cd /tmp
curl -fsSL --retry 3 --retry-delay 10 -o mesa-debs.zip "$URL" || { echo "[mesa-a740] download failed, skipping"; exit 0; }
rm -rf /tmp/mesa-debs
unzip -o -q mesa-debs.zip -d /tmp/mesa-debs
echo "[mesa-a740] dpkg -i 强制安装（同版本号）..."
dpkg -i /tmp/mesa-debs/*.deb || { echo "[mesa-a740] dpkg failed, continuing"; true; } || apt-get install -f -y
echo "[mesa-a740] 切换硬件 GL（KWIN_COMPOSE=O2，覆盖软件兜底）..."
mkdir -p /etc/systemd/user/plasma-kwin_wayland.service.d /etc/systemd/user/plasma-plasmashell.service.d
printf '[Service]\nEnvironment=KWIN_COMPOSE=O2\n' > /etc/systemd/user/plasma-kwin_wayland.service.d/sheng-software.conf
printf '[Service]\n' > /etc/systemd/user/plasma-plasmashell.service.d/sheng-software.conf
sed -i '/QT_QUICK_BACKEND/d' /etc/environment
rm -rf /tmp/mesa-debs /tmp/mesa-debs.zip
echo "[mesa-a740] 完成：Adreno 740 硬件加速（freedreno FD740 / OpenGL 4.6）"
