#!/usr/bin/env bash
# ==============================================================================
# build-proton.sh - bionic 线构建（GameNative/proton-wine 基底）
#
# 宿主环境：Linux x86_64（CI runner 或本地）
# 目标环境：Android bionic，x86_64 / arm64ec，SDK 28
#
# 前置依赖（由工作流或本地脚本准备）：
#   $HOME/termuxfs/<arch>/data/data/com.termux/files/usr   bionic 兼容库
#   $HOME/Android/Sdk/ndk/<ver>/toolchains/llvm/prebuilt/linux-x86_64/bin  NDK clang
#   $HOME/toolchains/llvm-mingw-*/bin                      PE 侧 llvm-mingw
#   NTSYNC_ANDROID_DIR                                      ntsync-android 检出
#
# 用法：
#   build-proton.sh --srcdir <proton-wine 源目录> --arch x86_64|aarch64 [--steps all|prepare|build]
# ==============================================================================
set -euo pipefail

SRCDIR=""
ARCH=""
STEPS="all"

while [ $# -gt 0 ]; do
  case "$1" in
    --srcdir) SRCDIR="$2"; shift 2 ;;
    --arch)   ARCH="$2"; shift 2 ;;
    --steps)  STEPS="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
done

[ -n "$SRCDIR" ] || { echo "ERROR: 必须指定 --srcdir"; exit 2; }
[ -d "$SRCDIR/build-scripts" ] || { echo "ERROR: $SRCDIR 不是 proton-wine 源码目录"; exit 2; }
case "$ARCH" in x86_64) STEP="build-step-x86_64.sh" ;; aarch64) STEP="build-step-arm64ec.sh" ;; *) echo "ERROR: arch 必须是 x86_64 或 aarch64"; exit 2 ;; esac

cd "$SRCDIR"

if [ "$STEPS" = "all" ] || [ "$STEPS" = "prepare" ]; then
  if [ ! -f configure ]; then
    echo "==> autogen.sh"
    bash autogen.sh
  fi
  if [ ! -d wine-tools ]; then
    echo "==> wine-tools（step 0）"
    bash build-scripts/build-step0.sh
  fi
fi

if [ "$ARCH" = "aarch64" ]; then
  echo "==> sysvshm"
  bash "build-scripts/$STEP" --build-sysvshm
fi

echo "==> ntsync-android 用户态库"
bash "build-scripts/$STEP" --build-ntsync-android

echo "==> configure"
bash "build-scripts/$STEP" --configure

echo "==> build"
bash "build-scripts/$STEP" --build

echo "==> install"
bash "build-scripts/$STEP" --install

echo "PROTON_BUILD_OK arch=$ARCH"
