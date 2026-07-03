# nextpas.core.config 代码契约

**模块路径**：`core/src/nextpas.core.config*.pas`（6 个源文件）
**层级**：L3（依赖 L0-L2: json, yaml, toml）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
config.base        ← TConfigFormat 枚举, IConfig 接口
config.loader      ← 多格式加载器 (JSON/YAML/TOML)
config.env         ← 环境变量覆盖
config.cli         ← 命令行参数覆盖
config.pas         ← 门面
```

### 1.2 核心接口

```pascal
IConfig = interface
  function GetString(const APath: string): string;
  function GetInt(const APath: string): Int64;
  function GetBool(const APath: string): Boolean;
  function GetFloat(const APath: string): Double;
  function Has(const APath: string): Boolean;
end;
```

### 1.3 加载优先级

CLI args > Environment variables > Config file > Defaults

---

## 2. 不变量

- **[INV-1]** 配置路径用 `.` 分隔（如 `server.port`）
- **[INV-2]** 类型不匹配抛 EConfigError
- **[INV-3]** 多格式统一 DOM 模型

---

## 3-6. 概要

- **错误**: EConfigError（类型不匹配/路径不存在/格式错误）
- **线程安全**: IConfig 读操作 ✅; 加载过程 ❌
- **内存**: DOM 递归展平, IAllocator 集成
- **测试**: 12 个测试目录, 55 tests

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
