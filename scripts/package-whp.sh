#!/usr/bin/env bash
# ==============================================================================
# package-whp.sh - Winlator whp 格式打包（winlator-pulse）
# 结构（参照 Waim908/wine-winlator）：
#   wine-$version-/  (bin/lib/share)
#   container-pattern-$version.tzst  (prefixPack, zstd 压缩)
#   外层: xz -9e
#   无 profile.json
# 用法：package-whp.sh <install_prefix> <prefixPack.tar> <输出.whp> <版本>
# ==============================================================================
set -euo pipefail

INSTALL_PREFIX="${1:?用法: package-whp.sh <install_prefix> <prefixPack.tar> <输出.whp> <版本>}"
PREFIX_TAR="${2:?缺少 prefixPack.tar}"
OUTPUT="${3:?缺少输出路径}"
VERSION="${4:-10.17}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> [whp] 组织目录结构..."
WINE_DIR="${TMP}/wine-${VERSION}-"
mkdir -p "${WINE_DIR}"
cp -r "${INSTALL_PREFIX}/bin" "${WINE_DIR}/"
cp -r "${INSTALL_PREFIX}/lib" "${WINE_DIR}/"
[ -d "${INSTALL_PREFIX}/share" ] && cp -r "${INSTALL_PREFIX}/share" "${WINE_DIR}/"

echo "==> [whp] 压缩 container-pattern.tzst (zstd -9)..."
zstd -T0 -9 -c "${PREFIX_TAR}" > "${TMP}/container-pattern-${VERSION}.tzst"

echo "==> [whp] 清理多余文件..."
find "${WINE_DIR}" -type f -name "*.a" -delete 2>/dev/null || true
find "${WINE_DIR}" -type f -name "*.def" -delete 2>/dev/null || true
rm -rf "${WINE_DIR}/share/man" "${WINE_DIR}/share/doc" 2>/dev/null || true
rm -rf "${WINE_DIR}/include" 2>/dev/null || true

echo "==> [whp] 打包 (xz -9e)..."
mkdir -p "$(dirname "$OUTPUT")"
cd "${TMP}"
tar -I "xz -T0 -9e" -cf "${OUTPUT}" "wine-${VERSION}-" "container-pattern-${VERSION}.tzst"
echo "==> [whp] 完成: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
