# nextpas.core.os.env — 环境变量模块

## 概述

`nextpas.core.os.env` 提供跨平台的环境变量操作 API，支持：
- 读取/设置/删除环境变量
- 环境变量展开（`$VAR` 和 `${VAR}` 语法）
- 三种展开模式：宽松、带默认值、严格
- 用户目录查询（Home/Cache/Config）

## 快速开始

```pascal
uses nextpas.core.os.env;

// 读取环境变量
LValue := GetEnv('HOME');
LValue := GetEnvDefault('MY_VAR', 'default');

// 区分"未定义"和"定义为空"
if TryGetEnv('MY_VAR', LValue) then
  // MY_VAR 已定义，LValue 可能为空字符串
else
  // MY_VAR 未定义

// 设置环境变量
SetEnv('MY_VAR', 'value');

// 环境变量展开
LPath := ExpandEnv('$HOME/.config');           // 宽松：未定义返回空
LPath := ExpandEnvWithDefault('$HOME/.config', '/tmp');  // 带默认值
LPath := ExpandEnvStrict('$HOME/.config');     // 严格：未定义抛异常

// ${VAR} 语法（支持变量名后紧跟其他字符）
LPath := ExpandEnv('${HOME}/.config');
LPath := ExpandEnv('${VAR}_suffix');

// 用户目录
LHome := UserHomeDir();
LCache := UserCacheDir('myapp');
LConfig := UserConfigDir('myapp');

// 列出所有环境变量名
LKeys := EnvKeys;
```

## API 参考

### 读取

| 函数 | 说明 |
|------|------|
| `GetEnv(AName): string` | 获取环境变量值，未定义返回空字符串 |
| `GetEnvDefault(AName, ADefault): string` | 获取环境变量值，未定义返回默认值 |
| `TryGetEnv(AName, out AValue): Boolean` | 尝试获取，区分未定义和空值 |
| `HasEnv(AName): Boolean` | 检查环境变量是否存在 |
| `EnvKeys: TStringArray` | 获取所有环境变量名 |

### 修改

| 函数 | 说明 |
|------|------|
| `SetEnv(AName, AValue)` | 设置环境变量 |
| `UnsetEnv(AName)` | 删除环境变量 |

### 展开

| 函数 | 说明 |
|------|------|
| `ExpandEnv(AValue): string` | 宽松展开：未定义变量替换为空字符串 |
| `ExpandEnvWithDefault(AValue, ADefault): string` | 带默认值展开：未定义变量替换为默认值 |
| `ExpandEnvStrict(AValue): string` | 严格展开：未定义变量抛 `EArgumentError` |

### 用户目录

| 函数 | 说明 |
|------|------|
| `UserHomeDir(): string` | 获取用户主目录 |
| `UserCacheDir(AppName): string` | 获取用户缓存目录 |
| `UserConfigDir(AppName): string` | 获取用户配置目录 |

## 展开语法

支持两种变量引用语法：

- `$VAR` — 简单形式，变量名由字母、数字、下划线组成
- `${VAR}` — 花括号形式，变量名后可紧跟其他字符

```pascal
ExpandEnv('$HOME/.config');        // → /home/user/.config
ExpandEnv('${HOME}_backup');       // → /home/user_backup
ExpandEnv('$HOME-$USER');          // → /home/user- (USER 未定义)
ExpandEnv('${HOME}-${USER}');      // → /home/user-
```

## 空值语义

`TryGetEnv` 正确区分"未定义"和"定义为空"：

```pascal
SetEnv('EMPTY_VAR', '');

GetEnv('EMPTY_VAR');                    // → '' (无法区分)
GetEnvDefault('EMPTY_VAR', 'default');  // → '' (空值不替换)
TryGetEnv('EMPTY_VAR', V);             // → True, V = ''

GetEnv('UNDEFINED_VAR');                // → '' (无法区分)
GetEnvDefault('UNDEFINED_VAR', 'default');  // → 'default'
TryGetEnv('UNDEFINED_VAR', V);         // → False
```

## 错误处理

| 异常 | 触发条件 |
|------|---------|
| `EArgumentError` | 变量名为空或包含 `=` |
| `EArgumentError` | `ExpandEnvStrict` 遇到未定义变量 |
| `EEnvironmentError` | 系统调用失败（权限不足等） |
| `EArgumentError` | `${...}` 未闭合 |

## 测试

```bash
make -C core/tests/nextpas.core.os.env/test_os_env clean test
```

测试覆盖：GetEnv/SetEnv/UnsetEnv/TryGetEnv/HasEnv/EnvKeys/ExpandEnv/ExpandEnvWithDefault/ExpandEnvStrict/UserHomeDir/UserCacheDir/UserConfigDir
