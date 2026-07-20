# toml × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20
**范围**：`nextpas.core.toml*`
**标杆**：Go `BurntSushi/toml` / `pelletier`；Rust `toml` crate

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | `TTomlError`；datetime；IReader；深度/大值/dup |
| **规模 Scale** | **9.0** | Parse/Builder/Writer + compliance/fuzz 厚 |
| **综合** | **9.0** | 与 TOML 1.0 常用表对齐 |

---

## Essential 矩阵

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Parse | Decode | `TomlParse` | Done |
| 表/数组访问 | tree | `TTomlValue` | Done |
| 错误定位 | line/col | `TTomlError` (Line/Col/Offset) | Done |
| Datetime | time types | `TTomlDateTime` | Done |
| Builder | — | `ITomlBuilder` | Done |
| 严格重复 key | 规范 | 拒绝/诊断 | Done |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.toml/test_toml_facade_surface
```
