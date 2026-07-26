# config-formats 全族 SCORECARD（Wave T — 流式面差分 fuzz）

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

## B. Wave T 关闭项 — 流式面差分 fuzz

| 项 | 状态 |
|----|------|
| `test_csv_stream_fuzz`（chunked IReader 1/3/7 字节 vs 整串差分，5 tests） | Done |
| `test_xml_pull_fuzz`（TXmlReader pull vs DOM 先序差分，6 tests） | Done |

**痛点**：Wave S 只覆盖各格式整串 parse 面；家族两条真流式路径
（CSV chunked refill、XML pull）是独立代码路径、豁免 bulk cap/深度上限，
恰恰零 fuzz。**oracle 升级**：从"不崩溃"弱断言升级为差分测试——
同一输入两条路径结果必须逐字节一致（CSV：行/字段/错误状态全等；
XML：start/empty 元素先序序列全等），refill 边界撕裂（引号/CRLF 跨
chunk）与两面不一致直接变断言失败。

关键覆盖：引号转义对/CRLF 逐字节跨 chunk 酷刑；深度豁免两面验证
（600 层 DOM 拒 512 上限 / pull 完整读完，5000 层证无隐藏递归）；
失配/孤儿闭合标签 pull in-band 报错。两套件 11 tests 全绿、
诚实通道 exit=0 + pin 命中。**flip check 双向验证有牙**：chunked 路
悄悄丢 1 字节 → CSV 差分红；漏计 empty 元素 → XML 差分红 2 测试。
零新缺陷 = 流式/整串两面实现一致性的独立证据。
发现（契约确认非缺陷）：`TCsvReader` 默认执行字段数一致性校验
（"Wrong number of fields"，Go encoding/csv 语义），首行定列数。

---

## B2. Wave S 关闭项（历史）

| 项 | 状态 |
|----|------|
| `test_csv_fuzz`（in-band 契约 + 引号酷刑 + writer→parser 往返 100 轮） | Done |
| `test_ini_fuzz`（Try 契约 + 结构洪水 + write→reparse 往返 100 轮） | Done |
| `test_json_fuzz`（in-band 契约 + 600 层深度洪水 + Stringify 幂等） | Done |
| `test_yaml_fuzz`（in-band 契约 + 300 层 flow 洪水 + 锚点/别名碎片） | Done |
| `test_xml_fuzz`（Try 契约 + `Root.Text` 消费面 + 实体/标签碎片） | Done |

全部套件复用 `test_toml_fuzz` 的确定性 xorshift32 模式（seed=12345，
失败可复现）：随机 / 二进制垃圾 / 半合法 / 重复结构 / 大文档五路 +
模块特色攻击路。5 套件 33 tests 全绿、heaptrc 0 泄漏。fuzz 覆盖
1/7（仅 toml）→ 6/7；config 为 DOM 聚合层，输入面由底层各格式
parser fuzz 覆盖，插值环已有专测（`test_config` cycle 两测试）。
本轮 fuzz 未挖出新缺陷 = Wave R 防线的独立验证。

### Wave S 附录：heaptrc 泄漏门禁真空 + 诚实通道验证

**发现（2026-07-26）**：FPC trunk 3.3.1 heaptrc 有泄漏时进程仍 exit=0，
`common.mk` 的 `test: run` 永不因泄漏失败——`-gh` 只产出 dump，不构成门禁。
"0 泄漏" 若只看 make 绿灯，是不可证伪的口头声明。

**诚实通道**：`HEAPTRC='haltonnotreleased,log=<file>'` 环境变量下，
泄漏 → exit=203 + dump 落文件；干净 → exit=0 + dump 含
`0 unfreed memory blocks : 0`（该 pin 同时证明 heaptrc 确实运行了，fail closed）。

**证据（host-linux，lane HEAD）**：家族 7 个二进制全部通过诚实通道：

| 套件 | exit | pin `0 unfreed` |
|------|------|------------------|
| test_csv_fuzz / test_ini_fuzz / test_json_fuzz / test_yaml_fuzz / test_xml_fuzz | 0 | ✅ |
| test_toml_fuzz | 0 | ✅ |
| test_config | 0 | ✅ |

**Follow-up**：math lane（`codex/math-simd` c1dbdfe26）已为 `common.mk` 加
opt-in `HEAPTRC_GATE=1` 同款机制；落 main 后本家族套件直接接线即可，
本 lane 不重复改 `common.mk`（避免合并冲突）。在此之前，泄漏声明以
本节诚实通道复跑为准。

---

## C. Wave R 关闭项（历史）

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

## D. Wave Q 关闭项（历史）

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

## E. PARITY 指针

| 模块 | 综合（Wave S） | fuzz |
|------|----------------|------|
| config | **9.5** | 间接（底层 parser + 插值环专测） |
| json | **9.3**（Get/IsFloat） | ✅ Wave S |
| toml | **9.2** | ✅（先行） |
| yaml/csv | **9.2** | ✅ Wave S |
| ini | **9.2**（fs I/O） | ✅ Wave S |
| xml | **9.2**（深度防线） | ✅ Wave S |

**Steady**：Schema / XPath / YAML multi-doc / 真流式 JSON 仍 Out of scope。
