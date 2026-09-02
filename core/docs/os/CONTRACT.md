# nextpas.core.os 代码契约

**模块路径**：`core/src/nextpas.core.os.env.pas`、`core/src/nextpas.core.os.procinfo.pas`
**层级**：L2（依赖 L0: base, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 环境变量 API

```pascal
function EnvironmentVariables: TStringArray;
function GetEnvironmentVariable(const AName: string): string;
function GetEnv(const AName: string): string; inline;
function TryGetEnv(const AName: string; out AValue: string): Boolean;
function HasEnv(const AName: string): Boolean;
function EnvironmentVariableNamesCaseSensitive: Boolean; inline;
procedure SetEnv(const AName, AValue: string);
procedure UnsetEnv(const AName: string);
function ExpandEnv(const AValue: string): string;
procedure ValidateEnvName(const AName: string);
```

| 函数 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `EnvironmentVariables` | 无 | 返回所有环境变量名 | 不抛异常 |
| `GetEnv(AName)` | AName 非空 | 返回值，不存在返回空串 | 不抛异常 |
| `TryGetEnv(AName, AValue)` | AName 非空 | 存在返回 True+值，否则 False | 不抛异常 |
| `HasEnv(AName)` | AName 非空 | 存在返回 True | 不抛异常 |
| `SetEnv(AName, AValue)` | AName 非空 | 设置环境变量 | EOsError |
| `UnsetEnv(AName)` | AName 非空 | 删除环境变量 | EOsError |
| `ExpandEnv(AValue)` | 无 | 展开 `$VAR` / `${VAR}` 引用 | 不抛异常 |
| `ValidateEnvName(AName)` | 无 | 验证环境变量名合法性 | EOsError |

---

## 2. 不变量

- 环境变量名在 Linux 上区分大小写，在 Windows 上不区分
- `GetEnv` 返回空串表示不存在（无法区分值为空串的情况）
- `TryGetEnv` 可区分不存在和空值

---

## 3. 错误处理

- `SetEnv`/`UnsetEnv` 失败抛 `EOsError`
- `ValidateEnvName` 名称非法抛 `EOsError`
- 读取函数不抛异常

---

## 4. 线程安全

- 环境变量操作依赖 POSIX `getenv`/`setenv`，非线程安全
- 调用方应自行同步

---

## 5. 内存管理

- 返回的 `TStringArray` 由调用方负责释放
- 所有字符串使用标准 Pascal 引用计数

---

## 6. 测试覆盖

- `test_os_env`: 10 测试，覆盖 Get/Set/Unset/Expand/Validate

---

## 7. 进程信息 API（nextpas.core.os.procinfo）

```pascal
const cProcessMemUnknown = Int64(-1);
function ProcessRssBytes: Int64;
function ProcessPeakRssBytes: Int64;
```

| 函数 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `ProcessRssBytes` | 无 | 当前进程常驻集（字节）；不可用返回 `cProcessMemUnknown` | 不抛异常 |
| `ProcessPeakRssBytes` | 无 | 常驻集峰值（字节，Linux VmHWM）；不可用返回哨兵 | 不抛异常 |

**平台支持面**：Linux 读 `/proc/self/status`（`VmRSS` / `VmHWM`，内核稳定 ABI，
kB→字节换算）；其他平台返回哨兵值（Windows GetProcessMemoryInfo /
macOS mach_task_basic_info 为规划后端位）。哨兵语义 = 调用方降级跳过预算断言，
不把诊断查询变成故障点。

**测试覆盖**：`test_os_procinfo`: 5 测试（源码 RTL 扫描 ×2、RSS 可读、峰值≥当前、
触碰 8MB 后 RSS 增长口径验证）。

---
