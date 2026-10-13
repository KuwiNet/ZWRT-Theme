#!/bin/bash
# 用官方 OpenWrt 主线(main) SDK 构建 luci-theme-zwrt 的 APK（apk 包格式，供官方 25.x/主线 apk 固件使用），
# 并按主流架构生成 apk 软件源目录（每个目录内含 .apk + packages.adb 索引）。
set -e
cd "$(dirname "$0")"

echo "=== Step 1: 提取版本号 ==="
PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' Makefile | xargs)
[ -z "$PKG_VERSION" ] && { echo "无法提取 PKG_VERSION" >&2; exit 1; }
echo "版本: $PKG_VERSION"

echo "=== Step 2: 安装 zstd（解压 .tar.zst SDK） ==="
sudo apt-get update >/dev/null 2>&1 || true
sudo apt-get install -y zstd >/dev/null 2>&1 || true

echo "=== Step 3: 动态获取官方主线 SDK ==="
SDK_BASE="https://downloads.openwrt.org/snapshots/targets/x86/64"
SDK_FILE=$(curl -s "$SDK_BASE/" | grep -o 'openwrt-sdk-x86-64_gcc-[^"<>]*\.tar\.zst' | head -1)
[ -z "$SDK_FILE" ] && { echo "无法找到主线 SDK" >&2; exit 1; }
SDK_URL="$SDK_BASE/$SDK_FILE"
echo "SDK: $SDK_URL"

if [ ! -d openwrt-sdk ]; then
  echo "⬇️ 下载 SDK（约 290MB）..."
  curl -sL --retry 3 --retry-delay 5 "$SDK_URL" -o sdk.tar.zst || { echo "SDK 下载失败" >&2; exit 1; }
  tar --zstd -xf sdk.tar.zst
  mv openwrt-sdk-* openwrt-sdk
fi

echo "=== Step 4: 复制主题到 SDK ==="
rm -rf openwrt-sdk/package/luci-theme-zwrt
mkdir -p openwrt-sdk/package/luci-theme-zwrt
for item in Makefile htdocs luasrc ucode root doc README.md; do
  [ -e "$item" ] && cp -r "$item" openwrt-sdk/package/luci-theme-zwrt/
done

cd openwrt-sdk
echo "=== Step 5: 全量更新 feeds（含 base）并编译 ==="
# lua/libubox/ucode/rpcd 等在 base feed，必须 update -a，否则缺 lua.h 编译失败
./scripts/feeds update -a
./scripts/feeds install -p luci luci-base
make defconfig >/dev/null 2>&1 || true
echo "--- 开始编译（V=99 完整输出） ---"
make package/luci-theme-zwrt/compile V=99 2>&1 | tail -200 || { echo "编译失败" >&2; exit 1; }
echo "--- 生成 apk 源索引（make package/index → packages.adb，官方标准） ---"
make package/index V=99 2>&1 | tail -30 || true
cd -

echo "=== Step 6: 定位 APK 产物与 packages.adb 索引 ==="
APK=$(find openwrt-sdk/bin/packages -name "luci-theme-zwrt*.apk" | head -1)
ADB=$(find openwrt-sdk/bin/packages -name "packages.adb" | head -1)
[ -z "$APK" ] && { echo "未找到 luci-theme-zwrt.apk" >&2; exit 1; }
[ -z "$ADB" ] && { echo "未找到 packages.adb（make package/index 未生成）" >&2; exit 1; }
echo "APK: $APK"; ls -lh "$APK"
echo "ADB: $ADB"; ls -lh "$ADB"

echo "=== Step 7: 生成多架构 apk 源（复制 apk + packages.adb 到各架构目录） ==="
ARCHS=(x86_64 aarch64_cortex-a53 aarch64_cortex-a72 aarch64_cortex-a76 \
       aarch64_generic arm_cortex-a7 arm_cortex-a9 mips_24kc mipsel_24kc riscv64_riscv64)
rm -rf apk-feed
for a in "${ARCHS[@]}"; do
  d="apk-feed/$a"
  mkdir -p "$d"
  cp "$APK" "$d/"
  cp "$ADB" "$d/packages.adb"
  echo "  ok: $a"
done

echo "=== Step 8: 输出 ==="
find apk-feed -name packages.adb | sort
echo "APK_RELEASE_TAG=luci-theme-zwrt-${PKG_VERSION}" >> $GITHUB_ENV
echo "APK_FEED_DIR=$PWD/apk-feed" >> $GITHUB_ENV
echo "✅ apk 源生成完成"
