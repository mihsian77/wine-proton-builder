# wine-proton-builder

面向 Winlator 系 Android 容器应用的 Wine 自动构建仓库。从上游 tag 出发编译，产出可直接导入的容器包，Release 正文记录上游来源、更新摘要与补丁清单。

## 产物

| 资产 | 格式 | 适用 |
|---|---|---|
| `wine-<版本>-x86_64.whp` | WHIP 容器包 | winlator-pulse |
| `wine-<版本>-x86_64.wcp` | WCP 容器包 | ludashi_plus |

包内构成：

- PE 侧 i386 + x86_64（WOW64 模式），NLS 中文资源随 PE 编入
- unix 库按 16KB 页对齐，适配 16KB 页设备
- prefix 由包内 wine 自身执行 wineboot 生成，注册表版本与产物一致
- 每个 Release 附 SHA256SUMS.txt

## 补丁

- `patches/winlator-glibc-paths.patch`：路径修正。glibc 环境下 wineserver socket 目录与 NLS 路径指向容器 rootfs，z 盘映射 rootfs。
- `patches/enhanced/`：增强补丁集，逐件独立、可按需取舍（dnsapi 走 libresolv、midimap 音频映射、win32u 剪贴板等），详见 docs/patches.md。

## 构建

GitHub Actions → Build Wine，手动触发：

| 输入 | 说明 |
|---|---|
| versions | 上游 tag `wine-<ver>` 的版本号，逗号分隔批量构建 |
| profile | core：仅路径修正；enhanced：路径修正 + 增强补丁集 |
| publish | 构建成功后发布 Release |
| prerelease | 预发布标记（自动构建、未经真机验证时使用） |

## 发布策略

- tag `wine-<ver>`：已真机验证的稳定版，Latest 置顶
- tag `wine-<ver>-auto`：CI 自动构建的预发布
- Release 正文含：上游源码 tag 与提交链接、上游更新摘要（ANNOUNCE）、本仓库补丁清单、构建与验证状态

## 本地构建

scripts/ 下各脚本可独立运行，参数见脚本头注释：

```
build.sh          编译（源码目录 + 安装前缀）
gen-prefixpack.sh 用包内 wine 生成 prefixPack
package-whp.sh    打 WHIP 包
package-wcp.sh    打 WCP 包
release-notes.sh  生成 Release 正文
```

## 构建原则

- 上游 tag 直编，不引入第三方二进制
- 不为通过编译降级 SDK，不注释报错代码，不删失败用例；源码编译失败直接中断构建
- `--disable-tests` 是包构建的标准配置（测试用例不编入产物），不影响编译期错误检测

## 路线图

- arm64 构建线：llvm-mingw 编 PE + aarch64 unix 库，产出 arm64 容器包
- Proton 构建线：bionic 依赖环境，NTSYNC 用户态库，产出 x86_64 / arm64ec 容器包
- 上游 tag 监听，自动触发预发布构建

## 许可

补丁作用于 Wine 源码，随 Wine 以 LGPL-2.1 释出；仓库脚本以 MIT 释出。
