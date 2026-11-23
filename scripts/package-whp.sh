#!/usr/bin/env bash
# ==============================================================================
# package-whp.sh - Winlator whp 格式打包（winlator-pulse）
#
# 结构（对第三方 wine-11.8.1.whp 实测得到）：
#   wine-$version-/    bin/ lib/ share/
#   container-pattern-$version.tzst    prefixPack 的 zstd 压缩
#   外层：zstd，magic 28b52ffd
#
# 注意：早期版本这里用 xz 外层，与 App 实际读取的格式不符，
# 打出来的包 magic 是 fd377a585a00，会被拒绝。
#
# 用法：package-whp.sh <install_prefix> <prefixPack.tar> <输出.whp> <版本>
# ==============================================================================
set -euo pipefail

INSTALL_PREFIX="${1:?用法: package-whp.sh <install_prefix> <prefixPack.tar> <输出.whp> <版本>}"
PREFIX_TAR="${2:?缺少 prefixPack.tar}"
OUTPUT="${3:?缺少输出路径}"
VERSION="${4:-10.17}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> [whp] 组织目录结构"
WINE_DIR="${TMP}/wine-${VERSION}-"
mkdir -p "${WINE_DIR}"
cp -r "${INSTALL_PREFIX}/bin" "${WINE_DIR}/"
cp -r "${INSTALL_PREFIX}/lib" "${WINE_DIR}/"
[ -d "${INSTALL_PREFIX}/share" ] && cp -r "${INSTALL_PREFIX}/share" "${WINE_DIR}/"

echo "==> [whp] 压缩 container-pattern (zstd -19)"
zstd -T0 -19 -c "${PREFIX_TAR}" > "${TMP}/container-pattern-${VERSION}.tzst"

echo "==> [whp] 清理冗余"
find "${WINE_DIR}" -type f \( -name "*.a" -o -name "*.def" \) -delete 2>/dev/null || true
rm -rf "${WINE_DIR}/share/man" "${WINE_DIR}/share/doc" "${WINE_DIR}/include" 2>/dev/null || true

CP_SIZE=$(stat -c %s "${TMP}/container-pattern-${VERSION}.tzst")
if [ "${CP_SIZE}" -lt 10485760 ]; then
  echo "ERROR: container-pattern 只有 ${CP_SIZE} 字节，prefix 生成失败"
  exit 1
fi

echo "==> [whp] 打包（外层 zstd）"
mkdir -p "$(dirname "${OUTPUT}")"
cd "${TMP}"
tar --owner=0 --group=0 -I "zstd -T0 -19" -cf "${OUTPUT}" "wine-${VERSION}-" "container-pattern-${VERSION}.tzst"
echo "==> [whp] 完成: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
