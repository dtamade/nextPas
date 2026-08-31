# nextpas.core.xml 代码契约

**模块路径**：`core/src/nextpas.core.xml*.pas`（5 个源文件）
**层级**：L2（`design-conventions` 将 xml 放在 L2 系统能力；非 L1）
**Owner**：config-json-xml-toml-yaml-csv-ini lane
**最后更新**：2026-08-31
**版本**：2.1（对齐真实 class API + IXmlDocument；废止 1.0 record Reader 描述）

---

## 1. 源文件与职责

| 单元 | 职责 |
|------|------|
| `xml.base` | `TXmlTokenKind`、`TXmlName`、`TXmlPosition`、`EXmlError`、属性/命名空间类型 |
| `xml.reader` | `TXmlReader` **class** 分词/流式读 |
| `xml.writer` | `TXmlWriter` **class** 序列化 |
| `xml.dom` | `TXmlDocument` / `TXmlNode` **class** DOM |
| `xml.pas` | 门面 re-export + `XmlParse*` / `XmlTokenize*` / 编解码辅助 + `IXmlDocument` |

---

## 2. 公开 API

### 2.1 门面类型

```pascal
type
  TXmlReader = class ...;   // 调用方 Free
  TXmlWriter = class ...;   // 调用方 Free
  TXmlDocument = class ...; // 调用方 Free
  TXmlNode = class ...;
  EXmlError = class(EParseError)
    // Pos: TXmlPosition (ByteOffset, Line, Column; Col is Column alias)
  end;

  IXmlDocument = interface
    property Root: TXmlNode;
    property HasError: Boolean;
    property Error: EXmlError;
    property Document: TXmlDocument;
    function Stringify: string;
  end;
```

### 2.2 解析入口

| 函数 | 返回 | 失败 |
|------|------|------|
| `XmlParse` / `XmlParseWith` | `TXmlDocument` | 抛 `EXmlError` |
| `TryXmlParse` / `TryXmlParseWith` | `Boolean` | `False` 且 `ADoc = nil` |
| `XmlParseDoc` / `XmlParseDocWith` | `IXmlDocument` | 适配 interface 生命周期 |
| `TryXmlParseDoc` / `TryXmlParseDocWith` | `Boolean` + `IXmlDocument` | 失败路径按实现 |
| `XmlTokenize` / `XmlTokenizeWith` | `TXmlTokenArray` | 失败抛 `EXmlError` |

### 2.3 编解码辅助

- `XmlDecodeEntities`
- `XmlEncodeText`
- `XmlEncodeAttr`

### 2.4 推荐入口

- **应用代码 / 与 JSON 风格对齐**：优先 `XmlParseDoc` → `IXmlDocument`
- **需要细粒度 token 控制**：`TXmlReader`
- **就地改 DOM 树**：`TXmlDocument` + 调用方 `Free`

**config 不加载 XML**（`TConfigFormat` 无 `cfXml`）。

---

## 3. 错误与失败契约

- 主路径错误模型是 **异常** `EXmlError`，不是 JSON 式 error record
- `EXmlError.Pos`：`ByteOffset`、`Line`、`Column`（`Col` 为 `Column` 的 property 别名）
- `TryXmlParse*`：不抛，返回 `False`

这与 json/yaml/toml 的「document.HasError」模型不同，是 **有意差异**。

---

## 4. Lifetime / 所有权

- `TXmlDocument` / `TXmlReader` / `TXmlWriter`：调用方拥有并 `Free`
- `IXmlDocument`：COM 引用计数；内部持有 `TXmlDocument`
- DOM：父节点拥有子节点

---

## 5. 不变量

- **[INV-1]** Reader/Writer/Document 为 class，不是零堆 record（1.0 文档错误）
- **[INV-2]** well-formedness 检查、namespace、CDATA、注释、PI、XML 声明、DOCTYPE（以实现/测试为准）
- **[INV-3]** Writer 转义特殊字符；非法 close 操作拒绝
- **[INV-4]** DOM 物化深度上限 `XML_MAX_NESTING_DEPTH`（512，`xml.base`）：
  超限 `XmlParse` 抛 `EXmlError('Element nesting too deep')`，`TryXmlParse` 返回 `False`；
  空元素同样按父级+1 计深。流式 `TXmlReader` 不设上限（与 CSV 流式同理）

---

## 6. 依赖边界

- `text.view`、`text.scan`、`errors`、`mem`
- 相对 json/toml 为 **低优先级** 格式模块（design-conventions 亦标注）

---

## 7. 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.xml/test_xml_facade_surface
make focused FOCUS=core/tests/nextpas.core.xml/test_xml_roundtrip
```

套件：`test_xml`、`test_xml_dom`、`test_xml_reader`、`test_xml_writer`、`test_xml_edge_cases`、`test_xml_roundtrip`、`test_xml_facade_surface`。

---

## 8. Out of scope / Future

- XPath / XQuery / XSD / full DTD validation
- 把 Reader 改成 record 零分配公开 API（除非独立设计 slice）
- 纳入 `TConfigFormat`

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始（record Reader/L1 描述错误，已废止） | — |
| 2026-07-20 | 2.0 | 对齐 class API、IXmlDocument、L2 | config-formats lane |
| 2026-07-26 | 2.1 | INV-4 DOM 深度上限 512（修复深树 `Text` 递归 SIGSEGV） | config-formats lane |
| 2026-08-31 | 2.1 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
