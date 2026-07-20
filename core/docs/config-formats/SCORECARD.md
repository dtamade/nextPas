# config-formats 全族 SCORECARD（Wave Q — path A/B）

**truth**：`host-linux`
**lane**：`config-json-xml-toml-yaml-csv-ini`
**日期**：2026-07-21

---

## A. 一键门禁

```bash
bash core/docs/config-formats/scripts/run-facade-gates.sh
make focused FOCUS=core/tests/nextpas.core.config/test_config_format_contracts
make focused FOCUS=core/tests/nextpas.core.ini/test_ini
make focused FOCUS=core/tests/nextpas.core.config/test_config_examples
make hygiene
```

---

## B. Wave Q 关闭项

| 项 | 状态 |
|----|------|
| INI `LoadFromFile`/`SaveToFile` → `ReadFileText`/`WriteAtomic` | Done |
| 生产禁止 `TextFile`/`AssignFile`（contracts） | Done |
| `test_config_examples` 去 SysUtils/Classes → process/fs | Done |
| 测试 SysUtils/Classes 禁令（contracts） | Done |
| Recommended calls + 错误模型 + silent-default ⚠️ | Done |
| json `Get` / `IsFloat` 别名 | Done |
| xml `TextFormat` 替代 deprecated `Format` | Done |

---

## C. PARITY 指针

| 模块 | 综合（Wave Q） |
|------|----------------|
| config | **9.5** |
| json | **9.3**（Get/IsFloat） |
| yaml/toml/csv | **9.1–9.2** |
| ini | **9.2**（fs I/O） |
| xml | **9.1** |

**Steady**：Schema / XPath / YAML multi-doc / 真流式 JSON 仍 Out of scope。
