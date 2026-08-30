# Changelog — nextpas.core.agent

> 仅收录 `nextpas.core.agent` family 的面向 registry 的落地版本；通用 `core/CHANGELOG.md` 保留跨模块治理记录。

## agent-perfection-2026-08-30 — registry:stable completeness (W18 docs)

**Scope**: W14–W18 六维收口精化 + W18 landing docs 定版（docs only，本 wave 无 src 增量，仅文档与体积/基线对齐）。

### Commits (4, 本 lane)

| Hash | Type | Summary |
|------|------|---------|
| `84876646c` | fix | Phase1 纯策略吸收 — pricing/quota/estimate/sink/idempotency（`token888::billing/PlatformQuota` 复刻，`AgentEstimateTokens`/`EstimateCost`/`PlatformQuota*`/`AgentWireApplyIdempotency` 单一真源） |
| `53ab417e8` | refactor | 模块化 openai + responses — 抽 encode/decode/decoder 三子域（4/4，完成 openai 326/348/232/359 + responses 256/307/245/441 全 <800） |
| `c9bc0f520` | docs | Phase4 有界预算与高级感收口 — `PROMPT-BUDGET.md` + `PERFORMANCE.md §7` + `LIFECYCLE.md §8` + 双示例（`examples/07_bounded_snapshot` / `examples/08_stream_box_lifecycle`） |
| `1a831086d` | refactor | 模块化 provider.common — 抽 wire/extra/slots 三子域（3/3，完成 common 291+565+109+519 全 <800） |

### Gates (21/21 HEAPTRC, 5 bench)

- **HEAPTRC** 21/21：`test_protocol` / `test_sse` / `test_transport_stream` / `test_provider_openai` / `test_provider_anthropic` / `test_provider_responses` / `test_provider_common` / `test_codecs` / `test_tools` / `test_loop` / `test_retry` / `test_fallback` / `test_throttle` / `test_hedge` / `test_transport_trace` / `test_session` / `test_clock` / `test_compile_skeleton` / `test_security` / `test_agent_slot_registry` / `test_e2e_live`(opt-in) 全 `HEAPTRC_GATE=1` 零泄漏。
- **Benchmarks** 5/5：`bench_fold` 1.18 ms / `bench_sse_feed` 92.3 ms (≈176 MB/s) / `bench_loop_overhead` 165.8 µs / `bench_wire_codec` responses-encode 18 µs + anthropic-encode 34.6 µs + decode 171.2 µs / `bench_wire_headers` 203 ns（5 头 p50）— 与 `bench_regression/check_regression.py` FROZEN 1:1，阈值 10% 内 `OK`。
- **Docs sync**：`ARCHITECTURE.md §2` 体积指引 + `BENCHMARKS.md §2.3` perfection 复核 + `README.md` PROMPT-BUDGET 索引已对齐；`make hygiene` 绿。

### Volume (completeness, provider 14/14 <800)

- `provider.common` 291+565+109+519 / `provider.openai` 326/348/232/359 / `provider.openai.responses` 256/307/245/441 / `provider.anthropic` 397+449+196+332（含 `fake` 386）—— provider 域 14/14 <800 全达标。
- `base` 1177 / `loop` 994 为受控例外（词表/循环为稳定聚合点，增量受限、监控行数不回落即零增量承诺），`ARCHITECTURE.md §2` 单独标注。
- 表内行数与 `wc -l core/src/nextpas.core.agent.*.pas` 实测同步。

### Docs & Examples (W18 completeness)

- 新增 `PROMPT-BUDGET.md`（6000 B 有界快照：`AgentBuildSystemText` 合并去重 + `AgentEstimateTokens` 加权粗估 + `AgentUtf8SafeTruncate`/`GraphemeNext` 簇安全截断 + `pricing.EstimateCost` 联动 + `IAgentTokenCounter` 探测）。
- 新增 `examples/07_bounded_snapshot` + `examples/08_stream_box_lifecycle`（Phase4 高级感双示例）。
- `PERFORMANCE.md §7` cookbook（Grapheme/EAW、StreamBox Lock+Done+id、SetLength+Move/PByte/InsertSort）与 `LIFECYCLE.md §8` 生命周期样板已对齐。

### External Alignment (C2-C4 + T3.1)

- **C2** `token888::billing` → `pricing.EstimateCost` 整数 μUSD 舍入（`billing:22,212`）+ `ImageTierOf` 2048×2048→2000 特判。
- **C3** `token888::PlatformQuota*` → `quota` 标量滚动（`86400/604800/2592000`，无 TConcurrentHashMap，O(1) 纯函数）。
- **C4** `code888` 韧性三件 → `resilience`（`StreamHasError`/`WaitCancelMs`/`ClampHintMs` K69-K75 反哺）。
- **T3.1** `pricing.EstimateCost` + `AgentEstimateTokens` + `IAgentUsageSink.RecordUsage` 估算透传（loop 每轮 nil 退化/吞异常不 raise）。
