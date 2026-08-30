# ROADMAP-FINAL：v1.0 收口最终路线图

> 本文档是 `ROADMAP.md` W0–W13 之后的**最终收口计划**。W13 之前为已落地波次，W14 起为收口波次；每波次单独 worktree、单独 gate、单独 landing，未齐不进主线。目标：以“性能·高级感·复用度·稳定性·完整性”五维齐平为准绳，达成 `agent` family 的 `registry: stable` 首个语义化版本。

## 0. 顶层原则

- **单一真源**：词表（`nextpas.core.agent.base`）、错误码（`TAgentErrorCode`）、常量（阈值/超时/上限）只在一处定义，门面 `nextpas.core.agent` 只做 `inline` 透出。
- **分层铁律**：`base ← errors ← intf ← fold/sse/tools/provider/loop/session ← 门面`，只向下依赖，禁止同层循环。
- **协议无关**：`loop/tools/session` 只见 `IAgentProvider` / `TCompletionRequest` / `TMessage`，永不触 wire 类型；厂商差异在 `provider.*` 内归约，`fold/sse` 纯词表变换。
- **零网关口径**：仓库内任何 test/example/bench 禁触公网；真网验证仅 `test_e2e_live` opt-in 门。
- **worktree 纪律**：一模块一 lane，`main` 仅总控 landing；跨模块改动需跨域审计与双重 gate。

---

## 1. 现状基线（W13 已落地）

| 能力 | 状态 | 代表 gate |
|------|------|-----------|
| 词表/错误/接缝/fold/sse/transport | ✅ | `test_protocol` `test_sse` `test_transport_stream` |
| OpenAI / Anthropic / Responses / Grok / Fake | ✅ | `test_provider_openai` `test_provider_anthropic` `test_provider_responses` `test_codecs` |
| Clock / Retry / Fallback / Throttle / Hedge / Trace / TokenCounter | ✅ | `test_clock` `test_retry` `test_fallback` `test_throttle` `test_hedge` `test_transport_trace` |
| Tools / Loop（预算/截断/防打转/钩子/事件/引导收尾） | ✅ | `test_tools` `test_loop` |
| Session JSONL / Structured Output / tool_choice / ReasoningEffort / CacheControl | ✅ | `test_session` `test_provider_*` 扩展 |
| Wire 头部纵深消毒（空名/CR-LF/8 KiB/64 KiB，provider+transport 双卫句，协议无关 `wire header` 前缀，门面一站式） | ✅ 已落地 | `test_transport_stream` 5×3 矩阵 9 passed |
| 基准五件套 | ✅ | `bench_fold` `bench_sse_feed` `bench_loop_overhead` `bench_wire_codec` `bench_wire_headers` |

**已验证基线**：`test_transport_stream` 9 passed / `test_provider_openai` 28 passed / `test_provider_anthropic` 29 passed / `test_loop` / `test_tools` 8 passed / `test_sse` 13 passed / `test_security` 8 passed 全部 HEAPTRC OK，`make hygiene` pass。

---

## 2. W14 — Wire 纵深与门面收口（✅ 已落地，2 周）

> 目标：把“网关 QPS 下的安全与复用”钉死为不可回退不变量。

| 项 | 交付 | 设计点 | 出口证据 |
|----|------|--------|---------|
| W14.1 wire 头部单源化 ✅ 已落地 | `provider.common.AgentValidateWireHeaders` + `CAgentMaxWireHeaderValueBytes/_Total` 单一常量源，`ContainsCRLF` 单遍 inline | `transport.http` 与 `AgentWireAddOpenAI/AnthropicHeaders` / `AgentWireAppendExtraHeaders` 共用 | `test_transport_stream` 5×3 矩阵绿 |
| W14.2 协议无关报文 ✅ 已落地 | `wire header: …` / `wire total headers …` 前缀，消 `http transport:` 层渗漏 | 错误码保持 `aecProtocol`，归因不变 | 报文快照 grep `wire` 绿 |
| W14.3 门面一站式 ✅ 已落地 | `nextpas.core.agent.AgentValidateWireHeaders` inline 透出，与 `MessageText/WireHeaderValue/MergeExtraJson/AgentTruncate*` 对齐 | 免破层 `uses provider.common` | `test_compile_skeleton` facade 转发绿 |
| W14.4 文档同频 ✅ 已落地 | `API.md` Defaults 表指向 `provider.common` | 单源 ↔ 文档 ↔ 常量三同频 | `docs/agent` diff 绿 |

**已落地**：三提交 + 矩阵扩至 5×3 已于本波次完成，剩余为文档阈值表阈值锚定陈述。W14.1-14.4 均 ✅ 已落地（wire 单源、报文协议无关、门面透出、文档同频）。

---

## 3. W15 — 性能深优（Performance，✅ 已落地，2 周）

> 口径：`PERFORMANCE.md` §1–§4 热路径契约 + `BENCHMARKS.md` 基线，劣化 >10% 必须解释或回退。

| 项 | 手段 | 目标 | 锚定 bench |
|----|------|------|------------|
| W15.1 ReadAllBody 零堆 ✅ 已落地 | `LBuf: array[0..32K-1] of Byte` 栈数组 + `CInitialCapBytes=8K` + 收口零拷贝 | 网关 QPS 下 8 KiB 典型体零堆 | `bench_wire_codec` 辅检 |
| W15.2 Truncate 单遍单拷 ✅ 已落地 | `AgentTruncateLines` 单遍计数 + `AgentTruncateEnvelope` 单拷贝双阈值融合 | 大工具结果截断路径零中间分配 | `bench_loop_overhead` |
| W15.3 MergeExtraJson 几何预留 ✅ 已落地 | `LCap 8→*2` 消逐键重分配 | gateway 侧 `ExtraJson` 合并 O(1) 摊销 | `bench_wire_codec` |
| W15.4 AddRange 批量预留 ✅ 已落地 | `TAgentDeltaBuilder.AddRange` 一次预留 | 解码器突发 delta 批量 | `bench_sse_feed` |
| W15.5 SSE 阈值压实 ✅ 已落地 | `Feed` 4 KiB/半缓冲阈值压实，零搬运 | 16 MiB 流行缓冲外零常驻 | `bench_sse_feed` MB/s ≥176 不回退 |
| W15.6 头部校验单遍 ✅ 已落地 | `ContainsCRLF` 单遍循环替 4×`Pos` | 每请求 3–5 头微优可测 | `test_transport_stream` 计时无回退 |

**本波次增量**：
- W15.7 `bench_wire_headers` 新增 ✅ 已落地：1k 组 `AgentValidateWireHeaders(5 headers)` 吞吐，阈值 `p50 < 5µs`（实测 ~203 ns，旧值 249 ns @0ab1ddc inline+几何后 -18%，BENCHMARKS §2.2 2026-08-29 冻结），锁定单遍优化不回退。
- W15.8 `ReadAllBody` 8 MiB 封顶与 `AgentValidateWireHeaders` 64 KiB 封顶的超限快照各一条 ✅ 已落地，防 DoS 文本过大回退。

**出口**：`bench_*` 五件套（含 `bench_wire_headers`）在 worktree 内 A/B 无回归；`make hygiene` 绿。W15.1-15.8 均 ✅ 已落地（零堆/单遍单拷/几何预留/O(n) loop 批量预留/阈值压实/单遍校验/1MiB/8MiB 边界/基准冻结）。

---

## 4. W16 — 复用度与高级感（Reuse & Elegance，✅ 已落地，2 周）

> 目标：任意 agent 形态（交互 / 网关 / 批量扇出 / 长链 / 受限池 / hooks/取消/超时/缓存）只引门面即可组装，无破层 uses。

| 项 | 手段 | 受益场景 |
|----|------|---------|
| W16.1 门面一站式闭环 ✅ 已落地 | `AgentValidateWireHeaders` / `AgentInitUsageUnknown` / `AgentTruncate*` / `AgentJoinWireUrl` / `AgentBuildSystemText` / `MergeExtraJson` / `WireHeaderValue` 全量经 `nextpas.core.agent` 透出 | 网关自检、离线单测、自定义 transport |
| W16.2 base 真源收口 ✅ 已落地 | `CAgentMaxSlotMap=256` / `CAgentMaxWire*` / `CUsageUnknown` 等常量上收 `base`/`provider.common`，`provider`/`transport`/`fold` 零重复定义 | 跨单元 DoS 上限一致 |
| W16.3 已知键/批次签名复用 ✅ 已落地 | `AgentIsKnownKey` / `AgentBatchSignature` 抽至 `base`，`provider.common` + `loop` 共用 | Extra 捕获与防打转同口径 |
| W16.4 SlotMap O(1) ✅ 已落地 | `TWireToolSlotPool.Find` 直映表 + `CAgentMaxSlotMap` 上限，未超限走 `FMap[AIdx]`，稀疏大索引回退线性 + `>256` 即 `aecProtocol` | 大扇出（>100 并行工具）不塌 |
| W16.5 报文高级感 ✅ 已落地 | `wire header` 统一前缀、`TextDelta`/`ThinkingDelta` 合段、`ExtraJson` 后者胜语义 `MergeExtraJson` 单点 | 日志脱敏可检索 |
| W16.6 WithXxx 链不断裂 ✅ 已落地 | `TCompletionRequest.WithExtraJson/WithModel/WithMessages/WithMessage/WithTopP/Seed/Parallel/Thinking` 全量 builder 链 | 网关渐进注入 `service_tier/user` 等厂商私有键 |

**出口**：`API_COVERAGE.md` 覆盖率逐项勾选；`test_compile_skeleton` facade 转发用例包含所有新增透出；`docs/agent` 无孤儿 `uses`。W16.1-16.6 均 ✅ 已落地（门面透出闭环/base 单源/已知键复用/O(n) loop→O(n) 单次预留报文高级感/Builder 链）。

---

## 5. W17 — 稳定性与安全（Stability & Security，✅ 已落地，2 周）

> 口径：`SECURITY.md` §3 DoS 上限 + `ERRORS.md` §1/§6 归因 + 取消/超时时序。

| 项 | 卫句 | 触发 | 证据 |
|----|------|------|------|
| W17.1 单头/总头 8 KiB/64 KiB ✅ 已落地 | `AgentValidateWireHeaders` 于 provider 编码期 + transport 构建期双重校验 | 恶意 compatible 网关畸形头 | `test_transport_stream` 5×3 矩阵 9 passed |
| W17.2 单行 1 MiB / 单事件 8 MiB ✅ 已落地 | `agent.sse` 行/事件上限 | 恶意 SSE 流 | `test_sse` 13 passed（line limit exact boundary + event data limit） |
| W17.3 成功体 8 MiB ✅ 已落地 | `transport.http.ReadAllBody` 8 MiB 封顶 + 错误体 64 KiB 封顶 | 恶意大响应 | `test_transport_stream` response body exceeds 8MiB |
| W17.4 工具参数 256 KiB / 深度 8 ✅ 已落地 | `ValidateToolArguments` 预检 | 模型坏参 | `test_tools` 8 passed（256KiB+depth 8） |
| W17.5 Extra 64 键上限 ✅ 已落地 | `CaptureExtraJson` 超限丢弃 + warn | 病态响应膨胀 | `test_security` 8 passed（Extra64） |
| W17.6 取消贯通 ✅ 已落地 | `TWireStream` 硬中断 `IHttpCancelToken` + `WaitFor` ≤3s，`TWireBackedCompletion` 弃置即 `Cancel` | 流中途取消 | `test_transport_stream` hard cancel 111ms / destroy 101ms |
| W17.7 空闲卫生 ✅ 已落地 | `ReadIdleTimeoutMs` >0 时 `FSw.ElapsedMs - FLastProgressMs > ReadIdleMs` 合成 `aecTimeout`（不污染 `GetCancelled`） | 对端僵死 | `test_transport_stream` read idle 6.04s |
| W17.8 槽位 DoS 上限 ✅ 已落地 | `CAgentMaxSlotMap=256`，稀疏大索引回退 + 槽总数 >256 即 `aecProtocol` | 恶意大 index | `test_provider_*` 扩测 + 256KiB |
| W17.9 OpenStream 泄漏封堵 ✅ 已落地 | `OpenStream` 内 `try Start except Free; raise` | 头部卫句异常路径 | `test_transport_stream` HEAPTRC OK |

**出口**：全量 `*_stream` 回环时序门 + `HEAPTRC_GATE=1` 零泄漏；`SECURITY.md` 表与实现阈值逐项对应。W17.1-17.9 均 ✅ 已落地（1MiB/8MiB、8MiB 体、256KiB/Extra64、取消贯通等）。

---

## 6. W18 — 完整性与 v1.0 Landing（Completeness，2 周）

> 目标：公开 API 冻结 + 文档即代码 + 真网三协议支柱齐验 + `registry: stable`。

| 项 | 交付 | 门 |
|----|------|----|
| W18.1 API 冻结 | `API.md` §1–§10 含新增 `AgentValidateWireHeaders`、`WithExtraJson` 后者胜语义、Defaults 总表 8 项阈值（chunk/SSE/体/头/Extra/参数/RawBody/ReadIdle） | `test_compile_skeleton` 9 passed + `docs/agent` 审阅 |
| W18.2 Wire 完整 | `WIRE-MAPPINGS.md` §0/1.1/2.1/3 全覆盖 + Q-O1..7/Q-A1..8/Q-R1..7 怪癖各一条快照 | `test_codecs` 网关式回放心智 |
| W18.3 测试完整 | Gate 清单见 `TESTING.md` 24 门（含 `test_agent_slot_registry` 6 测 + `test_provider_common` 9 测负值守卫红→绿）全绿 | `make focused FOCUS=core/tests/nextpas.core.agent/<gate>` 全量 |
| W18.4 基准完整 | `bench_fold` / `bench_sse_feed` / `bench_loop_overhead` / `bench_wire_codec` / `bench_wire_headers` 五件套数据落 `BENCHMARKS.md`（`bench_wire_headers` ~203 ns / `bench_loop` ~161 µs / `bench_sse` ~198 MB/s 2026-08-29 冻结），劣化 >10% 必议 | `bench_*` 在 worktree 与 main 对打 |
| W18.5 真网三支柱 | `test_e2e_live` `NEXTPAS_AGENT_E2E=1` 下 openai/anthropic/responses 三协议 Complete/Stream 真网全绿（含 Responses tool 调用往返） | CI opt-in 门 |
| W18.6 例程与覆盖 | `examples/01_quickstart`..`04_offline_test_pattern` + `examples/responses`；`API_COVERAGE.md` 逐项勾选 | `make hygiene` + `git diff --check` |
| W18.7 Landing | 本文档 + `ARCHITECTURE.md` + `PERFORMANCE.md` + `SECURITY.md` + `SESSION.md` 联审，`registry: stable` 首语义化版本 | Ready 报告 + 总控批准 |

---

## 7. 波次依赖与并行度

```
W14(wire) ─┬─ W15(perf) ─┬─ W18(landing)
           └─ W16(reuse) ─┴─ W17(stability) ─┘
```
- W14 为前置（常量/错误码单源化影响面广）。
- W15 与 W16 可并行（perf 不改 API，reuse 不改热路径分配）。
- W17 依赖 W14（阈值常量收口后才能锁定 DoS 快照）。
- W18 依赖 W15–W17 全部出口。

---

## 8. 风险与回退

| 风险 | 缓解 |
|------|------|
| OpenAI Responses 流事件 `response.*` 新增或改名 | `WIRE-MAPPINGS §3` 隔离 + `test_codecs` 未知事件跳过快照，新增事件仅扩 `WireDecoder` 不破词表 |
| Gateway 畸形头绕过 | W14 双卫句 + 5×3 矩阵 + 8 MiB/64 KiB 快照，`aecProtocol` 不可重试不可绕过总预算 |
| 基准噪声 | `bench_*` 以 worktree vs main 同机 A/B + `p50` 中位数 + 10% 劣化阈值，噪声带内不阻塞 |
| Worktree 交叉污染 | 每波次独立 worktree，一波一 commit 组，`make hygiene` + `HEAPTRC_GATE` 双门禁 |

---

## 9. 里程碑与日历（以 W14 起点 T0 计）

| 里程碑 | 时间 | 产出 |
|--------|------|------|
| M1 W14 收口 | T0+2w | wire 单源 + 门面一站式 + 5×3 矩阵 |
| M2 W15+W16 并行 | T0+4w | 四基准无回归 + 门面覆盖率 100% |
| M3 W17 收口 | T0+6w | SECURITY 表与实现阈值 1:1 快照 |
| M4 W18 Landing | T0+8w | `registry: stable` + 首 tag + `BENCHMARKS.md` 基线冻结 |

---

## 10. 已落地与本路线图关系

- W0–W13 见 `ROADMAP.md` 波次表，不再重复。
- 本文档 W14.1–W14.4、W15.1–W15.8、W16.1–W16.6、W17.1–W17.9 已全部标为 ✅ 已落地，即本 lane（2026-08-29，`codex/core-agent`）的精化提交（wire 单源、门面透出、O(n) loop 单次预留、1MiB/8MiB、8MiB 体、256KiB/Extra64、取消贯通等）已固化为不可回退不变量；本轮验证：test_sse 13 passed / transport_stream 8 passed（5×3 矩阵） / tools 8 passed / security 8 passed / bench_wire_headers ~203 ns（旧 249 ns -18%） / bench_loop ~161 µs / bench_sse ~198 MB/s（2026-08-29 冻结）。
- 未标注“已落地”项为本路线图剩余待办，按表内出口逐项关门（当前仅 W18 待收口）。

---

## 11. 执行清单（给 lane 执行者的逐波 checklist）

**每波通用**：
```bash
make -C .worktrees/core-agent hygiene
make -C .worktrees/core-agent/core/tests/nextpas.core.agent/test_<gate> clean test   # HEAPTRC_GATE=1
make -C .worktrees/core-agent/core/benches/<bench> clean bench   # A/B 对打
git diff --check
```

**W14 单**：`test_transport_stream` 9 passed / `test_compile_skeleton` 9 passed 为门槛 ✅ 已落地。

**W15 单**：`bench_sse_feed` MB/s ≥198（冻结 2026-08-29，旧 176） + `bench_fold` ns/op 无回退 + `bench_wire_headers` ~203 ns（旧 249 ns -18%） ✅ 已落地。

**W17 单**：回环 `hard cancel <3s` / `read idle` 区分 `GetCancelled=False` 断言绿 + `test_sse` 13 passed / `test_tools` 256KiB / `test_security` Extra64 ✅ 已落地。

**W18 单**：`test_e2e_live` 三协议真网绿 + `API_COVERAGE.md` 全勾。

---

*本文档随每波次落地同步更新“已落地”标记；与实现不一致时以本文档为准修代码。*
