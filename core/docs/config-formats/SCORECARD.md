# config-formats 全族 SCORECARD（Wave M）

**truth**：`host-linux` 单机快照（2026-07-20）
**lane**：`config-json-xml-toml-yaml-csv-ini`

---

## A. 一键门禁

```bash
# from repo root
bash core/docs/config-formats/scripts/run-facade-gates.sh
```

门禁列表：config/json/yaml/toml/csv/ini/xml facade_surface + json edge_cases。

---

## B. Wave M focused 实测

| 套件 | 结果 |
|------|------|
| yaml facade_surface | **4 passed**（feature matrix） |
| xml facade_surface | **4 passed**（CDATA/entity/default-ns） |
| config facade_surface | **10 passed**（Clone/Merge） |
| hygiene | **pass** |

---

## C. Wave M 关闭项

| 项 | 状态 |
|----|------|
| YAML config 子集矩阵 + multi-doc/merge-key 严格锁 | Done |
| XML CDATA/entity/default-ns facade | Done |
| TConfig.Clone / MergeFrom | Done |
| 族门禁脚本 | Done |

---

## D. PARITY 综合指针（Wave M）

| 模块 | 综合 |
|------|------|
| config | **9.2** |
| json | **9.0** |
| yaml | **9.0** |
| toml | **9.0** |
| csv | **9.0** |
| ini | **9.0** |
| xml | **9.0** |

**全族 ≥ 9.0**（config 消费路径）。仍明确 Out of scope：remote、JSON Schema/Pointer/Patch、XPath/XSD、YAML 1.2 全量与 multi-doc 接受。
