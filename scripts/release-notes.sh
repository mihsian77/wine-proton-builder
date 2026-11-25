#!/usr/bin/env bash
# ==============================================================================
# release-notes.sh - 生成 Release 正文
#
# 素材来源：
#   - 上游公告：gitlab.winehq.org/wine/wine 的 ANNOUNCE.md（按 tag 取）
#   - 本仓库补丁清单：docs/patches.md + patches/ 目录实况
#
# 用法：release-notes.sh <版本> <profile> <格式列表，如 "whp wcp">
# ==============================================================================
set -euo pipefail

VER="${1:?用法: release-notes.sh <版本> <profile> <格式列表>}"
PROFILE="${2:?缺少 profile}"
FORMATS="${3:?缺少格式列表}"

ARCH="x86_64"
ANNOUNCE_URL="https://gitlab.winehq.org/wine/wine/-/raw/wine-${VER}/ANNOUNCE.md"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "## Wine ${VER}（${PROFILE}，${ARCH}）"
echo
echo "### 上游来源"
echo
echo "- 源码：[\`wine-mirror/wine\`](https://github.com/wine-mirror/wine/tree/wine-${VER})，tag \`wine-${VER}\`"
echo "- 上游公告：[winehq.org/announce/${VER}](https://www.winehq.org/announce/${VER})"
echo

echo "### 上游本次更新（摘自 ANNOUNCE）"
echo
if curl -sL --max-time 30 "${ANNOUNCE_URL}" -o "$TMP" && grep -q "What's new" "$TMP"; then
  awk '/What.s new in this release/{f=1;next} /^$/{if(f)exit} f' "$TMP" | sed 's/^/  /'
else
  echo "  （上游公告拉取失败，请看上方 winehq 链接）"
fi
echo

echo "### 本仓库补丁"
echo
PATCHES="patches/winlator-glibc-paths.patch"
[ -d patches/enhanced ] && for p in patches/enhanced/*.patch; do PATCHES="$PATCHES $(basename "$p")"; done
if [ "$PROFILE" = "core" ]; then
  echo "- \`winlator-glibc-paths.patch\`（路径修正：socket 目录、NLS、z 盘映射）"
else
  echo "- \`winlator-glibc-paths.patch\` + enhanced 补丁集："
  for p in patches/enhanced/*.patch; do echo "  - \`$(basename "$p")\`"; done
fi
echo

echo "### 构建"
echo
echo "- PE 侧：i386 + x86_64（WOW64），unix 库 16KB 页对齐"
echo "- 工具链：宿主 GCC + mingw-w64（PE），NLS 汉化随 PE 资源编入"
echo "- 验证：CI 全量编译通过；真机验证状态见下方"
echo

echo "### 安装"
echo
for f in $FORMATS; do
  case "$f" in
    whp) printf -- '- \x60wine-%s-%s.whp\x60 - winlator-pulse 导入\n' "$VER" "$ARCH" ;;
    wcp) printf -- '- \x60wine-%s-%s.wcp\x60 - ludashi_plus 导入\n' "$VER" "$ARCH" ;;
  esac
done
echo
echo "包内 prefix 由本包 wine 生成（wineboot），注册表版本与产物一致。"
