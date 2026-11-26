#!/usr/bin/env bash
# ==============================================================================
# release-notes-proton.sh - bionic Proton 线 Release 正文
#
# 用法：release-notes-proton.sh <版本> <源码 commit> <构建时间 UTC> <arch 列表>
# ==============================================================================
set -euo pipefail

VER="${1:?缺少版本}"
COMMIT="${2:?缺少源码 commit}"
BUILT_AT="${3:?缺少构建时间}"
ARCHS="${4:?缺少架构列表}"

echo "## Proton ${VER}（bionic）"
echo
echo "### 上游来源"
echo
echo "- 源码：[GameNative/proton-wine](https://github.com/GameNative/proton-wine)，ref \`proton_${VER}\`，commit \`${COMMIT}\`"
echo "- Wine 基底：[ValveSoftware/wine](https://github.com/ValveSoftware/wine/tree/proton_11.0)，分支 \`proton_11.0\`"
echo "- 前缀：[GameNative/bionic-prefix-files](https://github.com/GameNative/bionic-prefix-files)（prefixPack，含 disable 更新标记）"
echo
echo "### 构建"
echo
echo "- 目标环境：Android bionic，SDK 28，x86_64 / arm64ec，16KB 页对齐"
echo "- 依赖环境：Termux 前缀提供 bionic 兼容库；PE 侧 llvm-mingw 20250920"
echo "- 运行组件：ntsync 内核驱动优先，用户态 ntsync 回退（ntsync-android v0.2.0）"
echo "- 构建时间：${BUILT_AT}"
echo
echo "### 资产"
echo
for a in $ARCHS; do
  echo "- \`proton-${VER}-${a}.wcp\` — GameNative（profile type=Proton）"
  echo "- \`proton-wine-${VER}-${a}.wcp.xz\` — CMOD / Ludashi（profile type=Wine）"
done
echo
echo "包内 prefix 使用上游 prefixPack，首启即可新建容器。"
