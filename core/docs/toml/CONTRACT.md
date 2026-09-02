# nextpas.core.toml 代码契约

**模块路径**：`core/src/nextpas.core.toml*.pas`（6 个源文件）
**层级**：L2（只依赖 L0–L1）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-08-31
**版本**：2.1（对齐真实 facade；废止 1.0 中 `TTomlNode` class 描述）

---

## 概要

以 `TTomlValue` 值语义提供 TOML 解析与序列化,支持表/数组/键值及双层生命周期;门面 `nextpas.core.toml`(6 个源文件),错误与失败契约见后文。

## 1. 源文件与职责

| 单元 | 职责 |
|------|------|
| `toml.base` | `TTomlNodeKind`、`TTomlNode`、`TTomlDateTime`、`TTomlError`、标志常量 |
| `toml.parser` | `TTomlDocument` record 解析器 |
| `toml.value` | `TTomlValue` 借用视图 + `TomlEnumerate` |
| `toml.writer` | 低层序列化 |
| `toml.builder` | `ITomlBuilder` |
| `toml.pas` | 门面：`ITomlDocument`、`TomlParse*`、datetime 辅助、builder 入口 |

---

## 2. 接口契约(公开 API)

### 2.1 门面（`uses nextpas.core.toml`）

```pascal
type
  TTomlNodeKind = (...);
  TTomlDateTimeKind = (...);
  TTomlDateTime = record ... end;
  TTomlError = record
    Message: TStringView;
    Line: UInt32;
    Col: UInt32;      // 主字段名 Col；Column 为 property 别名
    Offset: SizeUInt;
    property Column: UInt32 read Col write Col;
  end;
  TTomlValue = record ... end;
  ITomlBuilder = interface ... end;

  ITomlDocument = interface
    function Root: TTomlValue;
    function HasError: Boolean;
    function Error: TTomlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32): string;
  end;

function TomlParse(const AInput: string): ITomlDocument; overload;
function TomlParse(const AInput: TStringView): ITomlDocument; overload;
function TryTomlParse(const AInput: string; out ADoc: ITomlDocument): Boolean;
function TomlParseWith(...; const AAllocator: TMemAllocator): ITomlDocument;
function TomlBuilder: ITomlBuilder; overload;
function TomlBuilder(const AInitialCap: SizeUInt): ITomlBuilder; overload;
function TomlDateTime(...): TTomlDateTime;
function TomlDateTimeWithOffset(...): TTomlDateTime;
function TomlDate(...): TTomlDateTime;
function TomlTime(...): TTomlDateTime;
function TomlEnumerate(const AValue: TTomlValue): TTomlValueEnumerator;
```

### 2.2 `TTomlValue` 访问

- 判断：`IsValid`、`IsStr`、`IsInt`、`IsFloat`、`IsBool`、`IsDateTime`、`IsArray`、`IsTable`、`Kind`
- 标量：`AsStr`、`AsInt`、`AsFloat`、`AsBool`、`AsDateTime`、`AsString`
- 安全出参：`TryAsBool`、`TryAsInt`、`TryAsFloat`、`TryAsStr`
- 表：`Get`、`Has`、`TableLen`、`TableKeyAt`、`TableValueAt`、`FindByPath`
- 数组：`ArrayLen`、`ArrayGet`
- 迭代：`TomlEnumerate` / `Key`（遍历时）
- 非法访问：`As*` 安全默认；`TryAs*` 返回 False

### 2.3 双层生命周期

| 层 | 类型 | 生命周期 |
|----|------|----------|
| 上层 | `ITomlDocument` / `ITomlBuilder` | COM 自动释放 |
| 下层 | `TTomlDocument` / `TTomlWriter` record | 手动 Init/Done（热路径） |

---

## 3. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `TomlParse` / `TomlParseWith` | document + `HasError` |
| `TomlParse(IReader)` | `IoReadAll` + `FORMAT_BULK_PARSE_MAX_BYTES` bulk cap |
| `TryTomlParse` | `False` + 诊断 document |
| 诊断 document | 不可 `Stringify` |
| 严格校验 | 重复键、前导零、下划线、datetime 范围等 → error |

---

## 4. Lifetime / 所有权

- 保持 `ITomlDocument` 存活期间使用 `TTomlValue`
- zero-copy 无转义字符串借用输入缓冲
- `TomlParseWith`：allocator 覆盖 document 寿命

---

## 5. 不变量

- **[INV-1]** 目标规范：**TOML v1.0**（实现细节以 compliance 测试为准）
- **[INV-2]** DateTime 支持 offset / local datetime / local date / local time
- **[INV-3]** Writer 日期字段固定宽度（含四位年份）
- **[INV-4]** 多行注释写出时每物理行以 `# ` 前缀，避免后续行变成有效 TOML
- **[INV-5]** 无 error 时 `Stringify` 可再解析

---

## 6. 依赖边界

- `text.view`、`text.builder`、`text.scan`、`mem` 系列
- **消费者**：`config`（LoadFromToml / export）

---

## 7. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.toml/test_toml_facade_surface
make focused FOCUS=core/tests/nextpas.core.toml/test_toml_compliance
make -C core/examples/nextpas.core.toml/toml_smoke run
```

套件含 facade、parser、writer、value、roundtrip、compliance、defensive、fuzz、property、stress、robustness 等。

---

## 8. Out of scope / Future

- 不以 `TTomlNode` **class** 为公开 API
- 不在本契约中宣称完整 TOML v1.1，除非 compliance 测试明确覆盖并更新本文件
- JSON 式 `ObjectGet` 命名不用于 TOML（使用 `Get` / table 语义）

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始（与实现不符，已废止） | — |
| 2026-07-20 | 2.0 | 对齐 ITomlDocument / TTomlValue 真实 API | config-formats lane |
| 2026-08-31 | 2.1 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
