#!/usr/bin/env python3
"""校验生成的 apk 索引中 luci-theme-zwrt 的 ucode 依赖没有版本下限。

apk v3 的 packages.adb = "ADBd" + raw deflate 数据。数据里依赖项格式为：
  \x05<name>\x00           无版本约束
  \x05<name>\n<version>\x00 有版本下限
若主题被钉上 ucode>=<构建机上 ucode 版本>，旧固件（ucode 更老）会直接解析失败：
  ucode-...: breaks: luci-theme-zwrt[ucode>=...]
"""
import re
import sys
import zlib


def load(path):
    data = open(path, "rb").read()
    if data[:4] != b"ADBd":
        sys.exit(f"不是 ADBd 索引: {path}")
    return zlib.decompress(data[4:], -15)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "packages.adb"
    raw = load(path)
    pkg = b"luci-theme-zwrt"
    idx = raw.find(pkg)
    if idx < 0:
        sys.exit(f"索引中找不到 luci-theme-zwrt（可能选错了 packages.adb）: {path}")
    window = raw[idx : idx + 600]
    hit = re.search(b"\x05ucode([^\x00]*)", window)
    if not hit:
        print("OK: 无 ucode 依赖")
        return
    tail = hit.group(1)
    if tail.startswith(b"\n") and tail[1:].strip():
        ver = tail[1:].decode("utf-8", "ignore").strip()
        sys.exit(f"FAIL: luci-theme-zwrt 仍依赖 ucode>={ver}（旧固件会安装失败）")
    print("OK: ucode 依赖无版本下限")


if __name__ == "__main__":
    main()
