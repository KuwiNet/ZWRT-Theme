#!/bin/bash
set -e

echo "📦 构建 LuCI 主题 ZWRT (all 架构专用版)"

# -------------------------------
# Step 1: 提取版本号
# -------------------------------
if [ ! -f "Makefile" ]; then
  echo "❌ 错误：找不到 Makefile（主题源目录为仓库根目录）" >&2
  exit 1
fi

PKG_VERSION=$(awk -F'[ =]+' '/^PKG_VERSION:/ {print $2; exit}' Makefile | xargs)
if [ -z "$PKG_VERSION" ]; then
  echo "❌ 错误：无法提取 PKG_VERSION" >&2
  exit 1
fi

BUILD_DATE="r$(date +%Y%m%d)"
FULL_VERSION="${PKG_VERSION}-${BUILD_DATE}"

echo "🔖 版本: $PKG_VERSION"
echo "📅 构建日期: $BUILD_DATE"
echo "✅ 完整版本: $FULL_VERSION"

# -------------------------------
# Step 2: 配置路径
# -------------------------------
SDK_URL="https://downloads.openwrt.org/releases/23.05.2/targets/x86/64/openwrt-sdk-23.05.2-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
SDK_DIR="../openwrt-sdk"  # 主题现位于仓库根目录，SDK 需放到仓库根之外，避免 cp 复制自指
# 直接使用SDK的输出目录作为最终输出目录
OUTPUT_DIR="$SDK_DIR/bin/packages/x86_64/base"

# -------------------------------
# Step 3: 下载 SDK
# -------------------------------
if [ ! -d "$SDK_DIR" ]; then
  echo "⬇️ 下载 OpenWrt SDK..."
  wget -qO- "$SDK_URL" | tar -xJ
  mv openwrt-sdk-* "$SDK_DIR" || true
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "❌ 错误：SDK 目录缺失" >&2
  exit 1
fi

# -------------------------------
# Step 4: 复制主题 + 安装最小依赖
# -------------------------------
echo "📂 复制主题到 SDK..."
rm -rf "$SDK_DIR/package/luci-theme-zwrt" 2>/dev/null || true
mkdir -p "$SDK_DIR/package/luci-theme-zwrt"

# 主题源 = 仓库根（排除 .git / .github 子目录）
for item in Makefile htdocs luasrc ucode root doc README.md build.sh build_auto.sh install-zwrt.sh; do
  [ -e "$item" ] && cp -r "$item" "$SDK_DIR/package/luci-theme-zwrt/"
done

cd "$SDK_DIR"

# runner 镜像（Ubuntu 25.10+）默认把 coreutils 换成 uutils（Rust 版），install --version 不含 GNU，
# 会让 OpenWrt 预检报 "Please install GNU 'install'"。FORCE=1 对 prepare-tmpinfo 里的 .prereq-build 不生效，
# 所以这里先尝试换成 GNU 实现；换不到就直接 touch 预检戳记跳过整套 host 依赖检查（依赖已由 workflow apt 装好）。
if ! install --version 2>/dev/null | grep -q 'GNU'; then
  echo "⚠️ install 非 GNU 版本（$(command -v install 2>/dev/null)）：$(install --version 2>&1 | head -1)"
  sudo apt-get install -y coreutils-from-gnu >/dev/null 2>&1 || sudo apt-get install -y --reinstall coreutils >/dev/null 2>&1 || true
  hash -r
fi
if install --version 2>/dev/null | grep -q 'GNU'; then
  echo "✅ GNU install 就绪"
else
  echo "⚠️ 仍无 GNU install，跳过 OpenWrt host 预检（touch staging_dir/host/.prereq-build）"
  mkdir -p staging_dir/host
  touch staging_dir/host/.prereq-build
fi

echo "🔄 更新全部 feeds（克隆 feed 目录）..."
./scripts/feeds update -a

# 23.05 固定的 luci 版本里，lemon 用 `cc -o contrib/lemon` 编译；GCC 15 默认 -std=gnu23，
# C23 中 "void f();" 等价于 (void)，lemon.c 的 K&R 空括号声明会和后面带 struct lemon *
# 参数的定义冲突，导致 luci-base host 编译失败。上游后续就是给这条规则补 -std=gnu17 修掉的。
LUCIMK=feeds/luci/modules/luci-base/src/Makefile
if [ -f "$LUCIMK" ] && grep -q 'cc -o contrib/lemon' "$LUCIMK"; then
  sed -i 's|cc -o contrib/lemon |cc -std=gnu17 -o contrib/lemon |' "$LUCIMK"
  echo "✅ 已给 lemon 编译规则补 -std=gnu17（同上游修法）"
fi

echo "📦 安装主题构建所需依赖 (luci-base)..."
./scripts/feeds install -p luci luci-base

make defconfig

cd - > /dev/null

echo "✅ 最小依赖安装完成"

# -------------------------------
# Step 5: 编译主题（含内置设置界面）
# -------------------------------
echo "⚙️ 开始编译主题（含内置设置界面）..."
make -C "$SDK_DIR" package/luci-theme-zwrt/compile V=s

# -------------------------------
# Step 6: 查找并验证编译生成的 IPK
# -------------------------------
# 匹配 SDK 编译输出的 IPK 路径（主题）
IPK_GLOB="$OUTPUT_DIR/luci-theme-zwrt_${PKG_VERSION}_*.ipk"
IPK_REAL_SRC=$(ls $IPK_GLOB 2>/dev/null | head -n1 | xargs realpath 2>/dev/null)

if [ ! -f "$IPK_REAL_SRC" ]; then
  echo "❌ 错误：未找到编译生成的主题 .ipk 文件！期望路径格式：" >&2
  echo "    $IPK_GLOB" >&2
  # 辅助排查：列出所有可能的 IPK 文件
  echo "当前 SDK 输出目录下的 IPK 文件："
  find "$SDK_DIR/bin/packages" -type f -name "luci-theme-zwrt_*.ipk" -ls 2>/dev/null || echo "无"
  exit 1
fi

echo "✅ 找到编译生成的主题 IPK: $IPK_REAL_SRC"

# 验证 IPK 文件格式有效性
echo "🔍 验证 IPK 文件格式（主题）..."
if ! ar t "$IPK_REAL_SRC" >/dev/null 2>&1; then
  echo "⚠️ ar 工具验证失败，尝试使用 bsdtar 二次验证..."
  if command -v bsdtar >/dev/null; then
    if ! bsdtar -tf "$IPK_REAL_SRC" >/dev/null; then
      echo "❌ IPK 文件损坏或格式不正确"
      echo "文件信息: $(file "$IPK_REAL_SRC")"
      echo "文件大小: $(du -h "$IPK_REAL_SRC")"
      exit 1
    else
      echo "✅ bsdtar 验证通过（IPK 格式有效）"
    fi
  else
    echo "❌ 请安装 libarchive-tools 以验证 IPK：sudo apt-get install libarchive-tools"
    exit 1
  fi
else
  echo "✅ ar 验证通过（IPK 格式有效）"
fi

# -------------------------------
# Step 7: 显示构建结果
# -------------------------------
echo -e "\n🎉 构建成功！最终文件信息："
ls -lh "$IPK_REAL_SRC"
echo "📁 主题输出路径：$IPK_REAL_SRC"

# 导出版本号到 GitHub 环境变量
echo "RELEASE_TAG=luci-theme-zwrt-${FULL_VERSION}" >> $GITHUB_ENV
echo "IPK_PATH=$IPK_REAL_SRC" >> $GITHUB_ENV  # 导出IPK路径方便后续处理

# -------------------------------
# 清理函数（可选）
# -------------------------------
cleanup() {
  echo -e "\n🧹 清理临时文件..."
  # 可选：清理SDK编译缓存
  # make -C "$SDK_DIR" package/luci-theme-zwrt/clean >/dev/null 2>&1
  echo "✅ 清理完成"
}
trap cleanup EXIT
