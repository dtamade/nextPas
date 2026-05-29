# FCL依赖说明

## 概述

`fafafa.ssl` 项目使用了部分Free Pascal Component Library (FCL)单元，主要用于Base64编码和JSON处理。本文档说明这些依赖及其配置方法。

## 必需的FCL单元

### 1. fcl-base

**用途**: Base64编码/解码

**使用模块**:

- `fafafa.ssl.log.pas` - 日志输出中的二进制数据编码
- `fafafa.ssl.utils.pas` - 工具函数中的Base64处理

**依赖单元**:

- `base64` - Base64编码/解码函数

### 2. fcl-json

**用途**: JSON数据处理

**使用模块**:

- `fafafa.ssl.log.pas` - 结构化日志输出

**依赖单元**:

- `fpjson` - JSON数据结构
- `jsonparser` - JSON解析器

### 3. rtl-objpas

**用途**: Object Pascal扩展

**使用模块**:

- 大部分模块（提供`variants`等标准类型）

**依赖单元**:

- `variants` - Variant类型支持

## Linux环境配置

### Ubuntu/Debian

```bash
# 安装FPC及FCL包
sudo apt-get update
sudo apt-get install -y fpc fp-units-fcl

# 验证安装
fpc -iV  # 查看FPC版本
ls /usr/lib/fpc/$(fpc -iV)/fcl-base/  # 确认fcl-base
ls /usr/lib/fpc/$(fpc -iV)/fcl-json/  # 确认fcl-json
```

### Fedora/RHEL

```bash
# 安装FPC
sudo dnf install fpc

# FCL通常随FPC一起安装
rpm -ql fpc | grep fcl
```

### Arch Linux

```bash
# 安装FPC
sudo pacman -S fpc

# FCL已包含在fpc包中
```

### 手动安装FPC

如果使用手动编译的FPC，单元路径通常为：

```
$HOME/freePascal/fpc/units/x86_64-linux/
├── rtl-objpas/
├── fcl-base/
└── fcl-json/
```

## 编译器配置

### 方法1: 命令行指定路径

```bash
fpc \
  -Fu$HOME/freePascal/fpc/units/x86_64-linux/rtl-objpas \
  -Fu$HOME/freePascal/fpc/units/x86_64-linux/fcl-base \
  -Fu$HOME/freePascal/fpc/units/x86_64-linux/fcl-json \
  -Fusrc \
  your_program.pas
```

### 方法2: 使用fpc.cfg配置文件

创建或编辑 `~/.fpc.cfg`:

```
# FCL单元路径
-Fu$HOME/freePascal/fpc/units/$FPCTARGET/rtl-objpas
-Fu$HOME/freePascal/fpc/units/$FPCTARGET/fcl-base
-Fu$HOME/freePascal/fpc/units/$FPCTARGET/fcl-json

# 或使用系统路径
-Fu/usr/lib/fpc/$FPCVERSION/rtl-objpas
-Fu/usr/lib/fpc/$FPCVERSION/fcl-base
-Fu/usr/lib/fpc/$FPCVERSION/fcl-json
```

### 方法3: Lazarus项目配置

在 `fafafa_ssl.lpk` 中已配置：

```xml
<RequiredPkgs Count="1">
  <Item>
    <PackageName Value="FCL"/>
  </Item>
</RequiredPkgs>
```

Lazarus会自动找到FCL路径。

## 当前默认验证链路

如果你是在当前工作树里确认 FCL 相关依赖是否齐全，优先跑当前验证链路，而不是回到历史 `build_linux.sh` / `run_tests_linux.sh`：

```bash
# 编译门禁：验证核心模块在当前环境可编译
python3 scripts/compile_all_modules.py

# 本地最小门禁：compile + P2 核心模块 + Phase 2 入口 dry-run
bash scripts/run_minimal_ci_gate.sh --fast-local

# 可选：只检查 Phase 2 基准入口是否仍可执行
bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local
```

历史 `build_linux.sh` 仍可作为兼容入口保留，但不再是默认文档路径。

## 常见问题

### Q: 编译时报 "Can't find unit base64"

**A**: FCL未安装或路径配置错误

```bash
# Ubuntu/Debian解决方案
sudo apt-get install fp-units-fcl

# 验证
ls /usr/lib/fpc/$(fpc -iV)/fcl-base/base64.ppu
```

### Q: 我不想依赖FCL，可以移除吗？

**A**: 可以，但需要替换功能

- `base64`: 实现自定义Base64编解码（约100行代码）
- `fpjson`: 移除JSON日志功能，使用纯文本日志

### Q: Windows环境如何配置？

**A**: Windows使用不同路径

```
C:\lazarus\fpc\3.3.1\units\x86_64-win64\
├── rtl-objpas\
├── fcl-base\
└── fcl-json\
```

在Lazarus IDE中通过 `fafafa_ssl.lpk` 自动配置。

## 依赖最小化策略

为减少外部依赖，项目已移除：

- ❌ `DateUtils` - 使用RTL的`SysUtils.Now`等替代
- ❌ `SyncObjs` - 使用RTL的`TRTLCriticalSection`替代
- ❌ `StrUtils` - 实现自定义`PosEx`等工具函数

**保留的依赖**:

- ✅ `base64` - 标准功能，实现复杂度高
- ✅ `fpjson` - 仅用于日志，可选功能

## 版本兼容性

| FPC版本 | fcl-base | fcl-json | 状态    |
| ------- | -------- | -------- | ------- |
| 3.2.0   | ✓        | ✓        | ✅ 支持 |
| 3.2.2   | ✓        | ✓        | ✅ 支持 |
| 3.3.1   | ✓        | ✓        | ✅ 推荐 |

## 进一步参考

- [Free Pascal FCL文档](https://www.freepascal.org/docs-html/fcl/)
- [FCL源代码](https://gitlab.com/freepascal.org/fpc/source/-/tree/main/packages)
- [项目编译指南](../README.md#系统要求)

---

**更新日期**: 2025-10-28  
**适用版本**: fafafa.ssl v1.0.0-rc
