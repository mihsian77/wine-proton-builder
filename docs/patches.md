# 补丁清单

## 内置补丁

`patches/winlator-glibc-paths.patch`

| 文件 | 改动 |
|---|---|
| `server/request.c`、`dlls/ntdll/unix/server.c` | wineserver socket 目录改为 `rootfs/tmp`，`__ANDROID__` 与 `#else` 两个分支都覆盖 |
| `server/unicode.c` | NLS 目录指向 rootfs |
| `dlls/ntdll/unix/server.c` | z 盘默认映射指向 rootfs |

10.0–11.22 全版本 dry-run 通过，11.22 沙箱实测 socket 目录落在 rootfs/tmp。

## enhanced 档位

`patches/enhanced/`，6 件，10.0–11.22 dry-run 全部干净，11.22 编译与运行验证通过。

| 补丁 | 作用 |
|---|---|
| `dlls_dnsapi_libresolv.c.patch` | dnsapi 走 libresolv |
| `termux-dns-fix.patch` | DNS 解析修正 |
| `dlls_midimap_midimap.c.patch`、`dlls_midimap_Makefile.in.patch` | MIDI 映射 |
| `dlls_win32u_clipboard.c.patch` | 剪贴板 |
| `dlls_user32_Makefile.in.patch` | user32 构建适配 |

## 未收录

- esync / fsync：钩子分散在 Proton 基树的 event、semaphore、mutex 等处，只带新文件打进 vanilla 是死代码。vanilla 10+ 自带 ntsync（`dlls/ntdll/unix/sync.c`、`server/inproc_sync.c`，走 `/dev/ntsync`），同步加速走这条线。
- 网络适配器文件适配：依赖外部生成的 adapterinfo，Winlator 不产生该文件，打进包里是死代码。
- 空的 wow64 补丁与无人引用的 nsi 公共头：不产生任何构建产物差异，已移除。
- 媒体补丁：语境集中在 11.18，和 11.22 有偏移，单独做 11.16–11.22 的 media 变体，不混进通用档位。

## 参考仓库

- `wine-mirror/wine`：版本 tag 来源
- `as14725836/termux-glibc-mangohud`：glibc 构建流水线与补丁序列
- `WinNative-Emu/proton-wine`：Proton 基树的 android 补丁
- `GameNative/wine`：双架构构建脚本与 ntsync 内核模块
- `Pipetto-crypto/wine`、`brunodev85/wine-10.10-custom`：Winlator 定制源码
- `Waim908/wine-termux`：BCC chroot 下的 glibc 构建
