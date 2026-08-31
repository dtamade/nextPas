# nextpas.core.json 代码契约

**模块路径**：`core/src/nextpas.core.json*.pas`（9 个源文件）
**层级**：L2（只依赖 L0–L1）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-08-31
**版本**：2.1（对齐真实 facade；废止 1.0 中 class-DOM / Pointer / Patch / Schema 描述）

---

## 概要

以 `TJsonValue` 值语义提供 JSON 解析、序列化与遍历,支持 object/array/string/number/bool/null 全类型;门面 `nextpas.core.json`(9 个源文件),错误与失败契约见后文。

## 1. 源文件与职责

| 单元 | 职责 |
|------|------|
| `json.types` | `TJsonNodeKind`、`TJsonNode`（arena 节点 record）、`TJsonError`、token 常量 |
| `json.scanner` | 结构扫描（含 SIMD 路径） |
| `json.reader` | 低层 token 读取 |
| `json.parser` | `TJsonDocument` record 解析器 |
| `json.value` | `TJsonValue` 借用视图访问器 |
| `json.writer` | 低层序列化 |
| `json.builder` | `IJsonBuilder` 流式构建 |
| `json.marshal` | 依赖 `reflect` 的 record ↔ JSON |
| `json.pas` | 门面：`IJsonDocument`、`JsonParse*`、`JsonStringify` |

依赖方向：`types` ← `parser`/`value`/`writer` ← `pas`；`builder`、`marshal` 为可选子面，不经门面强制 re-export 全部符号。

---

## 2. 接口契约(公开 API)

### 2.1 门面（`uses nextpas.core.json`）

```pascal
type
  TJsonNodeKind = (...);  // jnkNull, jnkBool, jnkInt, jnkReal, jnkString, jnkArray, jnkObject
  TJsonError = record
    Message: TStringView;
    Offset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;
  TJsonValue = record ... end;  // 借用视图，非堆 DOM class

  IJsonDocument = interface
    function Root: TJsonValue;
    function HasError: Boolean;
    function Error: TJsonError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

function JsonParse(const AInput: string): IJsonDocument; overload;
function JsonParse(const AInput: TStringView): IJsonDocument; overload;
function TryJsonParse(const AInput: string; out ADoc: IJsonDocument): Boolean;
function JsonParseWith(const AInput: string; const AAllocator: TMemAllocator): IJsonDocument; overload;
function JsonParseWith(const AInput: TStringView; const AAllocator: TMemAllocator): IJsonDocument; overload;
function JsonStringify(const AValue: TJsonValue): string;
```

### 2.2 `TJsonValue` 访问（`json.value`）

- 类型判断：`IsValid`、`IsNull`、`IsBool`、`IsInt`、`IsReal`（别名 `IsFloat`）、`IsStr`、`IsArray`、`IsObject`、`Kind`
- 标量：`AsBool`、`AsInt`、`AsFloat`、`AsStr`（`TStringView`）
- 安全出参：`TryAsBool`、`TryAsInt`、`TryAsFloat`、`TryAsStr`（类型匹配时 `True` + out；否则 `False` + 安全默认）
- 数组：`ArrayLen`、`ArrayGet`
- 对象：`ObjectGet`、`Get`（`ObjectGet` 别名）、`ObjectHas`、`ObjectLen`、`ObjectKeyAt`、`ObjectValueAt`
- **`As*` 非法访问返回安全默认值**（0 / empty / false / invalid view），不抛异常 — 应用代码优先 `TryAs*`

### 2.3 可选子面

| 单元 | API |
|------|-----|
| `json.builder` | `IJsonBuilder` + `JsonBuilder` / `JsonBuilder(AInitialCap)` |
| `json.marshal` | `JsonMarshal`、`JsonUnmarshal`、`JsonUnmarshalStr`（需 `ITypeRegistry`） |

---

## 3. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `JsonParse` / `JsonParseWith` | 返回带 `HasError=True` 的 document；不抛解析异常 |
| `TryJsonParse` | 失败返回 `False`，仍赋值诊断 document |
| `Stringify` / `StringifyPretty` | 诊断 document 不可序列化（实现内 RequireStringifiable） |
| `TJsonValue` 错误类型访问 | 安全默认，不抛 |
| OOM | allocator 路径 fail-closed（`EOutOfMemoryError` 等） |

`TJsonError` 字段：`Message`、`Offset`、`Line`、`Column`；`Col` 为 `Column` 的 property 别名（跨格式统一诊断命名）。

`JsonParse(IReader)` 经 `IoReadAll` 整读后解析，受 `FORMAT_BULK_PARSE_MAX_BYTES`（`nextpas.core.format.limits`，默认 64 MiB）约束；超限抛 `EArgumentError`。

---

## 4. Lifetime / 所有权

- `IJsonDocument`：COM 引用计数；出作用域自动释放
- `TJsonValue`：借用 document 内部节点；**document 必须活过所有 value 使用**
- zero-copy 字符串视图：未转义字符串可能指向输入缓冲；输入 lifetime 由 document 持有保证
- `JsonParseWith`：调用方提供的 `TMemAllocator` 生命周期须覆盖 document

---

## 5. 不变量

- **[INV-1]** 节点存储为 arena/`TJsonNode` record 树，不是 `TJsonNode` class
- **[INV-2]** RFC 8259 对象键为字符串；重复键 hash 查找 last-wins，迭代可保留全部
- **[INV-3]** 最大嵌套深度 512（实现常量）
- **[INV-4]** 整数优先 `Int64`；溢出可提升为 `Double`
- **[INV-5]** `Stringify` 输出可再解析（无 error 的 document）

---

## 6. 依赖边界

- 允许：`text.view`、`text.builder`、`text.scan`（实现）、`mem.intf` / `mem.allocator.base`
- `marshal` 额外依赖 `reflect`
- 禁止：直接 `uses SysUtils` 作为长期方案；禁止 L3 反向依赖

**主要消费者**：`config`、`http`、`tls`、`bench`、`reflect` 相关路径。公共 API 变更成本最高。

---

## 7. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.json/test_json_facade_surface
make focused FOCUS=core/tests/nextpas.core.json/test_json_parser
# 全模块：core/tests/nextpas.core.json/*
make -C core/examples/nextpas.core.json/json_smoke run
```

代表性套件：`test_json_facade`、`test_json_facade_surface`、`test_json_parser`、`test_json_reader`、`test_json_writer`、`test_json_builder`、`test_json_marshal`、`test_json_rfc8259`、`test_json_roundtrip`、`test_json_edge_cases`、`test_json_robustness`。

---

## 8. Out of scope / Future

**当前不存在（禁止在文档中写成已实现）**：

- JSON Pointer (RFC 6901)
- JSON Patch (RFC 6902)
- JSON Schema
- 以 `TJsonNode` **class** 为中心的公开 DOM API

**Future（需独立 slice + consumer）**：Pointer/Patch/Schema 等。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始（与实现不符，已废止） | — |
| 2026-07-20 | 2.0 | 对齐 IJsonDocument / TJsonValue 真实 API | config-formats lane |
| 2026-08-31 | 2.1 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
