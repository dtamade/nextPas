# nextpas.core.os.env

环境变量操作模块。

## 模块定位

- **层级**: L2 facade
- **职责**: 环境变量的读写、查询、展开
- **平台抽象**: 委托给 `nextpas.core.platform.env`

## API 入口

### 读取

| 函数 | 说明 |
|------|------|
| `GetEnv(AName)` | 获取环境变量值，不存在返回空字符串 |
| `GetEnvDefault(AName, ADefault)` | 获取环境变量值，不存在返回默认值 |
| `TryGetEnv(AName, AValue)` | 尝试获取，返回是否成功 |
| `HasEnv(AName)` | 检查环境变量是否存在 |
| `EnvironmentVariables` | 返回所有环境变量的 `TStringArray`（格式 `NAME=VALUE`） |
| `EnvKeys` | 返回所有环境变量名的 `TStringArray` |
| `EnvironmentVariableNamesCaseSensitive` | 平台是否区分大小写（Unix true, Windows false） |

### 便利目录

| 函数 | 说明 |
|------|------|
| `UserHomeDir` | 用户主目录（Unix: `$HOME`, Windows: `%USERPROFILE%`） |
| `UserCacheDir([AppName])` | 缓存目录（Unix: `$XDG_CACHE_HOME` 或 `$HOME/.cache`；Windows: `%LOCALAPPDATA%`） |
| `UserConfigDir([AppName])` | 配置目录（Unix: `$XDG_CONFIG_HOME` 或 `$HOME/.config`；Windows: `%APPDATA%`） |
| `UserDataDir([AppName])` | 数据目录（Unix: `$XDG_DATA_HOME` 或 `$HOME/.local/share`；Windows: `%LOCALAPPDATA%`） |

**Windows 说明**：`UserCacheDir` 与 `UserDataDir` **同根** `%LOCALAPPDATA%`（常见映射）。区分方式：不同 `AppName`，或由调用方在返回路径下再拼 `cache`/`data` 子目录。Unix 上 Cache/Config/Data 根路径不同。

### 写入

| 函数 | 说明 |
|------|------|
| `SetEnv(AName, AValue)` | 设置环境变量 |
| `UnsetEnv(AName)` | 删除环境变量 |

### 展开

| 函数 | 说明 |
|------|------|
| `ExpandEnv(AValue)` | 展开 `${VAR}`、`$VAR` 与 `%VAR%`（未定义→空） |
| `ExpandEnvWithDefault(AValue, ADefault)` | 展开（未定义→默认值） |
| `ExpandEnvStrict(AValue)` | 展开（未定义→抛异常） |

## 使用示例

```pascal
uses
  nextpas.core.os.env;

var
  LHome: string;
  LExpanded: string;
begin
  { 读取 }
  LHome := GetEnv('HOME');
  WriteLn('Home: ', LHome);

  { 带默认值 }
  if not TryGetEnv('MY_APP_PORT', LPort) then
    LPort := '8080';

  { 设置 }
  SetEnv('MY_VAR', 'hello');

  { 展开 }
  LExpanded := ExpandEnv('${HOME}/config');
  // → /home/user/config

  LExpanded := ExpandEnv('$HOME/config');
  // → /home/user/config

  LExpanded := ExpandEnv('$MY_VAR.txt');
  // → hello.txt（.txt 不是变量名字符）
end;
```

## 展开语法

| 语法 | 说明 | 示例 |
|------|------|------|
| `${VAR}` | 首选语法，无歧义 | `${HOME}` |
| `$VAR` | 简写，变量名边界为 `[A-Za-z0-9_]` | `$HOME` |
| `%VAR%` | Windows 风格，变量名 `[A-Za-z0-9_]` | `%PATH%` |

- 变量名边界：`$VAR.txt` → 展开 `$VAR` + `.txt`
- 未定义变量 → 空字符串
- `$` 后无变量名字符 → 保留原样 `$`
- 未终止的 `${...}` → 抛 `EArgumentError`
- 不完整 `%`（如 `100%`、`a%b`）→ 保留字面量
- 空值 vs 未定义：`HasEnv`/`TryGetEnv` 可区分；`GetEnv` 两者都返回 `''`

## 线程安全

**不线程安全**（与 C 标准库 `getenv`/`setenv` 一致）。多线程环境下调用方需自行加锁。

## 测试

```bash
make -C core/tests/nextpas.core.os.env/test_os_env clean test
```
