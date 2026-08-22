# nextpas.core.agent

通用 AI agent 标准库模块：多后端 LLM provider 抽象、真流式补全、工具调用循环、
重试/取消、用量核算。**通用的、可复用的、接口优雅的、高性能的**——不绑定任何
具体应用语义（不是 coding agent，不含任何内置业务工具）。

> **Status: draft（W0 阶段）。本目录文档是实施蓝图，按图施工；
> API 以 `API.md` 为契约权威，落地后按 CONTRACT 纪律维护。**

## 定位

```
L3  nextpas.core.agent
    ├─ protocol 子域   纯数据词表 + 纯折叠函数（零 IO）
    ├─ provider 子域   多后端适配器 + wire 传输接缝 + 重试/时钟装饰器
    ├─ loop 子域       通用多轮工具循环（可选消费，不强制）
    └─ session 子域    会话转录存储接口（接口先行，实现后置）
依赖（全部向下）：json / http / async.cancellation / io.intf / log.intf / base / errors / time / encoding
```

模块家族在 `core-module-registry.md` 登记为一个 family：`agent`
（先例：`http` 一个 family 含 server/client/sse/middleware）。

## 30 秒上手

### 非流式一行调用

```pascal
uses nextpas.core.agent;

var
  LProvider: IAgentProvider;
  LReply: TMessage;
begin
  LProvider := NewOpenAIProvider(
    TOpenAIOptions.New('gpt-4o').WithApiKeyFromEnv);

  LReply := LProvider.Complete(
    TCompletionRequest.New('gpt-4o')
      .WithSystem('你是一个简洁的助手')
      .WithUserText('用一句话介绍 TLS 1.3'),
    []);

  WriteLn(MessageText(LReply));
end.
```

### 流式（pull 式原语）

```pascal
var
  LStream: IAgentCompletion;
  LDelta: TStreamDelta;
begin
  LStream := LProvider.Stream(AReq, []);
  while LStream.NextDelta(LDelta) do
    if LDelta.Kind = sdkTextDelta then
      Write(LDelta.TextDelta);
  // EOF 后：
  if LStream.GetCancelled then ...   { 区分取消与正常结束 }
end.
```

### 工具循环（可选高层入口）

```pascal
var
  LLoop: TAgentLoop;
  LRun: IAgentLoopRun;
begin
  LLoop := TAgentLoop.Create(LProvider);
  LLoop.Options.MaxRounds := 10;
  LLoop.AddTool(TWeatherTool.Create);          { 实现 IAgentTool }

  LRun := LLoop.Run('上海今天适合骑车吗？');
  WriteLn(MessageText(LRun.FinalMessage));
end.
```

### 离线测试（CI 永不触公网 LLM）

```pascal
LProvider := NewFakeProvider(FAKE_SCRIPT_HELLO);  { 脚本化增量回放 }
// 或：真实 provider + scripted transport + fake clock，全链路零睡眠零网络
```

## 文档索引

| 文档 | 角色 |
|------|------|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层、单元清单、数据流、并发/取消/内存所有权模型 |
| [`API.md`](API.md) | **公开 API 契约权威**：全部类型/接口签名与语义 |
| [`WIRE-MAPPINGS.md`](WIRE-MAPPINGS.md) | 各厂商线级协议映射真相源（含怪癖清单） |
| [`DESIGN.md`](DESIGN.md) | 对标分析与决策记录（为何这样设计） |
| [`TESTING.md`](TESTING.md) | 测试 gate 清单、离线纪律、基准计划 |
| [`ROADMAP.md`](ROADMAP.md) | 实施波次与出口证据 |

## 非目标（v1）

- 不做 MCP（消息模型预留扩展点，不堵死后续接入）。
- 不内置业务工具集；不做 embeddings / 图像生成 / WebSocket realtime。
- 不内置定价表：只提供 Int64 token 用量，计价由消费方注入。
- 不做服务端代理网关（那是 token888 的领域）。

## 消费方引用粒度

| 需要 | 引用 |
|------|------|
| 开箱即用 | `nextpas.core.agent` |
| 只要类型定义（自建循环） | `nextpas.core.agent.base` + `.intf` |
| 自定义 provider/transport | 加 `.intf` + 对应 provider 单元 |
