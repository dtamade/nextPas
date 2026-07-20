# nextpas.core.yaml 代码契约

**模块路径**：`core/src/nextpas.core.yaml*.pas`（7 个源文件）
**层级**：L2（只依赖 L0–L1）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-07-20
**版本**：2.0（对齐真实 facade；废止 1.0 中 `TYamlNode` class / YamlPath 描述）

---

## 1. 源文件与职责

| 单元 | 职责 |
|------|------|
| `yaml.types` | `TYamlNodeKind`、`TYamlError`、token 类型、常量 |
| `yaml.scanner` | token 扫描（含 SIMD） |
| `yaml.parser` | `TYamlDocument` record 解析器 |
| `yaml.value` | `TYamlValue` 借用视图 |
| `yaml.writer` | 低层序列化 |
| `yaml.builder` | **`TYamlBuilder` record**（非 interface） |
| `yaml.pas` | 门面：`IYamlDocument`、`YamlParse*` |

---

## 2. 公开 API

### 2.1 门面（`uses nextpas.core.yaml`）

```pascal
type
  TYamlNodeKind = (...);
  TYamlError = record
    Message: TStringView;
    Line: UInt32;
    Col: UInt32;       // 字段名 Col（与 TOML 一致，与 JSON Column 不同）
    Offset: SizeUInt;
  end;
  TYamlValue = record ... end;
  TYamlBuilder = record ... end;  // Init/Done 手动生命周期

  IYamlDocument = interface
    function Root: TYamlValue;
    function HasError: Boolean;
    function Error: TYamlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

function YamlParse(const AInput: string): IYamlDocument; overload;
function YamlParse(const AInput: TStringView): IYamlDocument; overload;
function TryYamlParse(const AInput: string; out ADoc: IYamlDocument): Boolean;
function YamlParseWith(...; const AAllocator: TMemAllocator): IYamlDocument;
```

### 2.2 `TYamlValue` 访问

- 判断：`IsValid`、`IsNull`、`IsBool`、`IsInt`、`IsFloat`、`IsStr`、`IsSeq`、`IsMap`、`Kind`
- 标量：`AsBool`、`AsInt`、`AsFloat`、`AsStr`
- 序列：`SeqLen`、`SeqGet`
- 映射：`MapGet`、`MapHas`、`MapLen`、`MapKeyAt`、`MapValueAt`
- **没有** `Get` 方法（与 TOML 的 `Get` 不同；请用 `MapGet`）
- 非法访问：安全默认

### 2.3 Builder

`TYamlBuilder` 为 **record**，需 `Init`/`Done`（或文档约定的构造路径），与 `IJsonBuilder`/`ITomlBuilder` 的 interface 形态不同。这是已知 API 差异，不是疏漏。

---

## 3. 错误与失败契约

| API | 失败行为 |
|-----|----------|
| `YamlParse` / `YamlParseWith` | document + `HasError` |
| `TryYamlParse` | `False` + 诊断 document |
| 诊断 document | 不可 `Stringify` / `StringifyPretty` |

---

## 4. Lifetime / 所有权

- `IYamlDocument` 必须活过所有 `TYamlValue`
- `YamlParseWith`：allocator 控制 parser document 存储；实现注释说明部分内部仍用 RTL 动态数组

---

## 5. 不变量与支持子集

**当前支持（以实现与测试为准）**：

- 标量：string / int / float / bool / null（YAML 1.2 core schema 取向）
- block sequence / mapping、flow collections
- anchors & aliases（有解析深度限制常量）
- block scalars `|` / `>`
- comments、`%YAML` directive、multi-document (`---`)

**[INV-1]** 节点为 arena/record，不是 class DOM
**[INV-2]** 无 error 时 `Stringify` 可再解析（子集语义）
**[INV-3]** config 展平时使用 YAML DOM，不手写行解析

---

## 6. 依赖边界

- `text.view`、`text.scan`、`text.number`、`mem`、（实现可依赖 `math` 模块而非 FPC Math）
- **消费者**：`config`（LoadFromYaml / export）

---

## 7. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_facade_surface
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_spec
```

套件：facade、scanner、builder、block、roundtrip、spec、advanced、audit、coverage 等。

---

## 8. Out of scope / Future

- **不存在** `yaml.path` / YAMLPath 查询单元
- **不存在** 以 `TYamlNode` class 为中心的公开 API
- 完整 YAML 1.2 全部 tag / schema / 任意复杂 merge key 等：仅当有测试与 consumer 再扩
- 与 JSON 强制统一 `ObjectGet` 命名：不做破坏性 rename

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始（与实现不符，已废止） | — |
| 2026-07-20 | 2.0 | 对齐 IYamlDocument / MapGet / TYamlBuilder record | config-formats lane |
