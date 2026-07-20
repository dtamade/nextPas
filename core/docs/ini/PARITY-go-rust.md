# ini × Go / Rust 对标（Wave I）

**状态日期**：2026-07-20  
**范围**：`nextpas.core.ini`  
**标杆**：Go `gopkg.in/ini.v1` / `ini`；Rust `rust-ini` / `configparser`

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **8.3** | 宽松 parse + Try 路径；**TIniError** 结构化诊断 |
| **规模 Scale** | **8.0** | section/key CRUD、typed read/write、roundtrip |
| **综合** | **8.2** | 与 Go ini 常用 API 对齐；无继承/多文件 merge（交给 config） |

---

## Essential 矩阵

| 能力 | Go ini | nextpas | 状态 |
|------|--------|---------|------|
| Load string/file | ✓ | LoadFromString/File | Done |
| Try-load | 常见 | string + **TIniError** 重载 | Done |
| Section/Key 读写 | ✓ | Read*/Write* | Done |
| 大小写不敏感 | 常见 | INV-1 | Done |
| 注释 ; # | ✓ | ✓ | Done |
| 结构化错误 | 行号 | `TIniError` Line/Column/Offset | Done |
| 多文件 merge | 库层 | 由 `config` 负责 | Done（分工） |

---

## 本轮（Wave I）关闭

| 项 | 结论 |
|----|------|
| `TIniError` | **Done** — 对齐 CSV/JSON 诊断形状 |
| string 重载兼容 | 保留 `line N, column C: message` |

---

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.ini/test_ini_facade_surface
make focused FOCUS=core/tests/nextpas.core.ini/test_ini
```
