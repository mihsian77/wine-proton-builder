#!/usr/bin/env bash
# ==============================================================================
# package-wcp.sh - Winlator wcp 格式打包
# 结构（参照 Waim908/wine-winlator）：
#   根目录: bin/ lib/ share/ profile.json prefixPack.txz
#   prefixPack.txz: xz 压缩
#   外层: zstd --ultra -22
# 用法：package-wcp.sh <install_prefix> <prefixPack.tar> <输出.wcp> <版本> <架构>
# ==============================================================================
set -euo pipefail

INSTALL_PREFIX="${1:?用法: package-wcp.sh <install_prefix> <prefixPack.tar> <输出.wcp> <版本> <架构>}"
PREFIX_TAR="${2:?缺少 prefixPack.tar}"
OUTPUT="${3:?缺少输出路径}"
VERSION="${4:-10.17}"
ARCH="${5:-amd64}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> [wcp] 组织目录结构..."
cp -r "${INSTALL_PREFIX}/bin" "${TMP}/"
cp -r "${INSTALL_PREFIX}/lib" "${TMP}/"
[ -d "${INSTALL_PREFIX}/share" ] && cp -r "${INSTALL_PREFIX}/share" "${TMP}/"

echo "==> [wcp] 压缩 prefixPack.txz (xz -9e)..."
xz -T0 -9e -c "${PREFIX_TAR}" > "${TMP}/prefixPack.txz"

echo "==> [wcp] 生成 profile.json..."
cat > "${TMP}/profile.json" <<EOF
{
  "type": "Wine",
  "versionName": "${VERSION}-${ARCH}",
  "versionCode": 1,
  "description": "Wine ${VERSION} ${ARCH} - NLS multi-language Chinese localized",
  "files": [],
  "wine": {
    "binPath": "bin",
    "libPath": "lib",
    "prefixPack": "prefixPack.txz"
  }
}
EOF

echo "==> [wcp] 清理多余文件..."
find "${TMP}" -type f -name "*.a" -delete 2>/dev/null || true
find "${TMP}" -type f -name "*.def" -delete 2>/dev/null || true
rm -rf "${TMP}/share/man" "${TMP}/share/doc" 2>/dev/null || true

echo "==> [wcp] 打包 (zstd --ultra -22)..."
mkdir -p "$(dirname "$OUTPUT")"
cd "${TMP}"
tar -I "zstd -T0 --ultra -22" -cf "${OUTPUT}" .
echo "==> [wcp] 完成: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
