# xml × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.xml*`
**标杆**：Go `encoding/xml`；Rust `quick-xml` / `roxmltree`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **8.0** | `EXmlError` 带位置；Reader/Writer/DOM 分层 |
| **规模 Scale** | **7.5** | 常用 token + DOM；无 XPath/XSD |
| **综合** | **7.8** | 配置族旁路工具；不进 `TConfigFormat` |

---

## Essential 矩阵

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Token reader | Decoder / Event | `TXmlReader` class | Done |
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
