#!/bin/bash
# Momo 首启自动精简（ophub rebuild 定制，onshot 首次开机执行一次）
# 三刀合并：固件裁剪 + 文档清理 + apt 卸载编译链/git/zsh/aptitude/unicode-data
set -u
LOG=/var/log/momo-slim.log
{
echo "===== Momo slim firstboot $(date) ====="
BEFORE=$(du -sm / 2>/dev/null | cut -f1)
echo "精简前: ${BEFORE} MB"

# 防呆：确认网络可用（有线）
if ! ping -c 2 -W 2 192.168.8.1 >/dev/null 2>&1 && ! ping -c 2 -W 2 223.5.5.5 >/dev/null 2>&1; then
  echo "⚠️ 网络不可用，跳过 apt 部分"
fi

# [第一刀] 无关平台固件裁剪（path-exclude 已防回装）
for d in qcom i915 amdgpu radeon nvidia ath11k ath10k iwlwifi mediatek mrvl ti-connectivity rkwifi ath12k intel qca; do
  [ -d /lib/firmware/$d ] && rm -rf /lib/firmware/$d
done

# [第二刀] 文档/man/locale（保留 en/zh）
rm -rf /usr/share/doc/* /usr/share/man/* 2>/dev/null
find /usr/share/locale -maxdepth 1 -mindepth 1 -type d ! -name 'en*' ! -name 'zh*' 2>/dev/null | xargs rm -rf 2>/dev/null

# [第三刀] apt 卸载编译链/git/zsh/aptitude/unicode-data
export DEBIAN_FRONTEND=noninteractive
chsh -s /bin/bash root 2>/dev/null
apt-get remove --purge -y gcc-12 g++-12 cpp-12 libstdc++-12-dev libgcc-12-dev \
  binutils-aarch64-linux-gnu binutils-common libc6-dev \
  git zsh-common armbian-zsh zsh aptitude aptitude-common unicode-data >/dev/null 2>&1
apt-get autoremove --purge -y >/dev/null 2>&1
apt-get clean

AFTER=$(du -sm / 2>/dev/null | cut -f1)
echo "精简后: ${AFTER} MB（释放 $((BEFORE-AFTER)) MB）"

# E900V22C 专属：DTB eMMC 降频修复（200MHz→50MHz，防 armbian-install I/O error）
# 只在 eMMC 启动前需要；U 盘启动时改的是 U 盘 boot 区 dtb，为写 eMMC 做准备
if [ -f /boot/dtb/amlogic/meson-g12a-s905l3a-e900v22c.dtb ] && command -v dtc >/dev/null 2>&1; then
  cd /boot/dtb/amlogic
  [ -f meson-g12a-s905l3a-e900v22c.dtb.bak ] || cp meson-g12a-s905l3a-e900v22c.dtb meson-g12a-s905l3a-e900v22c.dtb.bak
  dtc -I dtb -O dts -o m.dts meson-g12a-s905l3a-e900v22c.dtb.bak 2>/dev/null \
    && sed -i 's/max-frequency = <0xbebc200>/max-frequency = <0x2faf080>/' m.dts \
    && dtc -I dts -O dtb -o meson-g12a-s905l3a-e900v22c.dtb m.dts 2>/dev/null \
    && echo "DTB 降频修复完成（eMMC 写入 I/O error 的解法）"
  cd /
fi
echo "===== slim done ====="
} > "$LOG" 2>&1