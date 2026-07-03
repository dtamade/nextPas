# nextpas.core.os 代码契约

**模块路径**：`core/src/nextpas.core.os.env.pas`（1 个源文件）
**层级**：L2（依赖 L0: base, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

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
