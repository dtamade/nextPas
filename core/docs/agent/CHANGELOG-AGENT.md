# Changelog — nextpas.core.agent

> 仅收录 `nextpas.core.agent` family 的面向 registry 的落地版本；通用 `core/CHANGELOG.md` 保留跨模块治理记录。

## agent-feedback-2026-08-31 — 反哺收口 + 模块化拆分 (4 commits)

**Scope**: 字符串语义全收口 nextpas.core 门面、UTF-8 截断/字节切片反哺 text/bytes 单源、helpers 模块化拆分、两处基线缺陷修复。

### Commits (4, 本 lane)

| Hash | Type | Summary |
|------|------|---------|
| `e43d50051` | refactor | 反哺 UTF8SafeTruncate/BytesSliceToString 入 nextpas.core（text.utf8 零分配 CutLen + 门面 TextUTF8SafeCutLen/Truncate；bytes.ops BytesSliceToString；agent.textutil 收薄壳）+ 修复 FPC inline+字面量 Move 缺陷（text.utils Pad*/CopyStrToBuf）+ wire.pas IndexOfStr 0 基迁移回归（test_text +5 / test_provider_common +3） |
| `f4a602d39` | refactor | 字符串语义全收口门面 + IntToStr 显式限定（fold 5 处裸调用 → text.conv；helpers 3 处字符串 Copy → TextSlice/TextEndsWith；agent 域 IntToStr 21/21 显式、字符串 Copy 清零） |
| `c759c5518` | refactor | base.helpers 模块化拆分 — 槽位注册表/增量构建器独立成单元（新 `slotmap.pas` 145 行 + `deltabuilder.pas` 128 行，helpers 666→414 行纯函数，消费方零改动经 base 门面） |

### Gates (25/25 HEAPTRC, 5 bench)

- **HEAPTRC** 25/25 全绿（含 `test_codecs` 37 / `test_provider_anthropic` 29 / `test_loop` 19 / `test_provider_common` 11（溢出短语 0 基回归修复后）/ `test_sse` 13 / `test_agent_slot_registry` 6）。
- **Benchmarks** 同负载 A/B 对比（负载 32 下相对比较）：decode 164.6 vs 169.0 µs / encode 14.7 vs 16.1 µs / sse-feed 99.7 vs 99.7 ms — 无回归（冻结基线偏差系环境噪声，A/B 证伪）。
- **Docs sync**：本条目即 CHANGELOG 同步；`make hygiene` 绿。

### Volume (modularity)

- `base.helpers` 666→414 行（拆出 slotmap 145 + deltabuilder 128）；`nextpas.core.agent.base` 门面 re-export 指向新单元。
- agent 域 33 单元职责单一化完成度：helpers（纯函数）/ slotmap（槽位注册表）/ deltabuilder（增量构建器）三足分立。

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
