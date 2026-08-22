# nextpas.core.agent 引导计划

> **Status: 设计定稿（2026-08-23）。实施蓝图已转正至 [`core/docs/agent/`](../agent/README.md)。**
> 本文件保留引导期决策轨迹；施工以 `docs/agent/` 套件为准，两者冲突时以后者为准。
>
> - Lane: `.worktrees/core-agent`（分支 `codex/core-agent`）

## 引导期输入

- nextpas.core 框架规范：AGENTS.md / core/AGENTS.md / design-conventions.md /
  core-module-registry.md，参照 http 模块文档范式。
- `~/projects/token888`：AI API 网关（IR 中枢、Extra 无损、FinalizeStream、
  故障归因分离、整数用量数学；缺请求内重试/取消/会话）。
- `~/projects/code888`：Pascal coding agent runtime（pull 式流、唯一 fold、
  transport 接缝+注入时钟、sentinel 选项、离线 CI 纪律；全缓冲流式/god object/
  全局注册表为反面教材）。

## 开放问题收敛记录

| # | 问题 | 结论 |
| --- | --- | --- |
| Q1 | v1 范围 | provider + loop 双层都做，分 wave landing（W0-W4），会话接口先行实现后置 |
| Q2 | 增量 SSE 解析器归属 | 先落 `nextpas.core.agent.sse`（W1 零跨模块）；行为稳定后提请晋升 http.sse，作为独立反哺 slice 报批 |
| Q3 | 会话持久化 | IAgentTranscriptStore 接口先行冻结；内存实现随 W4；JSONL 实现列 W5 按需立项 |
| Q4 | 适配器优先级 | v1 = OpenAI Chat Completions 兼容 + Anthropic Messages；其余按 inbox 追加 |
| Q5 | 模块名 | `nextpas.core.agent`（L3 单 family，registry 登记 draft） |

## 后续动作

按 `docs/agent/ROADMAP.md` 波次施工；每 wave 出口证据与 landing 纪律见
TESTING.md §5 与仓库 AGENTS.md。
