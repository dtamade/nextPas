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
| `TryGetEnv(AName, AValue)` | 尝试获取，返回是否成功 |
| `HasEnv(AName)` | 检查环境变量是否存在 |
| `EnvironmentVariables` | 返回所有环境变量的 `TStringArray` |
| `EnvironmentVariableNamesCaseSensitive` | 平台是否区分大小写（Unix true, Windows false） |

### 写入

| 函数 | 说明 |
|------|------|
| `SetEnv(AName, AValue)` | 设置环境变量 |
| `UnsetEnv(AName)` | 删除环境变量 |

### 展开

| 函数 | 说明 |
|------|------|
| `ExpandEnv(AValue)` | 展开 `${VAR}` 和 `$VAR` 占位符 |

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

- 变量名边界：`$VAR.txt` → 展开 `$VAR` + `.txt`
- 未定义变量 → 空字符串
- `$` 后无变量名字符 → 保留原样 `$`
- 未终止的 `${...}` → 抛 `EArgumentError`

## 线程安全

**不线程安全**（与 C 标准库 `getenv`/`setenv` 一致）。多线程环境下调用方需自行加锁。

## 测试

```bash
make -C core/tests/nextpas.core.os.env/test_os_env clean test
```
