#!/usr/bin/env bash
# ==============================================================================
# gen-prefixpack.sh - 融合式 prefixPack 生成器
# 方式：wineboot 真实初始化 + 中文注册表配置 + 中文字体注入
# 输出：未压缩 tar，由调用方分别压缩为 .txz (wcp) 和 .tzst (whp)
# 用法：gen-prefixpack.sh <输出.tar> [字体目录]
# ==============================================================================
set -euo pipefail

OUTPUT="${1:?用法: gen-prefixpack.sh <输出.tar> [字体目录]}"
FONT_DIR="${2:-}"
WINEPREFIX="${WINEPREFIX:-/tmp/wine-prefix-gen}"

echo "==> [prefix] 清理旧 prefix..."
rm -rf "${WINEPREFIX}"
mkdir -p "${WINEPREFIX}"

echo "==> [prefix] 检查宿主编译 Wine..."
if ! command -v wineboot &>/dev/null; then
  echo "ERROR: 未找到 wineboot，需要先安装宿主编译的 Wine (apt install wine)"
  exit 1
fi

echo "==> [prefix] wineboot 初始化容器..."
export WINEPREFIX
export WINEDLLOVERRIDES="mshtml=d,mscoree=d"  # 避免弹窗
wineboot -i 2>/dev/null || true
wineserver -w 2>/dev/null || true

# 验证注册表生成
for reg in system.reg user.reg userdef.reg; do
  if [ ! -f "${WINEPREFIX}/${reg}" ]; then
    echo "WARNING: ${reg} 未生成，wineboot 可能不完整"
  fi
done

echo "==> [prefix] 应用中文注册表配置..."
SYSREG="${WINEPREFIX}/system.reg"
USERREG="${WINEPREFIX}/user.reg"

# 代码页
sed -i 's/"ACP"="1252"/"ACP"="936"/' "$SYSREG" 2>/dev/null || true
sed -i 's/"OEMCP"="437"/"OEMCP"="936"/' "$SYSREG" 2>/dev/null || true
# 区域
sed -i 's/"Default"="0409"/"Default"="0804"/' "$SYSREG" 2>/dev/null || true
sed -i 's/"InstallLanguage"="0409"/"InstallLanguage"="0804"/' "$SYSREG" 2>/dev/null || true
# Locale 段
python3 - "$SYSREG" <<'PYEOF' 2>/dev/null || true
import sys, re
p = sys.argv[1]
with open(p, encoding='utf-8', errors='replace') as f: content = f.read()
def fix_locale(m):
    block = m.group(0)
    block = block.replace('@="00000409"', '@="00000804"', 1)
    return block
content = re.sub(r'\[System\\\\[^\]]*Nls\\\\Locale\][^\[]*', fix_locale, content, count=1, flags=re.DOTALL)
with open(p, 'w', encoding='utf-8') as f: f.write(content)
PYEOF
# 字体替换
sed -i 's/"MS Shell Dlg"="Tahoma"/"MS Shell Dlg"="Noto Sans CJK SC"/' "$SYSREG" 2>/dev/null || true
sed -i 's/"MS Shell Dlg 2"="Tahoma"/"MS Shell Dlg 2"="Noto Sans CJK SC"/' "$SYSREG" 2>/dev/null || true
# user.reg
sed -i 's/"Locale"="00000409"/"Locale"="00000804"/' "$USERREG" 2>/dev/null || true
sed -i 's/"LocaleName"="en-US"/"LocaleName"="zh-CN"/' "$USERREG" 2>/dev/null || true
sed -i 's/"sLanguage"="ENU"/"sLanguage"="CHS"/' "$USERREG" 2>/dev/null || true

echo "==> [prefix] 注入中文字体..."
FONTSDIR="${WINEPREFIX}/drive_c/windows/Fonts"
mkdir -p "${FONTSDIR}"
FONT_COUNT=0
if [ -n "$FONT_DIR" ] && [ -d "$FONT_DIR" ]; then
  for f in "${FONT_DIR}"/*.otf "${FONT_DIR}"/*.ttf "${FONT_DIR}"/*.ttc; do
    [ -f "$f" ] || continue
    cp "$f" "${FONTSDIR}/"
    FONT_COUNT=$((FONT_COUNT+1))
  done
fi
echo "  字体注入数: ${FONT_COUNT}"

echo "==> [prefix] 清理 dosdevices 和临时文件..."
rm -rf "${WINEPREFIX}/dosdevices"/*
rm -f "${WINEPREFIX}/.update-timestamp"

echo "==> [prefix] 打包为未压缩 tar: ${OUTPUT}..."
mkdir -p "$(dirname "$OUTPUT")"
cd "${WINEPREFIX}/.."
BASENAME=$(basename "${WINEPREFIX}")
tar -cf "${OUTPUT}" "${BASENAME}/"
# 重命名tar内的顶层目录为 .wine
cd /tmp
mkdir -p prefix-rename
tar -xf "${OUTPUT}" -C prefix-rename
mv "prefix-rename/${BASENAME}" "prefix-rename/.wine"
tar -cf "${OUTPUT}" -C prefix-rename .wine
rm -rf prefix-rename

echo "==> [prefix] 完成: ${OUTPUT} ($(du -h "${OUTPUT}" | cut -f1))"
