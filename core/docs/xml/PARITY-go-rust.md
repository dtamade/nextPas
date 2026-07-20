# xml × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.xml*`
**标杆**：Go `encoding/xml`；Rust `quick-xml` / `roxmltree`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **8.8** | `EXmlError` 位置；namespace 护栏；IReader |
| **规模 Scale** | **8.5** | token + DOM + `XmlParse(IReader)`；无 XPath/XSD |
| **综合** | **8.6** | encoding/xml 常用路径；XPath/XSD 有意 Out of scope |

---

## Essential 矩阵

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Token reader | Decoder / Event | `TXmlReader` class | Done |
| 从 Reader 解析 | Decoder | `XmlParse`/`XmlParseDoc`(IReader) bulk | Done |
| Writer | Encoder | `TXmlWriter` | Done |
| DOM | — / roxmltree | `TXmlDocument` / `TXmlNode` | Done |
| 位置诊断 | SyntaxError | `EXmlError.Pos` | Done |
| 命名空间 | ✓ | Writer `NamespaceDecl` + 保留前缀护栏 + facade 抽检 | Done |
| XPath | 外部 | Out of scope | Deferred |
| XSD | 外部 | Out of scope | Deferred |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.xml/test_xml_facade_surface
```
