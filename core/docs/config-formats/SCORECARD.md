# config-formats 全族 SCORECARD（Wave R — 递归/深度防线收口）

**truth**：`host-linux`
**lane**：`config-json-xml-toml-yaml-csv-ini`
**日期**：2026-07-26

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

## B. Wave R 关闭项

| 项 | 状态 |
|----|------|
| 全族递归/深度攻击面摸排（parse/writer/builder/stringify/Text） | Done |
| XML DOM 深度上限 `XML_MAX_NESTING_DEPTH=512`（修复深树 `Text` SIGSEGV） | Done |
| 空元素按父级+1 计深（边界两面测试） | Done |
| 200k 深度攻击回归测试（fail fast，1.01s→6ms） | Done |
| 家族深度矩阵入 README（json 512 / yaml 256 / toml 128 / xml 512） | Done |
| xml CONTRACT INV-4 | Done |

摸排结论（无需改动）：json parse 512 + writer 512 栈已测；yaml parse 256 +
alias 环拒绝 + builder 栈 raise；toml parse 128 + writer 可增长迭代栈；
csv/ini 扁平；xml writer 可增长迭代栈；`Stringify` 返回原始输入无递归。

---

## C. Wave Q 关闭项（历史）

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

## D. PARITY 指针

| 模块 | 综合（Wave R） |
|------|----------------|
| config | **9.5** |
| json | **9.3**（Get/IsFloat） |
| yaml/toml/csv | **9.1–9.2** |
| ini | **9.2**（fs I/O） |
| xml | **9.2**（深度防线） |

**Steady**：Schema / XPath / YAML multi-doc / 真流式 JSON 仍 Out of scope。
