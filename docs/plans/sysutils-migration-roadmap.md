# SysUtils/Classes 迁移路线图

> 目标：nextpas.core 中除桥接层外，所有模块零 SysUtils/Classes/FPC RTL 直接依赖。
> 生成日期：2026-06-18
> 基于：main @ 2207e0e

## 设计原则

- `nextpas.core.system/errors/exception` 是桥接层，保留 SysUtils import（设计选择，非债务）
- 框架内替代物按职责分布：`text.conv`（文本）、`os.env`（环境变量）、`path`（路径）、`fs.util`（文件）、`base.utils`（内存工具）
- `Classes` 依赖通过 `nextpas.core.system.classes`（TStream/TList shim）或框架内接口（IStream）处理
- `DateUtils` 用 `nextpas.core.time` 替代
- `ctypes` 用 `nextpas.core.platform.types` 替代（如适用）

## 稳定词汇表

| FPC 符号 | 框架替代 | 位置 |
|---|---|---|
| `FreeAndNil` | `FreeAndNil` | `base.utils` |
| `IntToStr/UIntToStr` | `IntToStr/UIntToStr` | `text.conv` |
| `Format` | `TextConvFormat` | `text.conv`（deprecated 别名 `Format` 可用） |
| `Trim/LowerCase/UpperCase` | `Trim/LowerCase/UpperCase` | `text.conv` |
| `StringReplace` | `StringReplace` | `text.conv` |
| `TryStrToInt64/StrToInt/StrToIntDef` | 同名 | `text.conv` |
| `GetEnvironmentVariable` | `GetEnvironmentVariable` | `os.env` |
| `ExtractFilePath/FileName/Ext` | 同名 | `path` |
| `ChangeFileExt` | `ChangeFileExt` | `path` |
| `FileExists/DeleteFile/RenameFile` | `FsExists/FsRemoveFile/FsRenameFile` | `fs.util` |
| `FindFirst/FindNext/FindClose` | `FsGlob/FsReadDir`（函数式） | `fs.glob` / `fs.util` |
| `TStream` | `IStream`（接口）或 `system.classes.TStream`（兼容） | `io.intf` / `system.classes` |
| `TStringList` | `TStringBuilder` 或直接数组操作 | `text.*` |
| `TList` | `Vec<T>` 或 `TList` | `system.classes`（兼容） |
| `ParamStr/ParamCount` | `platform_param_str/Count`（需新增） | `platform` |
| `Exception.Create/CreateFmt` | 同名 | `exception` / `errors` |

## 批次

### Batch 1 — 非 TLS 机械替换（7 文件）

纯 import 替换，零代码改动风险。

| 文件 | SysUtils 符号 | 替代 |
|---|---|---|
| `bench.pas` | Trim, GetEnv, TryStrToInt64, LowerCase | `text.conv` + `os.env` |
| `io.stream_adapter.pas` | FreeAndNil + Classes (TStream, TSeekOrigin) | `base.utils` + `system.classes` |
| `mem.allocator.mimalloc.pas` | LowerCase, GetEnv, ExtractFilePath, Exception | `text.conv` + `os.env` + `path` + `errors` |
| `mem.pool.fixed.pas` | FreeAndNil | `base.utils` |
| `platform.error.pas` | （import 存在但未使用） | 移除 import |
| `platform.mmap.pas` | StringReplace | `text.conv` |
| `io.mapped.slab_pool.pas` | FreeAndNil | `base.utils` |
| `font.shaper.pas` | （import 存在但仅用 System builtins） | 移除 import |
| `io.reactor.iocp.pas` | （import 存在但未使用） | 移除 import |

### Batch 2 — TLS 文本/基础符号（~20 文件）

import 替换 + 少量 qualified name 修正。

| 文件 | 主要符号 |
|---|---|
| `tls.capability.serializer` | StringReplace |
| `tls.cert.rotation` | 未确认 |
| `tls.cert.utils` | SysUtils.StringReplace × 4 |
| `tls.freepascal.context` | Base64 + SysUtils |
| `tls.freepascal.earlydatareplay.dirstore` | FindFirst/Next |
| `tls.freepascal.earlydatareplay.fileprovider` | FindFirst/Next |
| `tls.freepascal.earlydatareplay` | DateUtils |
| `tls.freepascal.lib` | 多种 |
| `tls.mbedtls.certificate` | 多种 |
| `tls.mbedtls.context` | Base64 + SysUtils |
| `tls.openssl.certificate` | 多种 |
| `tls.openssl.certstore` | SysUtils.StringReplace × 6 |
| `tls.openssl.connection` | 多种 + ctypes |
| `tls.openssl.context` | 多种 |
| `tls.openssl.loader` | 多种 |
| `tls.pkcs11.backend` | 多种 |
| `tls.random` | 多种 |
| `tls.session.cache` | 多种 |
| `tls.winssl.certificate` | Windows + SysUtils |
| `tls.winssl.context` | Windows + SysUtils |
| `tls.wolfssl.certificate` | 多种 |
| `tls.wolfssl.context` | Base64 + SysUtils |

### Batch 3 — FindFirst 迁移（7 TLS 文件）

需重构为 FsGlob/FsReadDir 函数式循环。

### Batch 4 — ParamStr 基础设施（2 文件）

新增 `platform_param_str`/`platform_param_count` → `nextpas.core.platform`。
影响：`mem.allocator.mimalloc` + `git.libgit2.backend`。

### Batch 5 — Git 模块（1 文件）

`git.libgit2.backend` — 依赖 SysUtils(Format,Trim) + DateUtils + ctypes。
属于 L2，复杂度最高，最后处理。

### 保留层（不动）

| 文件 | 原因 |
|---|---|
| `nextpas.core.path.pas` | 提供 SysUtils 兼容 API，注释引用（非 import） |
| `nextpas.core.errors.pas` | 桥接层 |
| `nextpas.core.exception.pas` | 桥接层 |
| `nextpas.core.system.sysutils.pas` | 桥接层 |

## 执行顺序

**Batch 1 → Batch 4 → Batch 2 → Batch 3 → Batch 5**

理由：Batch 1 验证框架替代物可用性 → Batch 4 解锁 ParamStr → Batch 2 批量推进 → Batch 3 需重构 → Batch 5 最复杂
