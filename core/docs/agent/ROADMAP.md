# ROADMAP：实施波次

> 前提：本目录设计文档套件（README/ARCHITECTURE/API/WIRE-MAPPINGS/DESIGN/TESTING）
> 已获总控批准。每 wave 出口证据齐备才可 landing；wave 之间 lane 保持可编译。

## Wave 概览

| Wave | 内容 | 出口证据 |
|------|------|---------|
| **W0 骨架** | registry 登记 `agent` family（draft）；空门面+base+errors 编译 gate；本文档转正 | `test_compile_skeleton` 绿；hygiene 绿 |
| **W1 协议与传输** | base/errors/intf 全量词表；fold.pas；agent.sse 增量解析器；transport.http；provider.common + provider.openai（含公开编解码器）+ provider.fake；clock | test_protocol / test_errors / test_sse / test_transport_stream / test_provider_openai / test_codecs(openai) / test_fake_provider 绿 |
| **W2 可靠性** | retry 装饰器（含 fake clock 生产单元）；anthropic 适配器（含公开编解码器）；取消贯穿 transport/provider；usage 六字段全量映射 | test_retry / test_provider_anthropic / test_codecs(anthropic) 绿 |
| **W3 循环** | tools 校验/截断/超时包装；TAgentLoop（预算/钩子/事件/防打转/引导收尾）| test_tools / test_loop 绿 |
| **W4 收口** | examples（01_quickstart / 02_streaming / 03_tool_loop / 04_offline_test_pattern）；benchmarks 三件套；docs/agent/BENCHMARKS.md + API_COVERAGE.md 建立；README 状态 draft→stable(draft truth) | 全 gates + benches；`git diff --check`；`make hygiene`；Ready 报告 |
| **W5（后置，按需立项）** | JSONL event-sourced transcript store（fork/crash 恢复语义先出独立设计）；agent.sse 反哺晋升 http.sse 的跨模块 slice | 各自独立 Ready 报告 |

## Wave 内顺序约束

- W1：fold 与 sse 先行并各自带 gate 落地，再接 transport（消费二者），最后 openai
  适配器——依赖方向即施工顺序。
- W2：retry 不依赖 anthropic；两者并行可行但 landing 分开提交（可回滚逻辑单元）。
- W3：loop 只准消费 intf 词表；发现需要 wire 信息即为分层违规，回 W1/W2 修词表。

## Inbox（活动输入池，非承诺）

- Gemini / Responses 协议编解码器——token888 上游侧存在真实需求（CONSUMERS.md §5），
  待其接入立项时进 WIRE-MAPPINGS 立节后实施。
- IdleGuard 装饰器（code888 的空闲超时 408 语义）——待 code888 Phase 1 接入时
  评估是否上移为通用 transport 装饰器。

## 明确不做（v1 冻结）

MCP / embeddings / 图像生成 / WebSocket realtime / 自动 compaction / 子代理编排 /
JSON mode / 定价表 —— 见 README「非目标」与 DESIGN §4。变更须先改文档再动代码。
