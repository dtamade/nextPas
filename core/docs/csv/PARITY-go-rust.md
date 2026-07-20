# csv × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20  
**范围**：`nextpas.core.csv`  
**标杆**：Go `encoding/csv`；Rust `csv` crate

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **8.8** | RFC4180；`TCsvError` 行/列/offset；in-band 错误 |
| **规模 Scale** | **8.5** | Reader/Writer + delimiter/comment/trim + **IReader** |
| **综合** | **8.6** | 与 Go Reader 形状对齐；非真正按块流式 token |

---

## Essential 矩阵

| 能力 | Go `encoding/csv` | nextpas | 状态 |
|------|-------------------|---------|------|
| NewReader(string) | NewReader(r io.Reader) | `Create(string)` | Done |
| NewReader(io.Reader) | ✓ | `Create(IReader)`（ReadAll 后解析） | Done |
| Read / ReadAll | ✓ | `ReadRow` / `ReadAll` | Done |
| Comma / Comment | ✓ | Delimiter / Comment | Done |
| FieldsPerRecord | ✓ | ✓ | Done |
| LazyQuotes | ✓ | Partial（实现取舍） | Partial |
| Writer | ✓ | `TCsvWriter` | Done |
| 结构化错误 | ParseError | `TCsvError` | Done |
| 真正流式大文件 | 按块读 | 当前整读入 string | Partial |

---

## 本轮（Wave I）关闭

| 项 | 结论 |
|----|------|
| `IReader` 入口 | **Done** — `Init`/`Create(IReader)`；nil → `EArgumentError` |
| 超大文件流式 | Future（需真流式字段扫描） |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.csv/test_csv_facade_surface
make focused FOCUS=core/tests/nextpas.core.csv/test_csv
```
