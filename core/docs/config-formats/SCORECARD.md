# config-formats 全族 SCORECARD（Wave K）

**truth**：`host-linux` 单机快照（2026-07-20）
**lane**：`config-json-xml-toml-yaml-csv-ini`

对标矩阵见各模块 `PARITY-go-rust.md`。

---

## A. 用例规模（`T.Test` 静态计数）

| 模块 | T.Test 合计 |
|------|-------------|
| config | ~237（含 facade 8） |
| json | 175+ |
| yaml | 206+ |
| toml | 334+ |
| csv | 105+ |
| ini | 71+ |
| xml | 216+ |

---

## B. Wave K focused 代表路径（本波实测）

```bash
make focused FOCUS=core/tests/nextpas.core.config/test_config_facade_surface
make focused FOCUS=core/tests/nextpas.core.json/test_json_facade_surface
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_facade_surface
make focused FOCUS=core/tests/nextpas.core.toml/test_toml_facade_surface
make hygiene
```

| 套件 | 结果 |
|------|------|
| config facade_surface | **8 passed**（Section + DurationNs） |
| json facade_surface | **2 passed**（IReader parse） |
| yaml facade_surface | **3 passed**（IReader parse） |
| toml facade_surface | **3 passed**（IReader parse） |
| hygiene | **pass** |

---

## C. Wave K 关闭项

| 项 | 状态 |
|----|------|
| ConfigSection（viper Sub） | Done |
| GetDurationNs 最小后缀 | Done |
| Json/Yaml/Toml Parse(IReader) bulk | Done |
| CSV bare-quote 严格语义文档 | Done（既有 TestBareQuoteError） |

---

## D. PARITY 综合指针（Wave K）

| 模块 | 综合 |
|------|------|
| config | **9.0** |
| json | **9.0** |
| csv | **9.0** |
| toml | 8.6 |
| yaml | 8.0+ |
| ini | 8.2 |
| xml | 8.2 |
