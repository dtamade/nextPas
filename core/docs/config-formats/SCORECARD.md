# config-formats 全族 SCORECARD（Wave N Steady+）

**truth**：`host-linux`
**lane**：`config-json-xml-toml-yaml-csv-ini`

---

## A. 一键门禁

```bash
bash core/docs/config-formats/scripts/run-facade-gates.sh
```

---

## B. Wave N focused 实测

| 套件 | 结果 |
|------|------|
| config facade_surface | **10 passed**（DebugDump 含于 clone/merge） |
| config examples | startup markers section/duration/bytesize/clone/dump |
| hygiene | **pass** |

---

## C. Wave N 关闭项

| 项 | 状态 |
|----|------|
| ConfigDebugDump 排序诊断 | Done |
| startup example DX 标记 | Done |
| 全族 9.0 Steady 巩固 | Done |

---

## D. PARITY 综合指针

| 模块 | 综合 |
|------|------|
| config | **9.3** |
| json / yaml / toml / csv / ini / xml | **9.0** |

**Steady 线**：Essential 路径已齐；remote / Schema / XPath / YAML multi-doc 接受仍 Out of scope。
