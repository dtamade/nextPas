# config-formats 全族 SCORECARD（Wave L）

**truth**：`host-linux` 单机快照（2026-07-20）
**lane**：`config-json-xml-toml-yaml-csv-ini`

---

## A. Wave L focused 代表路径（本波实测）

```bash
make focused FOCUS=core/tests/nextpas.core.config/test_config_facade_surface
make focused FOCUS=core/tests/nextpas.core.ini/test_ini_facade_surface
make focused FOCUS=core/tests/nextpas.core.xml/test_xml_facade_surface
make hygiene
```

| 套件 | 结果 |
|------|------|
| config facade_surface | **9 passed**（ByteSize + watcher auto） |
| ini facade_surface | **6 passed**（IReader） |
| xml facade_surface | **3 passed**（IReader） |
| hygiene | **pass** |

---

## B. Wave L 关闭项

| 项 | 状态 |
|----|------|
| TConfigWatcher 无格式 Create | Done（reload 走 sniff） |
| GetByteSize / KiB 进制 | Done |
| IniParse(IReader) | Done |
| XmlParse / XmlParseDoc(IReader) | Done |
| 低分模块 PARITY 升分 | Done |

---

## C. PARITY 综合指针（Wave L）

| 模块 | 综合 |
|------|------|
| config | **9.1** |
| json | **9.0** |
| csv | **9.0** |
| toml | **9.0** |
| ini | **9.0** |
| yaml | **8.8** |
| xml | **8.6** |

**全族 Essential 路径**（config + 四格式 + ini/csv/xml 门面）均 ≥ 8.6；config/json/csv/toml/ini 达 9.0 线。
