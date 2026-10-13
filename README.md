# ZWRT 主题（luci-theme-zwrt）

一款基于 [sirpdboy/luci-theme-kucat](https://github.com/sirpdboy/luci-theme-kucat) 二次开发的 OpenWrt / LuCI 主题。**保持原主题完整的前端与 CSS 样式**，在命名、依赖与交互上做了自包含改造：

- 全量改名 `kucat` → `zwrt`，作为独立主题存在（设置界面内置）；
- 主题自带壁纸（Bing / 小鸟 / 本地图）与默认配色；
- 内置独立的「ZWRT主题设置」界面，**不再依赖官方 `luci-app-advancedplus` / `luci-app-kucat-config`**；
- 提供持续更新的 opkg 软件源，可在路由器上直接添加并自动更新。

## 组成

本仓库构建产出**一个自包含软件包**：

| 软件包 | 说明 |
| --- | --- |
| `luci-theme-zwrt` | 主题本体（前端 / CSS / 壁纸 / 图标）+ 内置「系统 → ZWRT主题设置」界面与默认配置 |

> 设置界面已内置于主题包，安装 `luci-theme-zwrt` 即可全部使用。

## 特性

- 完整保留 Kucat 的 CSS 样式：侧栏、卡片、透明/毛玻璃、配色与明暗（auto / light / dark）模式；
- 内置壁纸源：**Bing**（已切换国内 `cn.bing.com`）、**小鸟壁纸**、**本地图片**，安装后默认开启壁纸；
- 多套配色预设（栅栏蓝 / 绿 / 炫灰等），可实时切换；
- 独立设置界面，无需额外安装官方配置插件；
- GitHub Actions 自动构建 + Release + GitHub Pages 托管 opkg 软件源，可在线升级。

## 快速安装（推荐）

在路由器的终端（或 LuCI「系统 → 软件包」）添加本仓库 opkg 源后安装：

```sh
# 1) 添加软件源（一次即可，之后可自动更新）
echo 'src/gz zwrt https://kuwinet.github.io/ZWRT-Theme/all' >> /etc/opkg/customfeeds.conf

# 2) 更新列表并安装
opkg update
opkg install luci-theme-zwrt
```

### 使用

1. 安装完成后，进入 LuCI **系统 → 系统 → 语言和界面**，将主题切换为 **ZWRT**；
2. 进入 **系统 → ZWRT主题设置**，配置壁纸来源（Bing / 小鸟 / 本地）、配色、透明与明暗模式。

### 升级

```sh
opkg update
opkg install --force-reinstall luci-theme-zwrt
```

## 本地构建

需要 OpenWrt SDK 环境（本仓库默认使用 `build_auto.sh`）：

```sh
curl -LO https://raw.githubusercontent.com/KuWiNet/ZWRT-Theme/js/build_auto.sh \
  && chmod +x build_auto.sh && ./build_auto.sh
```

脚本会调用 `scripts/gen-opkg-index.py` 在 `feeds/all` 下生成 `Packages` / `Packages.gz` / `Packages.manifest` 软件源索引，可直接配合 GitHub Pages 部署为 opkg 源。

## 目录结构

```text
htdocs/                主题前端资源（css / js / img / 壁纸 / 设置界面 view）
luasrc/                 controller（「ZWRT主题设置」菜单）
root/                   uci-defaults / 默认配置 / 壁纸 rpcd / rpcd ACL
scripts/
  gen-opkg-index.py    生成 opkg 软件源索引
build_auto.sh          SDK 自动构建脚本
.github/workflows/     自动构建 + Release + Pages 部署
```

## 鸣谢

- 原作者：**sirpdboy** —— [luci-theme-kucat](https://github.com/sirpdboy/luci-theme-kucat)
- 本仓库为在其基础上的二次开发与维护，版权与许可遵循原项目约定。
