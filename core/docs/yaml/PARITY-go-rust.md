# yaml × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.yaml*`
**标杆**：Go `gopkg.in/yaml.v3`；Rust `serde_yaml` / `yaml-rust2`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.1** | 单文档严格；矩阵 facade；merge-key 拒绝；roundtrip |
| **规模 Scale** | **8.9** | config 消费子集 + IReader + builder |
| **综合** | **9.0** | 子集有意；证据见 facade feature matrix |

---

## Essential 矩阵

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Parse / Stringify | Unmarshal/Marshal | `YamlParse` / writer | Done |
| Map/Seq 访问 | Node | `TYamlValue` + `Get`/`MapGet` | Done |
| 结构化错误 | line/col | `TYamlError` | Done |
| Builder | — | `TYamlBuilder` record | Done |
| 多文档流 | Decoder | **拒绝**第二 `---` | Done（有意严格） |
| merge-key `<<` | 部分库 | **拒绝**（有意） | Done（strict） |
| config 消费子集 | — | 标量/map/seq + 深度/大值 + IReader | Done |
| YAML 1.2 全量 | 部分库 | 子集 | Partial（有意） |
| XPath-like | — | Out of scope | Deferred |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_facade_surface
```
