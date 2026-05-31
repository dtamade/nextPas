# fafafa.ssl 依赖说明

本文档列出 fafafa.ssl 的所有依赖项，包括编译时和运行时依赖。

---

## 🔨 编译依赖

### 必需

| 依赖 | 版本要求 | 说明 |
|------|---------|------|
| **Free Pascal** | ≥ 3.2.0 | Pascal编译器（推荐 3.2.2+） |

### 推荐（可选）

| 依赖 | 版本要求 | 说明 |
|------|---------|------|
| **Lazarus IDE** | ≥ 2.0 | 集成开发环境（可选） |

### 安装编译工具

#### Linux (Ubuntu/Debian)
```bash
# 安装Free Pascal
sudo apt-get update
sudo apt-get install fpc

# 可选：安装Lazarus
sudo apt-get install lazarus
```

#### Linux (Fedora/RHEL)
```bash
# 安装Free Pascal
sudo dnf install fpc

# 可选：安装Lazarus
sudo dnf install lazarus
```

#### macOS
```bash
# 使用Homebrew
brew install fpc

# 或从官网下载
# https://www.freepascal.org/download.html
```

#### Windows
1. 下载安装程序：https://www.freepascal.org/download.html
2. 或下载Lazarus（包含FPC）：https://www.lazarus-ide.org/

---

## 🚀 运行时依赖

### Windows平台

#### 选项A：WinSSL后端（推荐）
**运行时依赖**: ✅ **零依赖！**

```
部署文件：
└── YourApp.exe (约300KB)  ← 仅此一个文件！
```

**优势**：
- ✅ 无需任何DLL文件
- ✅ 使用Windows内置Schannel
- ✅ 自动集成Windows证书存储
- ✅ 自动遵守Windows安全策略
- ✅ Windows Update自动更新

**适用场景**：
- 桌面应用
- 命令行工具
- 企业内部工具
- 需要零依赖部署的场景

#### 选项C：FreePascal后端
**运行时依赖**: ✅ **无外部 SSL 动态库依赖**

```
部署文件：
└── YourApp.exe  (无 OpenSSL DLL)
```

**说明**：
- 适合 Pascal-first / 无外部 SSL 动态库部署
- 不等于 WinSSL：它不自动接入 Windows 系统证书存储或企业策略
- 如果你要 Windows-native 证书存储 / GPO / Schannel 集成，仍优先 WinSSL

#### 选项B：OpenSSL后端

**运行时依赖**：

| 依赖 | 版本 | 下载 |
|------|------|------|
| **OpenSSL** | 3.x 或 1.1.x | 见下方下载地址 |

**部署文件**：
```
YourApp目录：
├── YourApp.exe (约300KB)
├── libcrypto-3-x64.dll (约5MB)  ← OpenSSL加密库
└── libssl-3-x64.dll (约800KB)   ← OpenSSL SSL/TLS库
```

**OpenSSL 3.x下载** (Windows):
- Shining Light Productions: https://slproweb.com/products/Win32OpenSSL.html
- 推荐版本：Win64 OpenSSL v3.4.1 Light

**OpenSSL 1.1.x下载** (Windows):
- 同上网站，选择1.1.1系列
- 注意：1.1.1系列已停止更新（2023年9月）

**安装说明**：
1. 下载安装程序
2. 运行安装（默认路径：`C:\Program Files\OpenSSL-Win64\`）
3. 将DLL文件复制到应用程序目录，或
4. 将OpenSSL的bin目录添加到系统PATH

**适用场景**：
- 需要特定OpenSSL版本
- 需要OpenSSL专有功能
- 跨平台统一后端

---

### Linux平台

#### 选项A：OpenSSL后端（最常见）

**运行时依赖**：

| 依赖 | 版本 | 说明 |
|------|------|------|
| **OpenSSL** | 3.x (推荐) 或 1.1.x | 系统通常已预装 |

#### Ubuntu/Debian
```bash
# OpenSSL 3.x (推荐)
sudo apt-get install libssl3

# 或 OpenSSL 1.1.x
sudo apt-get install libssl1.1

# 检查版本
openssl version
```

#### Fedora/RHEL
```bash
# OpenSSL 3.x
sudo dnf install openssl-libs

# 检查版本
openssl version
```

#### Arch Linux
```bash
# OpenSSL 3.x
sudo pacman -S openssl

# 检查版本
openssl version
```

**说明**：
- Linux系统通常已预装OpenSSL
- 应用程序会自动链接到系统OpenSSL
- 无需手动部署DLL文件

#### 选项B：FreePascal后端（无外部 SSL 动态库）

**运行时依赖**: ✅ **无外部 SSL 动态库依赖**

**说明**：
- 适合 Pascal-first / 自带 TLS core 的部署路径
- 如果你需要 OpenSSL-specific 功能或更完整 capability coverage，仍优先 OpenSSL backend

---

### macOS平台

#### 选项A：OpenSSL后端（最常见）

**运行时依赖**：

| 依赖 | 版本 | 说明 |
|------|------|------|
| **OpenSSL** | 3.x | 系统预装或Homebrew |

```bash
# 使用Homebrew安装
brew install openssl@3

# 检查版本
openssl version

# 设置环境变量（如需要）
export DYLD_LIBRARY_PATH=/usr/local/opt/openssl@3/lib:$DYLD_LIBRARY_PATH
```

**说明**：
- macOS可能预装LibreSSL而非OpenSSL
- 建议使用Homebrew安装OpenSSL 3.x
- 应用程序会自动查找系统OpenSSL库

#### 选项B：FreePascal后端（无外部 SSL 动态库）

**运行时依赖**: ✅ **无外部 SSL 动态库依赖**

**说明**：
- 适合不想额外携带 OpenSSL / Homebrew 依赖的 Pascal-first 场景
- 如果你明确需要 OpenSSL-specific 能力，仍按上面的 OpenSSL 路径准备依赖

---

## 📦 打包和分发

### Windows应用打包建议

#### 最小化部署（WinSSL）
```
MyApp/
└── MyApp.exe  (约300KB)
```

#### OpenSSL部署
```
MyApp/
├── MyApp.exe
├── libcrypto-3-x64.dll
├── libssl-3-x64.dll
└── ca-bundle.crt (可选，用于证书验证)
```

**CA证书包**（可选）：
- 下载：https://curl.se/ca/cacert.pem
- 重命名为 `ca-bundle.crt`
- 放在应用程序目录

### Linux应用打包建议

#### 方式1：动态链接（推荐）
```bash
# 直接编译
fpc -Fusrc MyApp.pas

# 依赖系统OpenSSL
# 用户需要: sudo apt-get install libssl3
```

#### 方式2：静态链接
```bash
# 注意：Free Pascal不支持完全静态链接OpenSSL
# 建议使用动态链接
```

#### 方式3：AppImage打包
```bash
# 将应用和依赖打包为单个文件
# 适用于跨发行版分发
```

#### 方式4：FreePascal backend 最小依赖部署
```bash
# 走 FreePascal backend 时，无需额外准备 OpenSSL 动态库
fpc -Fusrc MyApp.pas
```

### macOS应用打包建议

```bash
# 创建应用包
MyApp.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── MyApp
│   └── Frameworks/  (如需要)
│       ├── libcrypto.3.dylib
│       └── libssl.3.dylib
```

---

## 🔍 版本兼容性

### OpenSSL版本支持

| OpenSSL版本 | 支持状态 | 说明 |
|------------|---------|------|
| **3.4.x** | ✅ 完全支持 | 最新版本，推荐 |
| **3.3.x** | ✅ 完全支持 | 稳定版本 |
| **3.2.x** | ✅ 完全支持 | 稳定版本 |
| **3.1.x** | ✅ 完全支持 | 稳定版本 |
| **3.0.x** | ✅ 完全支持 | LTS版本 |
| **1.1.1** | ✅ 核心功能 | 已EOL，不推荐新项目 |
| **1.1.0** | ⚠️ 未测试 | 不推荐 |
| **1.0.x** | ❌ 不支持 | 过时 |

### WinSSL (Schannel) 版本

| Windows版本 | TLS 1.2 | TLS 1.3 | 状态 |
|------------|---------|---------|------|
| **Windows 11** | ✅ | ✅ | 完全支持 |
| **Windows 10 (>= 18362)** | ✅ | ✅ | 完全支持 |
| **Windows 10 (旧版本)** | ✅ | ❌ | 仅TLS 1.2 |
| **Windows 8.1** | ✅ | ❌ | 仅TLS 1.2 |
| **Windows 7** | ✅ | ❌ | 仅TLS 1.2 |
| **Windows Vista** | ⚠️ | ❌ | 基础支持 |

---

## 🛠️ 开发依赖

### 可选工具（提升开发体验）

| 工具 | 用途 | 安装 |
|------|------|------|
| **Git** | 版本控制 | https://git-scm.com/ |
| **Python 3** | 运行脚本工具 | https://python.org/ |
| **PowerShell** | Windows脚本 | Windows内置 |

### 测试工具

| 工具 | 用途 | 说明 |
|------|------|------|
| **OpenSSL CLI** | 测试和验证 | 通常与OpenSSL一起安装 |
| **curl** | HTTP测试 | 系统包管理器安装 |

---

## 📝 验证依赖

### 快速检查脚本

#### Windows (PowerShell)
```powershell
# 检查FPC
fpc -iV

# 检查OpenSSL（如使用）
Get-Command openssl -ErrorAction SilentlyContinue

# 检查WinSSL可用性
[System.Net.ServicePointManager]::SecurityProtocol
```

#### Linux/macOS (Bash)
```bash
# 检查FPC
fpc -iV

# Linux: 检查OpenSSL
openssl version

# Linux: 检查库文件
ldconfig -p | grep libssl

# macOS: 检查 Homebrew OpenSSL（如使用 OpenSSL backend）
ls /opt/homebrew/opt/openssl@3/lib/libssl*.dylib 2>/dev/null
ls /usr/local/opt/openssl@3/lib/libssl*.dylib 2>/dev/null
```

---

## 🐛 常见问题

### Q: Windows上找不到OpenSSL DLL？
**A**: 
1. 确保DLL在应用程序目录，或
2. 将OpenSSL的bin目录添加到PATH，或
3. 使用WinSSL后端（零依赖）

### Q: Linux上报错找不到libssl.so.3？
**A**: 
```bash
# 安装OpenSSL 3.x
sudo apt-get install libssl3

# 或创建符号链接
sudo ln -s /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/libssl.so.3
```

### Q: 如何切换后端？
**A**: 
```pascal
uses fafafa.ssl;

// Windows上选择WinSSL
Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);

// 或使用OpenSSL
Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);

// 自动选择
Lib := TSSLFactory.GetLibraryInstance(sslAutoDetect);  // 让工厂按当前可用性与优先级选择
```

---

## 📚 更多信息

- 快速入门：`guides/GETTING_STARTED.md`
- API 文档：`reference/API_REFERENCE.md`
- 文档中心：`README.md`
- 示例代码：`examples/`
- 问题报告：https://github.com/dtamade/fafafa.ssl/issues

---

**文档版本**: v1.5.0
**更新日期**: 2026-05-21
