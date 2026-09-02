# Changelog — nextpas.core.agent

> 仅收录 `nextpas.core.agent` family 的面向 registry 的落地版本；通用 `core/CHANGELOG.md` 保留跨模块治理记录。

## agent-stage-review-fix-2026-09-01 — Stage Review P0/P1/P2 收口 (1 commit)

**Scope**: Stage Review 阻断与逻辑/文档契约收口——`CloneArray` 编译修复 + 预算/排水缺陷 + 传输拆分/门面白名单/会话4方法对齐。

### Commits (1, 本 lane)

| Hash | Type | Summary |
|------|------|---------|
| `e73722e91` | fix | `fold.pas:276 CloneArray` → `Copy` 编译修复，恢复 19 门编译 |
| `e73722e91` | fix | `loop.budget:LoopAccumulateUsage` 补 `ReasoningTokens` 累加 |
| `e73722e91` | fix | `loop.impl:GuidedFinish` 补 `AccumulateUsage` + `LoopAddOutUsed` + `UsageSink` 透传 |
| `e73722e91` | fix | `loop.exec:LoopFinalizeSlots` 预算涵盖 `skInvalid/skUnknown` 防绕过 |
| `e73722e91` | fix | `tools.pas` 排水加取消感知退出，防 `Timeout=0` 无限自旋 |
| `e73722e91` | docs | `ARCHITECTURE §2/§7` 传输三子域 + 韧性四件 + 定价/会话白名单补齐；`API.md` 4方法+`ReadIdleTimeoutMs`+`SESSION.md`对齐；`lane-focused` 新增 `agent` |

### Gates

- `test_assembly` 编译绿（`CloneArray` 修复）；`test_loop`/`test_tools` 预算/排水语义回归；`make hygiene` 绿。

## agent-sse-perf-2026-08-31 — sse Feed SIMD 跳扫 (1 commit)

**Scope**: sse 解析热路径性能优化——逐字节扫描 → simd 跳扫。

### Commits (1, 本 lane)

| Hash | Type | Summary |
|------|------|---------|
| `b4e827a13` | perf | sse Feed 主循环 SpanIndexOf SIMD 跳扫找 LF（bytes.ops → simd MemFindByte 分派），无 LF 大段直接跳过；循环外复用 TByteSpan view。同负载 A/B：sse-feed **98.13ms → 67.71ms（-31%，约 236 MB/s）**，超越冻结基线 92.3ms |

### Gates

- `test_sse` 13/13 全绿（HEAPTRC 门）；`test_loop` 19 / `test_provider_common` 11 / `test_codecs` 37 全绿。
- 注：`test_transport_stream` / `test_compile_skeleton` 受 worktree 外部脏文件 `compress.deflate`（未完成 zlib 重构）阻塞，agent 域零 compress 引用，待外部收敛后复跑。

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
| `c9bc0f520` | docs | Phase4 有界预算与高级感收口 — `PROMPT-BUDGET.md` + `PERFORMANCE.md §7` + `LIFECYCLE.md §8` + 双示例（`examples/gtd-grok-retry` / `examples/zen-gateway-codec`；CHANGELOG 旧称 07/08 为占位名，已对齐真实路径） |
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
- 新增 `examples/gtd-grok-retry` + `examples/zen-gateway-codec`（Phase4 高级感双示例；旧称 07/08 已更名为真实用例名，对应 `PROMPT-BUDGET.md §5` 有界快照与 `WIRE-MAPPINGS §3` 编解码器直通）。
- `PERFORMANCE.md §7` cookbook（Grapheme/EAW、StreamBox Lock+Done+id、SetLength+Move/PByte/InsertSort）与 `LIFECYCLE.md §8` 生命周期样板已对齐。

### External Alignment (C2-C4 + T3.1)

- **C2** `token888::billing` → `pricing.EstimateCost` 整数 μUSD 舍入（`billing:22,212`）+ `ImageTierOf` 2048×2048→2000 特判。
- **C3** `token888::PlatformQuota*` → `quota` 标量滚动（`86400/604800/2592000`，无 TConcurrentHashMap，O(1) 纯函数）。
- **C4** `code888` 韧性三件 → `resilience`（`StreamHasError`/`WaitCancelMs`/`ClampHintMs` K69-K75 反哺）。
- **T3.1** `pricing.EstimateCost` + `AgentEstimateTokens` + `IAgentUsageSink.RecordUsage` 估算透传（loop 每轮 nil 退化/吞异常不 raise）。

## agent-snapshot-streambox-2026-09-02 — 有界快照/流式盒复用面沉淀 (1 commit)

**Scope**: `snapshot`/`streambox` 复用面落地 + FPC RTL 解耦 + 文档对齐。

| Hash | Type | Summary |
|------|------|---------|
| `8aa6b84cd` | feat | 新增 `nextpas.core.agent.snapshot`/`streambox` + 门面透出 + `ARCHITECTURE §2/§7` 体积白名单 |
| `cb1b03f4f` | perf | 快照簇安全：`AgentUtf8SafeCutLen` 后向回退 + 前向 `GraphemeNext` 对齐 `👨‍👩‍👧/🇨🇳/1️⃣` |
| `bd862d297` | docs | `API.md §8.5/§10` 有界快照/流式盒契约 + 默认值总表 |

**Gates**: `test_compile_skeleton` 9 passed + 双示例离线可跑 + `make hygiene` pass。

## agent-snapshot-perf-2026-09-02 — 快照 ASCII 快路径 + test_snapshot 门 (1 commit)

**Scope**: 有界快照热路径与测试完整性收口。

| Hash | Type | Summary |
|------|------|---------|
| `fe975ed35` | perf | ASCII 快路径：前 `LCut` 全 `<$80` 时免 `GraphemeNext` 扫描；`API_COVERAGE §10` 同步 `test_snapshot` 5 测 |

**Gates**: `test_snapshot` 5 passed (`budget/utf8/cluster/ascii/tokens`) + `test_compile_skeleton` 9 passed + `make hygiene` pass。

## agent-streambox-perf-2026-09-03 — 流式盒环形队列 + 快照尾窗评估 (1 commit)

**Scope**: 流式盒去 O(n) 移位与快照簇对齐尾窗评估。

| Hash | Type | Summary |
|------|------|---------|
| `8f2677bf8` | perf | `streambox` 环形队列：`FHead` 游标 + 阈值压缩（`>64` 且过半时 `Move`），`TryPop` 摊销 O(1)，零语义回退；快照簇对齐保留 ASCII 快路径，6000 B 预算下全扫 <1µs，故保留全量前向扫描以保正确性（尾窗 128 B 评估后不引入） |

**Gates**: `test_snapshot` 5 passed + `test_compile_skeleton` 9 passed + `test_streambox` 隐式通过示例 + `make hygiene` pass。

## agent-streambox-fix-2026-09-03 — 环形队列托管修复 + 6 测门 (1 commit)

**Scope**: 托管泄漏修复与文档/测试闭环。

| Hash | Type | Summary |
|------|------|---------|
| `46ef5526c` | fix | `streambox` 托管修复：`Move` 绕过托管 → 逐项赋值+清零保引用计数；`PERFORMANCE §7.2` 同步 `TPlatformMutex`+`FHead`；`BENCHMARKS §2.4` 占位；`API_COVERAGE §11` 同步 `test_streambox` 6 测 |

**Gates**: `test_streambox` 6 passed + `test_snapshot` 5 passed + `test_compile_skeleton` 9 passed + `make hygiene` pass。

## agent-perfection-2026-09-03b — 六维匠心·hedge/定价/体积收口 (1 commit)

**Scope**: Stage Review 后 perfection 深打磨——溢出守卫/负值钳制/体积同步/inline 热点。

| Hash | Type | Summary |
|------|------|---------|
| `6efee4652` | fix | `hedge` DelayMs→ns 溢出钳制 `High div 1e6` + `pricing` 负 token 钳制 ` <0→0` + `snapshot` 首簇溢出空串分支 |
| `9e5c3c19d` | perf | `pricing` 三重载加 `inline`（`EstimateCost` 标量/Usage 两重载 inline 化，热点零分配） |
| `9889cc2f1` | test | `test_pricing` 负值钳制回归 + `test_hedge` `High(Int64)` 溢出守卫回归 |
| `d1d3125be` | docs | `ARCHITECTURE §2` 体积 13665→13687 同步（`provider.openai` 326/`responses` 256 精确化） |

**Gates**: `test_pricing` 6 passed + `test_hedge` 10 passed + `test_snapshot` 5 passed + `make hygiene` pass。

## agent-p0-perfection-2026-09-04 — P0 六维精修：预算/限流/SSE/loop 语义收口 (4 commits)

**Scope**: Stage Review P0 缺陷修复 + 文档/体积/门面对齐 — hvStop 全批阻断 + 限流阈值 + SSE 空值 + tool_call 预算 + skBlocked 计入 + 体积/CHANGELOG 同步。

| Hash | Type | Summary |
|------|------|---------|
| `9448d7718` | fix | P0 5 项：`loop.impl` hvStop 仅丢 allowance 内批（保留 CalledCount/Fire 一致） + `throttle` MaxAcquires>0 校验 + `sse` 无冒号行作空值 + `loop` 纯 tool_call 估算经 `LoopEstimateTokensFallback` + `loop.exec` skBlocked 计入预算 |
| `d3b4af3f1` | fix | `io.uring` 去重 `posix.base` 引入（`core` 层 debt 清理，`agent` lane 验证同步） |
| `42e845ef8` | refactor | `loop.impl` 清理未用 `SCount/Env` 变量（`AGENT.md` 悬垂变量规约） |
| `234f3ce4c` | fix | `loop.impl` 清理残留 `SCount` 赋值（`ARCHITECTURE` loop.impl 684→682 行，体积 13724→13722） |

**Gates**: `lane-focused --lane agent` 全绿（`555508 lines, 22.5 sec, 9 passed skeleton`，`build-hygiene=pass`，`make hygiene` 绿，`landing-check` path-limited 清零 `io.uring` debt）。

## agent-stage-review-p0-2026-09-05 — Stage Review P0/P1 深度收口（2 commits）

**Scope**: 编译门/预算同源/对冲链路/排水看门狗/配额回拨与溢出 + 体积/CHANGELOG 同步。

| Hash | Type | Summary |
|------|------|---------|
| `98e6ce2a6` | fix | P0/P1 6 项：`test_pricing/protocol/quota` 补 `base/json.value` uses（15 门全绿） + `loop.budget` LoopCostForMessage 增 provider 重载走 Fallback（与 LoopAddOutUsed 同源） + `hedge` 双路 CreateChildToken(LOuter) 链路化取消 + `tools` 排水 5s 看门狗 + `loop.impl` GuidedFinish 回滚污染 + `quota` 回拨过期+溢出钳制 |
| `c612fbbbe` | docs | `ARCHITECTURE §2` 体积 13722→13776（loop 152/690 hedge 581 tools 523 quota 186） |

**Gates**: `test_pricing 6` / `test_protocol 10` / `test_quota 5` / `lane-focused 9 skeleton` 全 `HEAPTRC OK`，`landing-check` 绿，完成 `for d in test_*; make test` 全量绿。
