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
SDK_FILE=$(curl -s --max-time 60 "$SDK_BASE/" | grep -o 'openwrt-sdk-x86-64_gcc-[^"<>]*\.tar\.zst' | head -1)
[ -z "$SDK_FILE" ] && { echo "无法找到主线 SDK" >&2; exit 1; }
SDK_URL="$SDK_BASE/$SDK_FILE"
echo "SDK: $SDK_FILE"

# downloads.openwrt.org 对 CI 常限速/超时，增加 USTC 镜像回退 + 断点续传 + 完整性校验
SDK_MIRRORS=(
  "$SDK_BASE"
  "https://mirrors.ustc.edu.cn/openwrt/snapshots/targets/x86/64"
)

if [ ! -d openwrt-sdk ]; then
  got=
  for base in "${SDK_MIRRORS[@]}"; do
    for attempt in 1 2 3; do
      echo "⬇️ 下载 SDK（$base，第 $attempt 次，约 290MB）..."
      rm -f sdk.tar.zst.part
      if curl -fL --connect-timeout 30 --retry 3 --retry-delay 5 --retry-all-errors \
           --speed-limit 4096 --speed-time 60 \
           "$base/$SDK_FILE" -o sdk.tar.zst.part \
         && mv sdk.tar.zst.part sdk.tar.zst \
         && tar --zstd -tf sdk.tar.zst >/dev/null 2>&1; then
        got=1
        break
      fi
      echo "   该镜像第 $attempt 次失败，稍后重试"
      sleep 10
    done
    [ "$got" = 1 ] && break
  done
  [ "$got" = 1 ] || { echo "SDK 下载失败（官方与 USTC 镜像均已重试）" >&2; exit 1; }
  echo "✅ SDK 下载完成，解压中..."
  tar --zstd -xf sdk.tar.zst
  mv openwrt-sdk-* openwrt-sdk
fi

# 主线快照的 host 预检没有 GNU install 这一项，但预检本身必须在 staging_dir/host/bin 里
# 生成 gcc 等宿主工具软链，绝不能跳过（跳过会导致 lua 等 host 包编译时找不到编译器）。
# runner 镜像（Ubuntu 25.10+）的 install 是 uutils 版，对主线没有影响，这里只做信息提示。
if ! install --version 2>/dev/null | grep -q 'GNU'; then
  echo "ℹ️ install 非 GNU 版本（$(install --version 2>&1 | head -1)）；主线预检不检查它，继续正常执行预检"
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

# 23.05 固定的 luci 版本里，lemon 用 `cc -o contrib/lemon` 编译；GCC 15 默认 -std=gnu23，
# C23 中 "void f();" 等价于 (void)，lemon.c 的 K&R 空括号声明会和后面带 struct lemon *
# 参数的定义冲突，导致 luci-base host 编译失败。上游后续就是给这条规则补 -std=gnu17 修掉的。
LUCIMK=feeds/luci/modules/luci-base/src/Makefile
if [ -f "$LUCIMK" ] && grep -q 'cc -o contrib/lemon' "$LUCIMK"; then
  sed -i 's|cc -o contrib/lemon |cc -std=gnu17 -o contrib/lemon |' "$LUCIMK"
  echo "✅ 已给 lemon 编译规则补 -std=gnu17（同上游修法）"
fi

./scripts/feeds install -p luci luci-base
make defconfig 2>&1 | tail -40 || true
echo "--- 关闭 ucode 模板预编译（否则产物要求 ucode>=2026.02.27，旧固件无法安装） ---"
sed -i '/^CONFIG_LUCI_UTMIN=/d' .config
echo '# CONFIG_LUCI_UTMIN is not set' >> .config
make defconfig 2>&1 | tail -40 || true
grep -q '^# CONFIG_LUCI_UTMIN is not set' .config && echo "  ok: CONFIG_LUCI_UTMIN=n" || { echo "关闭 LUCI_UTMIN 失败" >&2; exit 1; }
echo "--- 开始编译（V=99 完整输出） ---"
make package/luci-theme-zwrt/compile V=99 2>&1 | tail -200 || { echo "编译失败" >&2; exit 1; }
echo "--- 生成 apk 源索引（make package/index → packages.adb，官方标准） ---"
make package/index V=99 2>&1 | tail -30 || true
cd -

echo "=== Step 6: 定位 APK 产物与 packages.adb 索引 ==="
APK=$(find openwrt-sdk/bin/packages -name "luci-theme-zwrt*.apk" | head -1)
[ -z "$APK" ] && { echo "未找到 luci-theme-zwrt.apk" >&2; exit 1; }
# 索引必须取主题所在的那一个（bin/packages/<arch>/<feed>/packages.adb），
# 不能随便挑一个 packages.adb——luci feed 的索引里没有本主题。
ADB="${APK%/*}/packages.adb"
if [ ! -f "$ADB" ]; then
  ADB=$(find openwrt-sdk/bin/packages -name packages.adb | head -1)
fi
[ -z "$ADB" ] && { echo "未找到 packages.adb（make package/index 未生成）" >&2; exit 1; }
echo "APK: $APK"; ls -lh "$APK"
echo "ADB: $ADB"; ls -lh "$ADB"

echo "--- 校验 ucode 依赖未被钉版本 ---"
python3 scripts/check-apk-deps.py "$ADB" || { echo "依赖校验失败：产物要求过高版本 ucode，旧固件将无法安装" >&2; exit 1; }

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
echo "APK_RELEASE_TAG=v${PKG_VERSION}" >> $GITHUB_ENV
echo "APK_FEED_DIR=$PWD/apk-feed" >> $GITHUB_ENV
tar -czf apk-feed.tar.gz apk-feed
echo "APK_TAR=$PWD/apk-feed.tar.gz" >> $GITHUB_ENV
echo "✅ apk 源生成完成"
