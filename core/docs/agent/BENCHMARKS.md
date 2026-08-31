# BENCHMARKS：基线数据与回归规则

> 数据来源：`core/benchmarks/nextpas.core.agent/` 四基准（TESTING §4）。
> 首次基线取 W4 收口全量跑 p50（PERFORMANCE §5 冻结流程）。

## 1. 运行方式

```bash
make -C core/benchmarks/nextpas.core.agent/bench_fold run
make -C core/benchmarks/nextpas.core.agent/bench_sse_feed run
make -C core/benchmarks/nextpas.core.agent/bench_loop_overhead run
make -C core/benchmarks/nextpas.core.agent/bench_wire_codec run
```

JSON 基线落各自 `build/` 目录（`bench-agent-*.json`）。仓库内任何
benchmark 禁止触公网 LLM API（TESTING 铁律）——四基准全部进程内。

## 2. 基线（2026-08-24，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

| 基准 | 口径 | p50 | 派生读数 |
|------|------|-----|---------|
| `fold/10k-deltas-50-slots` | 10k delta 折叠（含 50 工具槽参数片段）| **1.265 ms/op** | ≈127 ns/delta——O(1) 摊许/delta 达标 |
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

## 4. 回归规则（PERFORMANCE §5）

- 对比口径：p50。
- 任何 wave 收口跑三基准，劣化 **>10%** 必须在整改记录解释或回退；
  无叙事的劣化不接受。
