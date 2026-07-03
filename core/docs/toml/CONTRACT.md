# nextpas.core.toml 代码契约

**模块路径**：`core/src/nextpas.core.toml*.pas`（6 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
toml.base      ← TTomlKind 枚举, TomlNode 前向声明
toml.node      ← TTomlNode DOM 树 (Table/Array/String/Integer/Float/Boolean/DateTime)
toml.parser    ← TOML v1.0/v1.1 解析器
toml.writer    ← TTomlNode → TOML 字符串输出
toml.pas       ← 门面
```

### 1.2 核心 API

```pascal
function TomlParse(const AInput: string): TTomlNode;
function TomlTryParse(const AInput: string; out ANode: TTomlNode): Boolean;

TTomlNode = class
  function Kind: TTomlKind;
  function AsString: string;
  function AsInt64: Int64;
  function AsFloat: Double;
  function AsBoolean: Boolean;
  function Count: SizeInt;
  function Child(const AKey: string): TTomlNode;
  function Item(AIndex: SizeInt): TTomlNode;
  function ToString: string;
end;
```

### 1.3 性能

TOML 解析比 Rust toml crate 快 6-8x。277 tests。

---

## 2. 不变量

- **[INV-1]** TOML v1.0 + v1.1 兼容
- **[INV-2]** DateTime 支持 offset-date-time, local-date-time, local-date, local-time
- **[INV-3]** ToString 输出合法 TOML（可再解析）

---

## 3-6. 概要

- **错误**: 非法 TOML 语法抛 EParseError; 类型不匹配抛 EInvalidOperation
- **线程安全**: 解析/序列化 ✅; TTomlNode ❌
- **内存**: 树结构，父节点拥有子节点
- **测试**: 13 个测试目录，277 tests

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
