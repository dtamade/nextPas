# nextpas.core.config 代码契约

> 模块路径: `core/src/nextpas.core.config.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

配置管理模块。支持多源加载（INI/JSON/YAML/TOML/环境变量），类型安全读取，
分层覆盖（后加载覆盖先加载）。零 SysUtils 依赖。

---

## 关键接口

```pascal
type
  TConfigFormat = (cfIni, cfJson, cfYaml, cfToml);
  IConfig = interface
    function GetString(AKey: string; ADefault: string = ''): string;
    function GetInt(AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(AKey: string; ADefault: Double = 0.0): Double;
    function GetStringRequired(AKey: string): string;
    function GetStringArray(AKey: string): TStringArray;
    function HasKey(AKey: string): Boolean;
  end;

function Config: IConfig;
procedure ConfigLoad(APath: string; AFormat: TConfigFormat);
procedure ConfigLoadEnv;
```

---

## 前置条件

1. AKey 使用点分隔路径（如 `server.port`）
2. ConfigLoad: 文件存在且格式正确

---

## 后置条件

1. GetString: 返回配置值或默认值
2. GetStringRequired: 值不存在时 raise EConfigError
3. 分层覆盖: 后加载的源覆盖先加载的同名键

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 键不存在 + Required | raise EConfigError |
| 格式解析失败 | raise EParseError |

---

## 线程安全

- IConfig 读取线程安全（threadvar 缓存）
- ConfigLoad 不线程安全（需在启动阶段调用）

---

## 依赖关系

- 依赖: text, ini, json, os.env, platform.watch, sync
- 被依赖: 应用层配置

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
