#!/usr/bin/env bash
# ==============================================================================
# build-wine.sh - 分阶段编译 Wine（x86_64 WOW64，NLS 汉化嵌入）
#
# 阶段0: 宿主编译 native tools (wrc/winebuild) + NLS(.mo)
# 阶段1: mingw 交叉编译 PE，wrc 加载 po/<lang>.mo 把翻译写进 PE 资源
# 阶段2: make install + 体积优化 + strip
#
# 用法：
#   build-wine.sh --srcdir <源码目录> [--prefix <安装目录>] [--builddir <构建目录>]
#                 [--jobs N] [--clean]
# ==============================================================================
set -euo pipefail

SRCDIR=""
INSTALL_PREFIX="/tmp/wine_build"
BUILD_DIR=""
JOBS="$(nproc)"
CLEAN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --srcdir)   SRCDIR="$2"; shift 2 ;;
    --prefix)   INSTALL_PREFIX="$2"; shift 2 ;;
    --builddir) BUILD_DIR="$2"; shift 2 ;;
    --jobs)     JOBS="$2"; shift 2 ;;
    --clean)    CLEAN=true; shift ;;
    *) echo "未知参数: $1"; exit 2 ;;
  esac
done

[ -n "${SRCDIR}" ] || { echo "ERROR: 必须指定 --srcdir"; exit 2; }
SRCDIR="$(cd "${SRCDIR}" && pwd)"
[ -f "${SRCDIR}/configure" ] || { echo "ERROR: ${SRCDIR} 不是 Wine 源码目录"; exit 2; }
[ -n "${BUILD_DIR}" ] || BUILD_DIR="${SRCDIR}/wine"

if [ "${CLEAN}" = true ]; then
  rm -rf "${BUILD_DIR}" "${INSTALL_PREFIX}"
fi
mkdir -p "${BUILD_DIR}" "${INSTALL_PREFIX}"
cd "${BUILD_DIR}"

echo "==> [0/3] GStreamer 1.20 兼容性补丁"
# Ubuntu 22.04 的 GStreamer 1.20 没有 GstBufferMapInfo，它是 1.24+ 对 GstMapInfo 的别名
if grep -rl "GstBufferMapInfo" "${SRCDIR}/dlls/winegstreamer/" 2>/dev/null | grep -q .; then
  grep -rl "GstBufferMapInfo" "${SRCDIR}/dlls/winegstreamer/" 2>/dev/null | while read -r f; do
    sed -i 's/GstBufferMapInfo/GstMapInfo/g' "$f"
    echo "  已替换: $(basename "$f")"
  done
else
  echo "  上游已是 GstMapInfo，无需处理"
fi

if [ ! -f "Makefile" ]; then
  echo "==> [0/3] configure（WOW64: i386 + x86_64，NLS 开启，unix 库 16KB 页对齐）"
  # LDFLAGS 只作用于 unix .so 链接（PE 走 i386/x86_64_LDFLAGS），
  # 16KB 对齐兼容 Android 15+ 的 16KB 页内核设备
  export LDFLAGS="${LDFLAGS:-} -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
  "${SRCDIR}/configure" --prefix="${INSTALL_PREFIX}" \
    --enable-archs=i386,x86_64 \
    --enable-win64 \
    --with-mingw \
    --enable-nls \
    --with-freetype --with-fontconfig --with-gstreamer \
    --with-vulkan --with-opengl --with-sdl --with-gnutls \
    --with-xrandr --with-xrender --with-gssapi --with-krb5 \
    --with-pulse --with-alsa --with-openal --with-mpg123 \
    --enable-tools --disable-tests --disable-win16 \
    --without-unwind --without-dbus --without-inotify --without-netapi \
    --without-xshape --without-xxf86vm --without-xshm --without-xcomposite \
    --without-xfixes --without-xinerama --without-capi --without-coreaudio \
    --without-cups --without-gphoto --without-sane --without-oss \
    --without-pcap --without-pcsclite --without-udev --without-usb \
    --without-v4l2 --without-wayland --without-ffmpeg --without-opencl \
    --without-vosk
else
  echo "==> [0/3] 复用已有配置（Makefile 已存在）"
fi

echo "==> [1/3] native tools + NLS"
make __tooldeps__ -j"${JOBS}"
if [ -d "nls" ]; then
  make -C nls -j"${JOBS}"
  [ -f "nls/locale.nls" ] && echo "  locale.nls 已生成" || echo "  WARNING: locale.nls 未生成"
fi

echo "==> [2/3] 全量编译（${JOBS} 线程）"
make -j"${JOBS}"

# .mo 在第二阶段随全量 make 生成，位置在构建目录 po/，不是源码 po/
MO_COUNT=$(find po -maxdepth 1 -name "*.mo" 2>/dev/null | wc -l | tr -d ' ')
echo "  构建目录 .mo 数量: ${MO_COUNT}"
if [ "${MO_COUNT}" -eq 0 ]; then
  echo "ERROR: 没有生成 .mo，NLS 汉化会缺失"
  exit 1
fi
[ -f "po/zh_CN.mo" ] || echo "  WARNING: 缺少 po/zh_CN.mo"
grep -q "zh_CN" po/LINGUAS 2>/dev/null || echo "  WARNING: po/LINGUAS 未包含 zh_CN"

echo "==> [3/3] install + 体积优化"
make install STRIP=true

find "${INSTALL_PREFIX}" -type f \( -name "*.a" -o -name "*.def" \) -delete
rm -rf "${INSTALL_PREFIX}/share/man" "${INSTALL_PREFIX}/share/doc" "${INSTALL_PREFIX}/include"

echo "  strip ELF (bin + x86_64-unix)"
find "${INSTALL_PREFIX}/bin" -type f -exec sh -c 'file "$1" | grep -q ELF && strip --strip-all "$1" 2>/dev/null || true' _ {} \;
find "${INSTALL_PREFIX}/lib/wine/x86_64-unix" -type f -exec sh -c 'file "$1" | grep -q ELF && strip --strip-all "$1" 2>/dev/null || true' _ {} \;
echo "  strip PE x86_64 / i386"
find "${INSTALL_PREFIX}" -path "*x86_64-windows*" \( -name "*.dll" -o -name "*.exe" \) -exec x86_64-w64-mingw32-strip --strip-all {} + 2>/dev/null || true
find "${INSTALL_PREFIX}" -path "*i386-windows*" \( -name "*.dll" -o -name "*.exe" \) -exec i686-w64-mingw32-strip --strip-all {} + 2>/dev/null || true

echo "==> 校验产物"
[ -f "${INSTALL_PREFIX}/lib/wine/i386-windows/ntdll.dll" ] || { echo "ERROR: 缺少 i386 ntdll"; exit 1; }
[ -f "${INSTALL_PREFIX}/lib/wine/x86_64-windows/ntdll.dll" ] || { echo "ERROR: 缺少 x86_64 ntdll"; exit 1; }
[ -x "${INSTALL_PREFIX}/bin/wine" ] || { echo "ERROR: 缺少 bin/wine"; exit 1; }

ZERO=$(find "${INSTALL_PREFIX}/bin" -maxdepth 1 -type f -size 0 | wc -l | tr -d ' ')
if [ "${ZERO}" -gt 0 ]; then
  echo "ERROR: bin/ 有 ${ZERO} 个 0 字节入口，install 的符号链接丢失"
  exit 1
fi

echo "BUILD_OK prefix=${INSTALL_PREFIX} builddir=${BUILD_DIR}"
