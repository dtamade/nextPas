# config-formats 全族 SCORECARD（Wave O Usability）

**truth**：`host-linux`
**lane**：`config-json-xml-toml-yaml-csv-ini`
**日期**：2026-07-20

---

## A. 一键门禁

```bash
bash core/docs/config-formats/scripts/run-facade-gates.sh
make focused FOCUS=core/tests/nextpas.core.config/test_config_format_contracts
make hygiene
```

---

## B. Wave O focused 实测

| 套件 | 结果 |
|------|------|
| config facade_surface | **10 passed** |
| config format contracts | **findings=0 status=ok** |
| json facade_surface | **4 passed**（TryAs + bulk guard） |
| json parser | **40 passed** |
| yaml facade_surface | **5 passed**（含 TryAs） |
| yaml facade | **50 passed** |
| toml facade_surface | **4 passed**（含 TryAs） |
| toml parser | **42 passed** |
| csv facade_surface | **3 passed**（Col 别名） |
| csv edge_cases | **28 passed** |
| ini facade_surface | **7 passed**（Strict + Col） |
| ini / ini_edge | **32 / 25 passed** |
| xml facade_surface | **4 passed** |
| facade gates script | **config-formats-facade-gates=pass** |
| hygiene | **pass** |
| modified tests build matrix | **36/36 OK** |

---

## C. Wave O 关闭项

| 项 | 状态 |
|----|------|
| `config.env` 去掉 SysUtils → `text.conv` | Done |
| 错误记录 `Col`/`Column` 双向别名 | Done |
| `nextpas.core.format.limits` + bulk `IReader` 64MiB 上限 | Done |
| JSON/YAML/TOML `TryAs*` | Done |
| INI `Strict` 模式 | Done |
| 测试 RTL 隔离（SysUtils purge；examples 白名单） | Done |
| source-contract 硬化（include 展开 + no SysUtils + limits） | Done |
| CONTRACT / SCORECARD / config-formats README | Done |

---

## D. PARITY 综合指针

| 模块 | 综合（Wave O） |
|------|----------------|
| config | **9.4**（RTL 隔离 + contracts） |
| json | **9.2**（TryAs + bulk cap） |
| yaml | **9.2** |
| toml | **9.2** |
| csv | **9.1**（Col 别名；真流式仍无 bulk cap） |
| ini | **9.1**（Strict + 结构化错误） |
| xml | **9.0**（bulk cap） |

**Steady 线**：Essential 路径已齐；remote / Schema / XPath / YAML multi-doc 接受仍 Out of scope。
