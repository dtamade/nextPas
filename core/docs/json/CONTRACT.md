# nextpas.core.json 代码契约

**模块路径**：`core/src/nextpas.core.json*.pas`（9 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
json.base      ← TJsonKind 枚举, TJsonNode 前向声明
json.node      ← TJsonNode DOM 树 (Object/Array/String/Number/Boolean/Null)
json.parser    ← 流式解析器 (UTF-8 输入 → TJsonNode)
json.writer    ← TJsonNode → JSON 字符串输出
json.builder   ← 流式构建 API
json.pointer   ← JSON Pointer (RFC 6901)
json.patch     ← JSON Patch (RFC 6902)
json.schema    ← JSON Schema 验证 (子集)
json.pas       ← 门面
```

### 1.2 核心 API

```pascal
// 解析
function JsonParse(const AInput: string): TJsonNode;
function JsonTryParse(const AInput: string; out ANode: TJsonNode): Boolean;

// 构建
function JsonNew: TJsonNode;  // null
function JsonNewObject: TJsonNode;
function JsonNewArray: TJsonNode;

// DOM 操作
TJsonNode = class
  function Kind: TJsonKind;
  function AsString: string;
  function AsInt64: Int64;
  function AsFloat: Double;
  function AsBoolean: Boolean;
  function Count: SizeInt;
  function Child(const AKey: string): TJsonNode;  // object
  function Item(AIndex: SizeInt): TJsonNode;       // array
  procedure SetKeyValue(const AKey: string; AValue: TJsonNode);
  procedure Add(AValue: TJsonNode);
  function ToString: string;  // 序列化
end;
```

### 1.3 JSON Pointer / Patch

- `JsonPointer(ANode, '/foo/0/bar')`: RFC 6901 路径查询
- `JsonPatch(ADoc, APatch)`: RFC 6902 补丁应用 (add/remove/replace/move/copy/test)

---

## 2. 不变量

- **[INV-1]** TJsonNode 为树结构，父节点拥有子节点
- **[INV-2]** JsonParse 失败抛 EParseError
- **[INV-3]** ToString 输出合法 JSON（可再解析）
- **[INV-4]** Number 精度：整数用 Int64，浮点用 Double

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 非法 JSON 语法 | EParseError |
| 类型不匹配 (AsString on number) | EInvalidOperation |
| Key 不存在 | ENotFoundError |
| Index 越界 | EOutOfRange |

---

## 4-6. 概要

- **线程安全**: TJsonNode ❌（调用方同步）; 解析/序列化函数 ✅
- **内存**: TJsonNode 树结构，父节点拥有子节点，Destroy 递归释放
- **测试**: 11 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
