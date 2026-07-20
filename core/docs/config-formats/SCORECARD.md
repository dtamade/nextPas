# config-formats 全族 SCORECARD（Wave P residual）

**truth**：`host-linux`
**lane**：`config-json-xml-toml-yaml-csv-ini`
**日期**：2026-07-21

---

## A. 一键门禁

```bash
bash core/docs/config-formats/scripts/run-facade-gates.sh
make focused FOCUS=core/tests/nextpas.core.config/test_config_format_contracts
make hygiene
```

---

## B. Wave P focused 实测

| 套件 | 结果 |
|------|------|
| config facade_surface | **11 passed**（+ TryGet*） |
| xml facade_surface | **5 passed**（+ Pos.Col） |
| config format contracts | **findings=0 status=ok** |
| hygiene | **pass** |

Wave O 证据保留：json/yaml/toml TryAs、bulk cap、INI Strict、SysUtils purge 仍有效。

---

## C. Wave P 关闭项

| 项 | 状态 |
|----|------|
| Config `TryGetInt/Bool/Float/DurationNs/ByteSize` | Done |
| XML `TXmlPosition.Col` 别名 | Done |
| IConfig 三 wrapper 转发 | Done |

---

## D. PARITY 综合指针

| 模块 | 综合（Wave P） |
|------|----------------|
| config | **9.5**（TryGet* 类型安全） |
| json | **9.2** |
| yaml | **9.2** |
| toml | **9.2** |
| csv | **9.1** |
| ini | **9.1** |
| xml | **9.1**（Col 别名对齐） |

**Steady 线**：Essential 路径已齐；remote / Schema / XPath / YAML multi-doc 接受仍 Out of scope。
