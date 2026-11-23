#!/usr/bin/env bash
# ==============================================================================
# package-wcp.sh - Winlator wcp 格式打包（ludashi / bionic 系）
#
# 结构：
#   根目录: bin/ lib/ share/ profile.json prefixPack.txz
#   prefixPack.txz: xz -9e
#   外层: zstd --ultra -22
#
# 用法：package-wcp.sh <install_prefix> <prefixPack.tar> <输出.wcp> <版本> <架构，默认 x86_64>
# ==============================================================================
set -euo pipefail

INSTALL_PREFIX="${1:?用法: package-wcp.sh <install_prefix> <prefixPack.tar> <输出.wcp> <版本> <架构>}"
PREFIX_TAR="${2:?缺少 prefixPack.tar}"
OUTPUT="${3:?缺少输出路径}"
VERSION="${4:-10.17}"
ARCH="${5:-x86_64}"

# 脚本后面会 cd 到临时目录，输出路径必须先转成绝对路径
mkdir -p "$(dirname "${OUTPUT}")"
OUTPUT="$(cd "$(dirname "${OUTPUT}")" && pwd)/$(basename "${OUTPUT}")"
PREFIX_TAR="$(cd "$(dirname "${PREFIX_TAR}")" && pwd)/$(basename "${PREFIX_TAR}")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> [wcp] 组织目录结构"
cp -r "${INSTALL_PREFIX}/bin" "${TMP}/"
cp -r "${INSTALL_PREFIX}/lib" "${TMP}/"
[ -d "${INSTALL_PREFIX}/share" ] && cp -r "${INSTALL_PREFIX}/share" "${TMP}/"

echo "==> [wcp] 压缩 prefixPack.txz (xz -9e)"
xz -T0 -9e -c "${PREFIX_TAR}" > "${TMP}/prefixPack.txz"

echo "==> [wcp] 生成 profile.json"
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

echo "==> [wcp] 清理冗余"
find "${TMP}" -type f \( -name "*.a" -o -name "*.def" \) -delete 2>/dev/null || true
rm -rf "${TMP}/share/man" "${TMP}/share/doc" "${TMP}/include" 2>/dev/null || true

echo "==> [wcp] 打包（外层 zstd）"
mkdir -p "$(dirname "${OUTPUT}")"
cd "${TMP}"
tar --owner=0 --group=0 -I "zstd -T0 --ultra -22" -cf "${OUTPUT}" .
echo "==> [wcp] 完成: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
