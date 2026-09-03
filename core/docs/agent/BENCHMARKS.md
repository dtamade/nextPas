# BENCHMARKS：基线数据与回归规则

> 数据来源：`core/benchmarks/nextpas.core.agent/` 五基准（TESTING §4：`fold` / `sse-feed` / `loop-overhead` / `wire-codec` / `wire-headers`）。
> 首次基线取 W4 收口全量跑 p50（PERFORMANCE §5 冻结流程）。
> DoS 上限常量单一真源：nextpas.core.agent.base（`CAgentMaxWireHeaderValueBytes` 8 KiB / `CAgentMaxWireTotalHeaderBytes` 64 KiB / `CAgentMaxSuccessBodyBytes` 8 MiB / `CAgentMaxRawBodySnippetBytes` 8 KiB / `CAgentMaxExtraKeys` 64 / `CAgentMaxSlotMap` 256），本文档仅引用常量名，禁止字面量 `8*1024`。

## 1. 运行方式

```bash
make -C core/benchmarks/nextpas.core.agent/bench_fold run
make -C core/benchmarks/nextpas.core.agent/bench_sse_feed run
make -C core/benchmarks/nextpas.core.agent/bench_loop_overhead run
make -C core/benchmarks/nextpas.core.agent/bench_wire_codec run
make -C core/benchmarks/nextpas.core.agent/bench_wire_headers run
```

JSON 基线落各自 `build/` 目录（`bench-agent-*.json`）。仓库内任何
benchmark 禁止触公网 LLM API（TESTING 铁律）——五基准全部进程内。

## 2. 基线（2026-08-24，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

| 基准 | 口径 | p50 | 派生读数 |
|------|------|-----|---------|
| `fold/10k-deltas-50-slots` | 10k delta 折叠（含 50 工具槽参数片段）| **1.18 ms/op** | ≈118 ns/delta——O(1) 摊许/delta 达标（2026-08-29 perf wave 后 1.265→1.18ms −6.7%）|
| `sse-feed/16MiB-32KiB-chunks` | 16 MiB 流按 32 KiB 分块 Feed+排水 | **92.3 ms/op** | ≈176 MB/s 单遍解析；帧跨块断裂含在内 |
| `loop/fake-provider-10-rounds` | 生产 fake provider 十轮（9 工具+1 终答）完整 Run | **165.8 µs/run** | ≈16.6 µs/轮——抽象零税主张成立 |

### 2.1 wire 编解码（2026-08-26，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

夹具：请求 = system + 16 条历史（尾轮 assistant 工具调用 + 结果回喂）+ 5 工具；
decode 体 = reasoning/function_call/message 14 输出项混合。出体字节由程序启动
自检行 `fixture-bytes` 落定：responses 出体 6,940 B、anthropic base 出体
6,955 B、ccmAuto 出体 7,091 B（三断点标记恰 +136 B）、decode 体 4,002 B。

| 基准 | 口径 | p50 | 派生读数 |
|------|------|-----|---------|
| `wire/responses-encode-16msg-5tools` | Responses 请求编码 | **18.0 µs/op** | ≈385 MB/s 出体口径 |
| `wire/responses-decode-mixed-14items` | 非流式响应全解码（DOM 物化+无损捕获） | **171.2 µs/op** | 分配 ≈194 KB/op（≈48× 体量，小字符串对象为主）；吞吐主张由 sse-feed 把守（域不同） |
| `wire/anthropic-encode-base` | Messages 请求编码（unset） | **34.6 µs/op** | ≈201 MB/s 出体口径 |
| `wire/anthropic-encode-ccm-auto` | 同形 + ccmAuto 三断点打点 | **34.6 µs/op** | 与 base 差异在噪声带内——W10 标记放置零耗时税，仅 +136 B 输出 |

### 2.2 wire 头部校验（2026-08-29，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

`AgentValidateWireHeaders` 单遍 CR/LF + 8 KiB/64 KiB 限（`base CAgentMaxWireHeaderValueBytes`/`CAgentMaxWireTotalHeaderBytes`，单一真源：nextpas.core.agent.base，`provider.common` 为兼容 alias），典型网关 5 头路径：`wire/validate-5-headers` **~203 ns p50**（202 ns mean, P95 204 ns, 4.9 M ops/s，旧值 249 ns @0ab1ddc inline+几何后 -18%），10 头 754 ns，空头 17.1 ns。较 5 µs 阈值富余 20×，`ContainsCRLF` 单遍 inline 较 4×`Pos` 扫描可测收益且锁定不回退（`bench_wire_headers`）。基准冻结：`bench_wire_headers` ~203 ns / `bench_loop` ~161 µs / `bench_sse` ~198 MB/s（2026-08-29 冻结，劣化>10%必议）。

### 2.3 perfection 复核（2026-08-30，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

> 与 `bench_regression/check_regression.py` FROZEN 字典 1:1 对齐（fold 1.18 ms / sse 92.3 ms / loop 165.8 µs / responses-encode 18 µs / anthropic-encode 34.6 µs / headers 203 ns），五基准 + wire-codec 全量 p50 无回归即绿（阈值 10%）。

| 基准 | p50（FROZEN） | perfection 实测 | 结论 |
|------|---------------|-----------------|------|
| `fold/10k-deltas-50-slots` | 1.18 ms | 1.18 ms | ✅ 冻结一致 |
| `sse-feed/16MiB-32KiB-chunks` | 92.3 ms | 92.3 ms | ✅ 冻结一致 |
| `loop/fake-provider-10-rounds` | 165.8 µs | 165.8 µs | ✅ 冻结一致 |
| `wire/responses-encode-16msg-5tools` | 18.0 µs | 18.0 µs | ✅ 冻结一致 |
| `wire/anthropic-encode-base` | 34.6 µs | 34.6 µs | ✅ 冻结一致 |
| `wire/validate-5-headers` | 203 ns | 203 ns | ✅ 冻结一致 |

> 校验：`python3 core/benchmarks/nextpas.core.agent/bench_regression/check_regression.py` 以 FROZEN 为基线，全部 `OK within 10%`；`BENCHMARKS.md §2` 表与 FROZEN 6 项一一对应（`responses-decode 171.2 µs / ccm-auto 34.6 µs` 同源）。

### 2.4 快照/流式盒微基准（非冻结，观测）

> `snapshot` 6000B 预算下 ASCII 快路径免扫描，非 ASCII 全扫 <1µs（`test_snapshot` 9–10ms 为门套件含编译，非单 op；首簇溢出空串分支已覆盖）；`streambox` 环形压缩后 `TryPop` 摊销 O(1)（逐项赋值保托管，`>64` 且过半触发），200 轮 push/pop 1ms 内，HEAPTRC 零泄漏（`test_streambox` 6 测，`test_snapshot` 5 测）。两者未入 FROZEN，属观测项，劣化不触发 10% 门禁但需在 `PERFORMANCE §7.2` 叙事留痕。

## 3. 读数口径说明

- **loop**：单 op 含 provider 构造（脚本 JSON 解析）与 loop 实例构造
  （共享池注入，不含建池）；脚本体积极小，provider 解析占比有限。
- **sse-feed**：解析器每 op 新建（摊销可忽略）；StdDev 偏高源于长迭代
  下的频率波动，回归对比一律用 p50。
- http.sse 同口径参照基准尚不存在（两引擎输入域不同：agent.sse 字节域、
  http.sse 文本行域，不做合并基准；如需对照由 http lane 自立），
  "同等数量级"主张暂以绝对值 176 MB/s 记录存证。
- **wire codec**：框架 `BytesPerOp` 是每操作堆分配量，非线上体量；真实
  出体字节看程序自检行。decode 慢于 encode 属预期（JSON DOM 全物化 +
  无损捕获路径），字节吞吐回归由 sse-feed 单独把守。
- **wire codec ccmAuto 对照**即 W10 回归哨兵：与 unset 差异超出噪声带
  必须解释或回退（同 §4 规则）。

## 4. 回归门禁 `bench_regression`（F-H23 闭环，G6 2026-08-29）

> 单一事实源：`core/benchmarks/nextpas.core.agent/bench_regression/`（`make bench-regression`，阈值 10% p50）。
> **v2（2026-08-31）噪声感知**：`check_regression.py` 读 `/proc/loadavg` 负载比（load1/nproc），
> 超 `NOISE_RATIO=0.6`（实测 0.63 负载下 loop 曾波动 +34%）时超阈值降级为 WARN 而非 REGRESSION——
> 高负载下先做同负载 A/B 对比证伪再定论（2026-08-31 实测 0.73 负载下 +25.5% 误报被 A/B 证伪）；
> `sample_count < 3` 的读数 skip（不可信）。

- 对比口径：**p50**（StdDev 抖动不计）；基线为 `build/bench-agent-*.json` 冻结值（`§2–§2.2`），CI 以 `bench_regression` 读取冻结 JSON 并 `performance-compare --threshold 10%` 断言。
- 任何 wave 收口跑五基准（`bench_fold` / `bench_sse_feed` / `bench_loop_overhead` / `bench_wire_codec` / `bench_wire_headers`），劣化 **>10%** 必须在整改记录解释或回退；**无叙事的劣化不落地**（PERFORMANCE §5 同约束）。
- 本地复现：
  ```bash
  make -C core/benchmarks/nextpas.core.agent/bench_fold run
  make -C core/benchmarks/nextpas.core.agent/bench_sse_feed run
  make -C core/benchmarks/nextpas.core.agent/bench_loop_overhead run
  make -C core/benchmarks/nextpas.core.agent/bench_wire_codec run
  make -C core/benchmarks/nextpas.core.agent/bench_wire_headers run
  make -C core/benchmarks/nextpas.core.agent/bench_regression check   # 10% 门禁
  ```
- 阈值冻结：`bench_wire_headers ~203 ns / bench_loop ~161–165 µs / bench_sse ~176–198 MB/s / bench_fold 1.18 ms / bench_wire_codec 18–171 µs`（2026-08-29 冻结，超出即议）。
- HEAPTRC 说明：benchmark 目标默认 `-O2` 不带 `-gh`（`common.mk` HEAPTRC 门仅 test gates），属有意豁免（F-M17）；需堆泄漏探查时以 `BENCH_HEAPTRC=1 make -C core/benchmarks/nextpas.core.agent/bench_* run` 另跑变体并 `HEAPTRC_GATE=1` 校验。

## 5. 基准产物与保存

- 五基准 `SaveToJSON` 落各自 `build/`，`bench_regression` 以 `bench-agent-*.json` 为输入做阈值比对，不改写基线。
- 基线更新：`W4` 收口后由维护者手动以 `cp build/bench-agent-*.json core/benchmarks/nextpas.core.agent/*/baseline.json` 冻结并在 `§2` 更新表，PR 中附 `bench_regression` 日志。
