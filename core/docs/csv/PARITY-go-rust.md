# csv × Go / Rust 对标（Wave I–J）

**状态日期**：2026-07-20
**范围**：`nextpas.core.csv`
**标杆**：Go `encoding/csv`；Rust `csv` crate

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | RFC4180；`TCsvError`；chunked IReader 跨块 quoted |
| **规模 Scale** | **9.0** | Reader/Writer + delimiter/comment/trim + **流式 IReader** |
| **综合** | **9.0** | 对齐 Go `encoding/csv` Reader 形状 |

---

## Essential 矩阵

| 能力 | Go `encoding/csv` | nextpas | 状态 |
|------|-------------------|---------|------|
| NewReader(string) | NewReader(r io.Reader) | `Create(string)` | Done |
| NewReader(io.Reader) | ✓ | `Create(IReader)` 分块 refill | Done |
| Read / ReadAll | ✓ | `ReadRow` / `ReadAll` | Done |
| Comma / Comment | ✓ | Delimiter / Comment | Done |
| FieldsPerRecord | ✓ | ✓ | Done |
| LazyQuotes | ✓ | **严格**：bare quote → error（`TestBareQuoteError`） | Done（strict） |
| Writer | ✓ | `TCsvWriter` | Done |
| 结构化错误 | ParseError | `TCsvError` | Done |
| 真正流式大文件 | 按块读 | 8KiB refill + 跨块 quoted | Done |

---

## 本轮关闭

| 项 | 结论 |
|----|------|
| `IReader` 入口 | **Done** — Wave I |
| 分块 refill / 跨块 quoted | **Done** — Wave J（chunk=1 测试锁） |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.csv/test_csv_facade_surface
make focused FOCUS=core/tests/nextpas.core.csv/test_csv
```
