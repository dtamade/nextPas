# API_COVERAGE：契约面 × 落地单元 × 测试证据

> 契约权威是 `API.md`；本文件回答"每条契约在哪实现、被哪个 gate 证明"。
> 状态词：**落地**（实现+gate 双全）/ **接口先行**（接口冻结，实现后置）。

## §1 base 词表 → `nextpas.core.agent.base` — 落地

| 词表 | 证据 |
|------|------|
| TMessage/TPart/TTokenUsage/TCompletionRequest 及 builder | 全部 gates 消费；编码侧细节见 test_provider_openai/anthropic 快照 |
| TStreamDelta 全枚举 | test_protocol（fold 矩阵）+ 两 provider gate 流 FSM |

## §2 错误分类 → `nextpas.core.agent.errors` — 落地

| 词表 | 证据 |
|------|------|
| EAgentError 族 + aec* 分类 | test_retry（白名单/归因）、两 provider gate（上游状态归约）、test_security（fail-closed 路径）|
| EAgentMisuse | test_security（GetMessage before EOF）；decoder 复用守卫见 test_codecs |

## §3 接缝接口 → `nextpas.core.agent.intf` — 落地（session 域除外）

| 接口 | 实现 | 证据 |
|------|------|------|
| IAgentProvider / IAgentCompletion | openai/anthropic/fake + retry 装饰 | 各 provider gate、test_retry、test_assembly |
| IAgentTransport | transport.http | test_transport_stream（真增量+硬取消回环）|
| IAgentWireDecoder（D13 公开） | 两适配器解码器 | test_codecs |
| IToolContext / IAgentTool | tools 单元 + 消费方注入 | test_tools / test_loop |
| IAgentClock | agent.clock（真实+fake） | test_retry / test_tools（超时确定性）|
| **IAgentTranscriptStore** | **无（W5 后置）** | **接口先行，session 域未立项** |

## §4 协议域纯函数 fold → `nextpas.core.agent.fold` — 落地

D1 唯一折叠实现。test_protocol 全词表矩阵；复杂度主张由 bench_fold
背书（≈127 ns/delta，BENCHMARKS §2）。

## §5 重试策略 → `nextpas.core.agent.retry` — 落地

Retry-After/退避曲线/MaxAttempts/白名单外直通/取消打断——test_retry
13 测（fake clock 零真实睡眠）。首 delta 门语义同门覆盖。

## §6 循环 → `nextpas.core.agent.loop` + `.tools` — 落地

| 面 | 证据 |
|----|------|
| 校验/截断信封/批执行器（超时·取消·异常兜底·迟到写仲裁） | test_tools 7 测 |
| 编排/预算/事件/防打转/引导收尾/钩子三态 | test_loop 14 测（含 prompt cache 前缀稳定断言，PERFORMANCE §6）|
| 执行设施复杂度 | bench_loop_overhead ≈16.6 µs/轮 |

## §7 Fake / scripted provider → `nextpas.core.agent.provider.fake` — 落地

自身语义 test_fake_provider；作为基建被 test_assembly /
bench_loop_overhead 与全部示例消费（离线纪律的合法替代面）。

## §8 纯编解码器（D13）→ `provider.common` 公开表面 — 落地

wire↔词表往返、Extra 保真、违例 fail-closed、双角色并行隔离——
test_codecs 11 测。已知键捕获上限由 test_security 复核
（含 W4 修复：openai 根级已知表补 'model'）。

## 门面 `nextpas.core.agent` — 落地

工厂/装饰器/工具转发/TAgentLoop 可用性：test_assembly 经门面装配点跑通
完整链（scripted transport 注入 → retry 叠加 → loop 工具两轮）。

## 安全验收（SECURITY.md）

集中防线 test_security 7 测（密钥不入日志、FromEnv nil、mime 白名单零
wire、256KiB 预检、UTF-8 截断边界、误用守卫、Extra 上限）；深度覆盖在
归属门（sse 行上限→test_sse；编码细节→provider gates）。

## 已知缺口

- **session 域**（IAgentTranscriptStore 实现）：接口先行，W5 按需立项。
- http.sse 同口径参照基准：随 agent.sse 反哺 slice 补齐（ROADMAP inbox）。
