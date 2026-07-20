# config-formats SCORECARD（host-linux 证据）

**truth 标签**

| 标签 | 含义 |
|------|------|
| `host-linux` | 本机 Linux 跑的 focused 门禁；非全量 CI 矩阵 |

本表是**单机快照**，用于复现命令与规模对照。对标矩阵见 [`PARITY-go-rust.md`](./PARITY-go-rust.md)。

---

## 环境（本快照）

| 项 | 值 |
|----|-----|
| 日期 | 2026-07-20 |
| OS | Linux x86_64 |
| 分支 | `config-json-xml-toml-yaml-csv-ini`（Wave J） |
| 工具 | FPC 3.3.1 |

---

## A. Config 门禁（`T.Test` 用例数）

| 套件 | 用例 | 结果 |
|------|------|------|
| test_config | 90 | host-linux 历史全绿（本波未重跑） |
| test_config_args | 5 | host-linux |
| test_config_env_windows_contract | 2 | host-linux |
| test_config_examples | 6 | host-linux |
| test_config_export | 9 | host-linux |
| test_config_facade_surface | **7** | **pass**（含 sniff） |
| test_config_format_contracts | python | host-linux |
| test_config_ini_export | 10 | host-linux |
| test_config_mutation | 19 | host-linux |
| test_config_nested | 41 | host-linux |
| test_config_phase3 | 29 | host-linux |
| test_config_toml_export | 9 | host-linux |
| test_config_yaml_export | 10 | host-linux |
| **合计（Pascal T.Test）** | **≈237** | — |

---

## B. 本波 focused 代表路径（必跑）

```bash
make focused FOCUS=core/tests/nextpas.core.config/test_config_facade_surface
make focused FOCUS=core/tests/nextpas.core.csv/test_csv_facade_surface
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_facade_surface
make focused FOCUS=core/tests/nextpas.core.toml/test_toml_facade_surface
make focused FOCUS=core/tests/nextpas.core.xml/test_xml_facade_surface
make focused FOCUS=core/tests/nextpas.core.json/test_json_edge_cases
make hygiene
```

| 套件 | 用例 | Wave J 结果 |
|------|------|-------------|
| config facade_surface | 7 | **7 passed** |
| csv facade_surface | 3 | **3 passed**（含 chunked IReader） |
| yaml facade_surface | 2 | **2 passed**（depth/large/multi-doc） |
| toml facade_surface | 2 | **2 passed**（depth/large/dup） |
| xml facade_surface | 2 | **2 passed**（namespace） |
| json edge_cases | 3 | **3 passed**（Wave I） |

---

## C. Wave J 能力关闭项

| 项 | 状态 |
|----|------|
| 内容嗅探（无扩展/错扩展） | Done — `TrySniffConfigFormat` |
| CSV 真流式 refill | Done — chunked `IReader` |
| YAML/TOML facade 边测 | Done |
| XML 命名空间抽检 | Done |
| SCORECARD 本文件 | Done |

---

## D. 质量指针

| 模块 | PARITY 综合（Wave I/J） |
|------|------------------------|
| config | 8.3 → **8.7**（嗅探 + SCORECARD） |
| csv | 8.6 → **9.0**（真流式） |
| json | 8.8 |
| toml | 8.6 |
| yaml | 8.0 |
| ini | 8.2 |
| xml | 7.8 → **8.2**（namespace 门面锁） |
