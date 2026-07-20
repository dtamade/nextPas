# yaml × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.yaml*`
**标杆**：Go `gopkg.in/yaml.v3`；Rust `serde_yaml` / `yaml-rust2`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | 单文档严格；错误定位；IReader；深度/大值边测 |
| **规模 Scale** | **8.5** | 1.1 常用 + builder；多文档有意拒绝 |
| **综合** | **8.8** | config 路径扎实；非全 YAML 1.2（有意） |

---

## Essential 矩阵

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Parse / Stringify | Unmarshal/Marshal | `YamlParse` / writer | Done |
| Map/Seq 访问 | Node | `TYamlValue` + `Get`/`MapGet` | Done |
| 结构化错误 | line/col | `TYamlError` | Done |
| Builder | — | `TYamlBuilder` record | Done |
| 多文档流 | Decoder | **拒绝**第二 `---` | Done（有意严格） |
| YAML 1.2 全量 | 部分库 | 子集 | Partial |
| XPath-like | — | Out of scope | Deferred |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_facade_surface
```
