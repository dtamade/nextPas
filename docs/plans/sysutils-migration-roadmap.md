# SysUtils/Classes 迁移路线图

> 目标：nextpas.core 中除桥接层外，所有模块零 SysUtils/Classes/FPC RTL 直接依赖。
> 生成日期：2026-06-18
> 状态：**已完成** ✅

## 设计原则

- `nextpas.core.system/errors/exception/system.sysutils/system.classes` 是桥接层，保留 SysUtils import（设计选择，非债务）
- 框架内替代物按职责分布：`text.conv`（文本）、`os.env`（环境变量）、`path`（路径）、`fs.util`（文件）、`base.utils`（内存工具）
- `DateUtils` 用 `nextpas.core.time` 替代
- `ctypes` 用 `nextpas.core.base`（C ABI 类型别名）替代

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
| `ParamStr/ParamCount` | `platform_param_str/Count` | `platform` |
| `Exception.Create/CreateFmt` | 同名 | `exception` / `errors` |
| `Now` | `DateTimeNow` | `time` |
| `DateTimeToUnix/UnixToDateTime` | 同名 | `time` |
| `DaysBetween` | 同名 | `time` |
| `FormatDateTime` | 同名 | `time`（POSIX 格式 `%Y-%m-%d`） |

## 执行批次（全部完成）

### Batch 1 — 非 TLS 机械替换 ✅ (commit 8e55d457c, 9 files)

纯 import 替换，零代码改动风险。

### Batch 2 — TLS 简单迁移 + DaysBetween + FindFirst ✅ (commit 3bf25e9dd, 34 files)

- Group A: 18 个 TLS 文件 SysUtils 移除
- Group B: 2 个 DaysBetween 文件
- Group C: 7 个 FindFirst→FsGlob 重构
- 新增 `DaysBetween` 独立函数 + 测试

### Batch 3 — TLS/Simd 残留清理 ✅ (commits 0a522429d + 307d5adc0, 11 files)

- 移除未使用的 DateUtils（5 文件）
- ctypes → nextpas.core.base（6 文件）
- winssl.connection: Now→DateTimeNow, FormatDateTime→POSIX

### Batch 4 — FindFirst 迁移 — 合并入 Batch 2

### Batch 5 — Git backend ✅ (commit 50085c145, 2 files)

- `git.libgit2.ffi.pas`: ctypes → nextpas.core.base
- `git.libgit2.backend.pas`: SysUtils+DateUtils+ctypes → base+text.conv+time

## 迁移结果

**core/src 中 FPC RTL 引用：SysUtils=0, DateUtils=0, ctypes=0**

合规保留层（允许引用 FPC RTL 的 foundation 模块）：

| 文件 | 原因 |
|---|---|
| `nextpas.core.path.pas` | 提供 SysUtils 兼容 API，注释引用（非 import） |
| `nextpas.core.errors.pas` | 桥接层 |
| `nextpas.core.exception.pas` | 桥接层 |
| `nextpas.core.system.sysutils.pas` | 桥接层 |
| `nextpas.core.system.classes.pas` | fmShare 常量来源 |
