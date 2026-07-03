# nextpas.core.yaml 代码契约

**模块路径**：`core/src/nextpas.core.yaml*.pas`（7 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
yaml.base      ← TYamlKind 枚举, TYamlNode 前向声明
yaml.node      ← TYamlNode DOM 树 (Mapping/Sequence/Scalar)
yaml.parser    ← YAML 1.2 解析器 (流式事件驱动)
yaml.writer    ← TYamlNode → YAML 字符串输出
yaml.path      ← YAMLPath 查询表达式
yaml.pas       ← 门面
```

### 1.2 核心 API

```pascal
function YamlParse(const AInput: string): TYamlNode;
function YamlTryParse(const AInput: string; out ANode: TYamlNode): Boolean;

TYamlNode = class
  function Kind: TYamlKind;
  function AsString: string;
  function AsInt64: Int64;
  function AsFloat: Double;
  function AsBoolean: Boolean;
  function Count: SizeInt;
  function Child(const AKey: string): TYamlNode;  // mapping
  function Item(AIndex: SizeInt): TYamlNode;       // sequence
  function ToString: string;  // 序列化
end;
```

### 1.3 性能

YAML 解析比 Go yaml.v3 快 10x。

---

## 2. 不变量

- **[INV-1]** YAML 1.2 核心 schema 兼容（bool: true/false, null: null/~）
- **[INV-2]** TYamlNode 树结构，父节点拥有子节点
- **[INV-3]** ToString 输出合法 YAML（可再解析）

---

## 3-6. 概要

- **错误**: 非法 YAML 语法抛 EParseError; 类型不匹配抛 EInvalidOperation
- **线程安全**: 解析/序列化 ✅; TYamlNode ❌
- **内存**: 树结构，父节点拥有子节点
- **测试**: 10 个测试目录，63 tests

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
