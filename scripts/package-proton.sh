#!/usr/bin/env bash
# ==============================================================================
# package-proton.sh - bionic Proton 双格式打包
#
# 产物：
#   proton-<ver>-<arch>.wcp      zstd 外层，profile type=Proton（GameNative）
#   proton-wine-<ver>-<arch>.wcp.xz  xz 外层，profile type=Wine（CMOD/Ludashi）
#
# 用法：
#   package-proton.sh --install-dir <安装树> --arch x86_64|arm64ec --version 11.0-2
#                     --prefix-pack <prefixPack.txz> --outdir <输出目录>
# ==============================================================================
set -euo pipefail

INSTALL_DIR=""
ARCH=""
VERSION=""
PREFIX_PACK=""
OUTDIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --arch)        ARCH="$2"; shift 2 ;;
    --version)     VERSION="$2"; shift 2 ;;
    --prefix-pack) PREFIX_PACK="$2"; shift 2 ;;
    --outdir)      OUTDIR="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
done

[ -d "$INSTALL_DIR/bin" ] || { echo "ERROR: 安装树不完整: $INSTALL_DIR/bin"; exit 2; }
case "$ARCH" in x86_64|arm64ec) ;; *) echo "ERROR: arch 必须是 x86_64 或 arm64ec"; exit 2 ;; esac
[ -n "$VERSION" ] || { echo "ERROR: 缺少 --version"; exit 2; }
[ -f "$PREFIX_PACK" ] || { echo "ERROR: prefixPack 不存在: $PREFIX_PACK"; exit 2; }
OUTDIR="${OUTDIR:-$(pwd)}"
mkdir -p "$OUTDIR"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -a "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/share" "$STAGING/"
cp "$PREFIX_PACK" "$STAGING/prefixPack.txz"

write_profile() {
  local type="$1"
  cat > "$STAGING/profile.json" <<EOF
{
  "type": "${type}",
  "versionName": "${VERSION}-${ARCH}",
  "versionCode": 1,
  "description": "Proton ${VERSION} ${ARCH} bionic - Valve wine + ntsync userspace + fsync + Android fixes, SDK 28, 16KB pages",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  }
}
EOF
}

PROTON_PKG="proton-${VERSION}-${ARCH}.wcp"
WINE_PKG="proton-wine-${VERSION}-${ARCH}.wcp.xz"

write_profile "Proton"
tar -I 'zstd -T0 -19' -C "$STAGING" -cf "${OUTDIR}/${PROTON_PKG}" profile.json prefixPack.txz bin lib share

write_profile "Wine"
tar -C "$STAGING" -cJf "${OUTDIR}/${WINE_PKG}" profile.json prefixPack.txz bin lib share

echo "PROTON_PKG ${OUTDIR}/${PROTON_PKG}"
echo "WINE_PKG ${OUTDIR}/${WINE_PKG}"
