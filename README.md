# wine-proton-builder

Winlator 用的 Wine 源码编译脚本。目前只跑通 x86_64 WOW64 一条线，产出 `.wcp` 和 `.whp` 两个包。

## 现状

已经能跑的：

- 分阶段编译：宿主编 native tools（wrc/winebuild）+ NLS，再交叉编译 PE，让 wrc 把 `po/<lang>.mo` 的翻译写进 PE 资源
- prefixPack：用刚编译出来的 wine 执行 wineboot 生成，不是用宿主 apt 的 wine，注册表版本和产物一致
- 汉化走 gettext NLS + 中文代码页/区域 + CJK 字体注入，不做二进制字符串硬改
- 双格式打包：`.wcp` 内层 `prefixPack.txz`（xz），`.whp` 内层 `container-pattern-*.tzst`（zstd）

还没实现（早期 README 里列过，仓库里没有对应文件，这里标清楚免得看错）：

- arm64ec 构建、Proton 构建
- 闭源包二次加工（解包 → 换资源 → 重打包）
- `patches/` 补丁库和 `docs/`

## 目录

```
.github/workflows/build-wine.yml   参数化构建：选源码仓库/ref/版本/线程
scripts/build-wine.sh              分阶段编译 + strip + 产物校验
scripts/gen-prefixpack.sh          prefixPack 生成（wineboot + 中文注册表 + 字体）
scripts/package-wcp.sh             .wcp 打包
scripts/package-whp.sh             .whp 打包
```

## 用法

Actions → **Build Wine (Winlator)** → Run workflow，填四个参数：

| 参数 | 说明 |
|---|---|
| `wine_repo` | 源码仓库，默认 `mihsian77/wine-10.17-winlator` |
| `wine_ref` | 分支/tag/commit |
| `wine_version` | 产物版本号，写进目录名和 profile.json |
| `jobs` | 编译线程数，2 核 runner 给 2 就行 |

跑完得到两个 artifact：`Wine-<ver>-x86_64-zh`（wcp）和 `Wine-<ver>-x86_64-zh-whp`（whp）。

## 几个踩过的坑

1. **源码必须是 Winlator 那一套**。wineserver 的 socket 目录在 `server/request.c` 和 `dlls/ntdll/unix/server.c` 里写死为 `/data/data/com.winlator/files/rootfs/tmp`，普通 winehq 源码没这条路径，CI 上 wineboot 会直接退出。脚本里已经在生成 prefix 前把目录建出来。
2. **wineboot 返回不等于 prefix 写完**。wineserver 还在后台，`system.reg`/`user.reg` 可能没落盘，这时候打包会得到一个没有注册表的 prefix，patch 阶段必失败。脚本里先 `wineserver -k` 再等文件出现。
3. **whp 外层必须是 zstd**。早期脚本用 xz，打出来 magic 是 `fd377a585a00`，和 App 实际读的 `28b52ffd` 不符。
4. **NLS 的 `.mo` 在构建目录**，不在源码 `po/` 下，查错时别看错地方。

## 参考项目

- [as14725836/termux-glibc-mangohud](https://github.com/as14725836/termux-glibc-mangohud) — CI 里管补丁序列和多版本矩阵
- [Waim908/wine-winlator](https://github.com/Waim908/wine-winlator) — wcp/whp 包结构
- [kaldin54321-boop/Wine-for-winlator-official](https://github.com/kaldin54321-boop/Wine-for-winlator-official) — 参数化 workflow 设计
- [marcomorosi06/DroidWine](https://github.com/marcomorosi06/DroidWine) — 16KB 页大小修复

## 许可

Wine 源码遵循 LGPL-2.1，本仓库脚本遵循 MIT。
