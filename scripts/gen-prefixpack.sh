#!/usr/bin/env bash
# ==============================================================================
# gen-prefixpack.sh - 生成真实可用的 prefixPack（中文环境）
#
# 用刚编译出来的 wine 执行 wineboot，而不是宿主机 apt 装的那套，
# 否则注册表版本与产物不一致。输出未压缩 tar，根目录为 .wine/。
#
# 用法：
#   gen-prefixpack.sh --wine-prefix <安装目录> --output <输出.tar>
#                     [--fonts <字体目录>] [--workdir <临时目录>]
# ==============================================================================
set -euo pipefail

WINE_PREFIX=""
OUTPUT=""
FONT_DIR=""
WORK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --wine-prefix) WINE_PREFIX="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    --fonts)       FONT_DIR="$2"; shift 2 ;;
    --workdir)     WORK="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
done

[ -n "${WINE_PREFIX}" ] || { echo "ERROR: 必须指定 --wine-prefix"; exit 2; }
[ -x "${WINE_PREFIX}/bin/wine" ] || { echo "ERROR: ${WINE_PREFIX}/bin/wine 不存在"; exit 2; }
[ -n "${OUTPUT}" ] || { echo "ERROR: 必须指定 --output"; exit 2; }
[ -n "${WORK}" ] || WORK="$(mktemp -d)"

rm -rf "${WORK}"
mkdir -p "${WORK}"
export WINEPREFIX="${WORK}/.wine"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml="
export PATH="${WINE_PREFIX}/bin:${PATH}"

echo "==> [prefix] 准备 wineserver socket 目录"
# 目标源码把 socket 目录写死为 Android rootfs 路径
# (server/request.c, dlls/ntdll/unix/server.c)，宿主上必须预先存在
WINE_TMP="/data/data/com.winlator/files/rootfs/tmp"
if [ ! -d "${WINE_TMP}" ]; then
  mkdir -p "${WINE_TMP}" 2>/dev/null || sudo mkdir -p "${WINE_TMP}" 2>/dev/null || true
  chmod 1777 "${WINE_TMP}" 2>/dev/null || sudo chmod 1777 "${WINE_TMP}" 2>/dev/null || true
  echo "  已创建: ${WINE_TMP}"
fi

echo "==> [prefix] wineboot 初始化"
BOOT_LOG="${WORK}/wineboot.log"
if command -v xvfb-run >/dev/null 2>&1; then
  timeout 1800 xvfb-run -a "${WINE_PREFIX}/bin/wine" wineboot -u >"${BOOT_LOG}" 2>&1 || true
else
  timeout 1800 "${WINE_PREFIX}/bin/wine" wineboot -u >"${BOOT_LOG}" 2>&1 || true
fi

if [ ! -d "${WINEPREFIX}/drive_c/windows/system32" ]; then
  echo "ERROR: prefix 不完整，缺少 drive_c/windows/system32"
  tail -30 "${BOOT_LOG}" 2>/dev/null || true
  exit 1
fi

echo "==> [prefix] 关停 wineserver，等待注册表落盘"
[ -x "${WINE_PREFIX}/bin/wineserver" ] && timeout 120 "${WINE_PREFIX}/bin/wineserver" -k >/dev/null 2>&1 || true
for _ in $(seq 1 30); do
  { [ -f "${WINEPREFIX}/system.reg" ] && [ -f "${WINEPREFIX}/user.reg" ]; } && break
  sleep 2
done
[ -f "${WINEPREFIX}/system.reg" ] || { echo "ERROR: 缺少 system.reg"; ls -la "${WINEPREFIX}" | head -20; exit 1; }
[ -f "${WINEPREFIX}/user.reg" ]   || { echo "ERROR: 缺少 user.reg";   exit 1; }

echo "==> [prefix] 中文代码页 / 区域"
SYSREG="${WINEPREFIX}/system.reg"
USERREG="${WINEPREFIX}/user.reg"

sed -i 's/"ACP"="1252"/"ACP"="936"/' "$SYSREG"
sed -i 's/"OEMCP"="437"/"OEMCP"="936"/' "$SYSREG"
sed -i 's/"Default"="0409"/"Default"="0804"/' "$SYSREG"
sed -i 's/"InstallLanguage"="0409"/"InstallLanguage"="0804"/' "$SYSREG"

python3 - "$SYSREG" <<'PYEOF'
import re, sys
p = sys.argv[1]
with open(p, encoding='utf-8', errors='replace') as f:
    content = f.read()

def fix_locale(m):
    return m.group(0).replace('@="00000409"', '@="00000804"', 1)

content = re.sub(r'\[System\\\\CurrentControlSet\\\\Control\\\\Nls\\\\Locale\][^\[]*',
                 fix_locale, content, count=1, flags=re.DOTALL)
with open(p, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

sed -i 's/"MS Shell Dlg"="Tahoma"/"MS Shell Dlg"="Noto Sans CJK SC"/' "$SYSREG" || true
sed -i 's/"MS Shell Dlg 2"="Tahoma"/"MS Shell Dlg 2"="Noto Sans CJK SC"/' "$SYSREG" || true
sed -i 's/"Locale"="00000409"/"Locale"="00000804"/' "$USERREG" || true
sed -i 's/"LocaleName"="en-US"/"LocaleName"="zh-CN"/' "$USERREG" || true
sed -i 's/"sLanguage"="ENU"/"sLanguage"="CHS"/' "$USERREG" || true

if [ -n "${FONT_DIR}" ] && [ -d "${FONT_DIR}" ]; then
  echo "==> [prefix] 注入中文字体"
  FONTSDIR="${WINEPREFIX}/drive_c/windows/Fonts"
  mkdir -p "${FONTSDIR}"
  COUNT=0
  for f in "${FONT_DIR}"/*.otf "${FONT_DIR}"/*.ttf "${FONT_DIR}"/*.ttc; do
    [ -f "$f" ] || continue
    cp "$f" "${FONTSDIR}/"
    COUNT=$((COUNT + 1))
  done
  echo "  注入 ${COUNT} 个字体文件"
else
  echo "  WARNING: 未提供字体目录，中文可能显示为方块"
fi

rm -rf "${WINEPREFIX}/dosdevices"/* 2>/dev/null || true
rm -f "${WINEPREFIX}/.update-timestamp"

echo "==> [prefix] 打包"
mkdir -p "$(dirname "${OUTPUT}")"
tar -cf "${OUTPUT}" -C "${WORK}" .wine
if ! tar -tf "${OUTPUT}" | grep -q "\.wine/system\.reg$"; then
  echo "ERROR: tar 结构异常，未包含 .wine/system.reg"
  exit 1
fi
echo "PREFIX_OK ${OUTPUT} $(du -h "${OUTPUT}" | cut -f1)"
