# wine-proton-builder

Winlator 通用 Wine/Proton 源码编译仓库。

## 特性

- **双架构**：x86_64 (glibc/mingw) + arm64ec (bionic/NDK+llvm-mingw)
- **原生汉化**：gettext NLS 全语言（51种）嵌入 PE 资源，非二进制硬改
- **双格式输出**：`.wcp` (ludashi/bionic) + `.whp` (winlator-pulse)
- **prefixPack 融合生成**：wineboot 真实初始化 + 中文注册表配置 + 中文字体注入
- **闭源包二次加工**：解包已有 wcp/whp → 替换汉化资源 → 重打包
- **参数化构建**：手动触发选择版本/架构/构建类型，支持任意 Wine/Proton 版本

## 仓库结构

```
├── .github/workflows/
│   ├── build-wine.yml           # 纯 Wine 编译（参数化版本/架构）
│   ├── build-proton.yml         # Proton 编译（nicholasx417 版本）
│   └── repackage-closed.yml     # 闭源包二次加工
├── scripts/
│   ├── build-native-tools.sh    # 阶段0：编译 native tools + NLS
│   ├── build-cross-x86_64.sh    # 阶段1：x86_64 交叉编译
│   ├── build-cross-arm64ec.sh   # 阶段1：arm64ec 交叉编译
│   ├── gen-prefixpack.sh        # prefixPack 生成（wineboot + 中文配置）
│   ├── package-wcp.sh           # wcp 打包
│   ├── package-whp.sh           # whp 打包
│   └── repackage.sh             # 闭源包解包→汉化→重打包
├── patches/
│   ├── localization/            # 汉化补丁（po 修正等）
│   └── compatibility/           # 兼容性补丁（termux 路径等）
├── prefix/
│   └── chinese-reg.patch        # 中文注册表补丁
└── docs/
    ├── architecture.md          # 编译架构说明
    └── packaging.md             # wcp/whp 格式说明
```

## 编译架构

### 分阶段编译（确保 NLS 正确嵌入 PE）

```
阶段0: 宿主编译器(gcc) → native Wine tools (wrc/winebuild) + NLS (.mo)
阶段1: mingw/llvm-mingw 交叉编译 → PE (dll/exe)，--with-wine-tools 指向阶段0
```

关键：wrc 在编译 PE 资源时加载 `po/<lang>.mo`，将翻译嵌入 PE 资源段。
直接全量 mingw 编译会导致 wrc 无法正确加载翻译。

### 双架构差异

| 维度 | x86_64 | arm64ec |
|------|--------|---------|
| 目标 | x86_64-w64-mingw32 | aarch64-linux-android28 (bionic) |
| 工具链 | mingw-w64 | NDK clang + bylaws/llvm-mingw(ucrt) |
| 环境 | 原生 | termuxfs (bionic 依赖) |
| strip | mingw-strip | llvm-strip (COFF+ELF 双支持) |

## 使用

### 编译 Wine

1. Actions → Build Wine → Run workflow
2. 选择版本（如 `10.17`）、架构（x86_64/arm64ec/both）
3. 等待编译完成，下载 Artifact

### 编译 Proton

1. Actions → Build Proton → Run workflow
2. 选择 nicholasx417 版本（9.0/10.0/11.0）、架构
3. 下载 Artifact

### 闭源包二次加工

1. Actions → Repackage Closed → Run workflow
2. 上传已有 wcp/whp 包
3. 自动解包 → 替换汉化资源 → 重打包

## 参考项目

- [as14725836/proton-wine](https://github.com/as14725836/proton-wine) — arm64ec bionic 编译权威参考
- [as14725836/termux-glibc-mangohud](https://github.com/as14725836/termux-glibc-mangohud) — 分阶段编译 + 补丁库
- [Waim908/wine-winlator](https://github.com/Waim908/wine-winlator) — wcp/whp 打包结构权威
- [kaldin54321-boop/Wine-for-winlator-official](https://github.com/kaldin54321-boop/Wine-for-winlator-official) — 参数化 workflow 设计

## 许可

Wine 源码遵循 LGPL-2.1，本仓库编译脚本遵循 MIT。
