# wine-proton-builder

Winlator 用的 Wine 源码编译。x86_64 WOW64 glibc 线已跑通全量稳定版
（10.0–10.20、11.0–11.22，上游 wine-mirror/wine），产出 tar.xz 构建产物，
另有 `.wcp` / `.whp` 打包脚本。

## 现状

已经能跑的：

- 全量版本矩阵：`build-glibc-matrix.yml`，versions 逗号分隔，44 个稳定版一次跑完
- 补丁档位：`core` 只打路径修正；`enhanced` 再加 6 件平台增强补丁
  （dnsapi、midimap、clipboard、dns-fix 等，全部 vanilla 实测干净）
- 路径修正补丁覆盖 glibc 分支：socket 目录落 rootfs/tmp，z 盘默认映射 rootfs
- unix 库 16KB 页对齐（`-Wl,-z,max-page-size=16384`），兼容 16KB 页内核设备
- 分阶段编译：宿主编 native tools + NLS，再交叉编译 PE，wrc 把 `po/<lang>.mo`
  翻译写进 PE 资源；产物带 BUILD_INFO.txt（上游 commit、补丁 sha256、工具链）
- prefixPack：用刚编译出来的 wine 执行 wineboot 生成，注册表版本和产物一致
- 双格式打包：`.wcp` 内层 `prefixPack.txz`（xz），`.whp` 内层 `container-pattern-*.tzst`（zstd）

还没实现：

- arm64ec / bionic 第二线、Proton 基树构建（esync/fsync 需要 Proton 基树，
  vanilla 10+ 已内置 ntsync，不硬塞）
- 媒体变体（winedmo + 自带 x86_64 FFmpeg，语境多在 11.18，单独做 11.16–11.22）
- 闭源包二次加工

## 目录

```
.github/workflows/build-glibc-matrix.yml  全量版本矩阵（core/enhanced 档位）
.github/workflows/build-wine.yml          参数化构建：选源码仓库/ref/版本/线程
patches/winlator-glibc-paths.patch        路径修正（socket + NLS + z 盘）
patches/enhanced/                         6 件平台增强补丁
scripts/build-wine.sh                     分阶段编译 + 16KB 对齐 + strip + 校验
scripts/gen-prefixpack.sh                 prefixPack 生成
scripts/package-wcp.sh / package-whp.sh   双格式打包
docs/patches.md                          补丁清单与参考仓库
```

## 用法

Actions → **Build Wine glibc (Winlator 11.2)** → Run workflow：

| 参数 | 说明 |
|---|---|
| `versions` | 逗号分隔，对应上游 tag `wine-<ver>`，如 `11.22` 或全量 44 版 |
| `jobs` | 编译线程数 |
| `profile` | `core` 仅路径修正；`enhanced` 加平台增强补丁集 |

产物 `wine-<ver>-x86_64-glibc[-enhanced]`（tar.xz + sha256 + BUILD_INFO），保留 14 天。

## 几个踩过的坑

1. **路径补丁必须覆盖 `#else` 分支**。socket 改写原来只在 `__ANDROID__` 分支里，
   glibc 构建走的是 `#else`，补丁打了等于没打。现在两个分支都改，
   沙箱实测 wineserver  socket 目录落在 `/data/data/com.winlator/files/rootfs/tmp`。
2. **wineboot 返回不等于 prefix 写完**。wineserver 还在后台，注册表可能没落盘，
   脚本里先 `wineserver -k` 再等文件出现。
3. **whp 外层必须是 zstd**。xz 的 magic 和 App 实际读的 `28b52ffd` 不符。
4. **NLS 的 `.mo` 在构建目录**，不在源码 `po/` 下。


## 许可

Wine 源码遵循 LGPL-2.1，本仓库脚本遵循 MIT。
