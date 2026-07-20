# json × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20  
**范围**：`nextpas.core.json*`  
**标杆**：Go `encoding/json`；Rust `serde_json`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | RFC8259 + 结构化 `TJsonError` + int64 溢出硬失败 |
| **规模 Scale** | **8.5** | Parse/Stringify/Builder/Marshal；无 Pointer/Patch/Schema |
| **综合** | **8.8** | 生产可用；Schema 族显式 Out of scope |

---

## Essential 矩阵

| 能力 | Go / Rust | nextpas | 状态 |
|------|-----------|---------|------|
| Parse / Stringify | Unmarshal/Marshal | `JsonParse` / `JsonStringify` | Done |
| 流式 token | Decoder/Token | `TJsonReader` | Done |
| 结构化错误 | SyntaxError offset | `TJsonError` Line/Column/Offset | Done |
| 对象/数组访问 | map/slice | `TJsonValue` 借用视图 | Done |
| int64 精确 | json.Number / i64 | `jnkInt` + overflow reject | Done |
| float | float64 | `jnkReal` + overflow reject | Done |
| Builder | Encoder | `IJsonBuilder` | Done |
| 结构体映射 | tags / serde | `json.marshal` + reflect | Done |
| JSON Pointer | 外部 | Out of scope | Deferred |
| JSON Schema | 外部 | Out of scope | Deferred |
| JSON Patch | 外部 | Out of scope | Deferred |

---

## 整数语义（锁死）

| 输入 | 行为 |
|------|------|
| `High(Int64)` / `Low(Int64)` | `jnkInt`，精确 roundtrip |
| `High+1` / `Low-1`（无小数/指数） | `number overflow` 错误，不静默变 float |
| `1e20` 等显式浮点 | `jnkReal`；`1e1000` → overflow |
| `2^53±1`（JS safe 边界） | 仍为精确 `Int64`（与 JS Number 不同） |

证据：`test_json_reader` overflow 套件 + `test_json_edge_cases` facade 锁。

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.json/test_json_edge_cases
make focused FOCUS=core/tests/nextpas.core.json/test_json_reader
make focused FOCUS=core/tests/nextpas.core.json/test_json_facade_surface
```
