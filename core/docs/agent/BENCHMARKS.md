# BENCHMARKS：基线数据与回归规则

> 数据来源：`core/benchmarks/nextpas.core.agent/` 三基准（TESTING §4）。
> 首次基线取 W4 收口全量跑 p50（PERFORMANCE §5 冻结流程）。

## 1. 运行方式

```bash
make -C core/benchmarks/nextpas.core.agent/bench_fold run
make -C core/benchmarks/nextpas.core.agent/bench_sse_feed run
make -C core/benchmarks/nextpas.core.agent/bench_loop_overhead run
```

JSON 基线落各自 `build/` 目录（`bench-agent-*.json`）。仓库内任何
benchmark 禁止触公网 LLM API（TESTING 铁律）——三基准全部进程内。

## 2. 基线（2026-08-24，Linux x86_64 44 核，FPC 3.3.1 trunk，-O2）

| 基准 | 口径 | p50 | 派生读数 |
|------|------|-----|---------|
| `fold/10k-deltas-50-slots` | 10k delta 折叠（含 50 工具槽参数片段）| **1.265 ms/op** | ≈127 ns/delta——O(1) 摊许/delta 达标 |
| `sse-feed/16MiB-32KiB-chunks` | 16 MiB 流按 32 KiB 分块 Feed+排水 | **92.3 ms/op** | ≈176 MB/s 单遍解析；帧跨块断裂含在内 |
| `loop/fake-provider-10-rounds` | 生产 fake provider 十轮（9 工具+1 终答）完整 Run | **165.8 µs/run** | ≈16.6 µs/轮——抽象零税主张成立 |

## 3. 读数口径说明

- **loop**：单 op 含 provider 构造（脚本 JSON 解析）与 loop 实例构造
  （共享池注入，不含建池）；脚本体积极小，provider 解析占比有限。
- **sse-feed**：解析器每 op 新建（摊销可忽略）；StdDev 偏高源于长迭代
  下的频率波动，回归对比一律用 p50。
- http.sse 同口径参照基准尚不存在（ROADMAP inbox：agent.sse 反哺晋升
  后补齐），"同等数量级"主张暂以绝对值 176 MB/s 记录存证。

## 4. 回归规则（PERFORMANCE §5）

- 对比口径：p50。
- 任何 wave 收口跑三基准，劣化 **>10%** 必须在整改记录解释或回退；
  无叙事的劣化不接受。
