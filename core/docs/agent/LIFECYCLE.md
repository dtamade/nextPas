# LIFECYCLE：对象生命周期、状态机与并发时序

> 施工依据：本文档的状态机与释放顺序是实现验收标准；
> 与 ARCHITECTURE §4 线程契约表配套使用。

## 1. IAgentCompletion 状态机

```
                 Stream() 返回
                      │
                      ▼
   ┌─────────────── Active ───────────────┐
   │  NextDelta=True（交付 delta）          │
   │  ──────────────────────────────────  │
   ├─→ EOF（正常/取消）      NextDelta=False│
   ├─→ Failed（流中途 sdkError）           │
   └─→ Cancelled → 归并为 EOF 形态          │
                      │
                      ▼
              Terminal (EOF|Failed)
   NextDelta 恒 False；GetCancelled 可读
   GetMessage / GetUsage：
     EOF     → 正常返回（sdkError 路径在此抛缓存错误）
     Failed  → 抛缓存的 EAgentError
```

规则：

- `GetMessage` 首次调用完成 fold 收口并缓存；重复调用返回同一结果（幂等）。
- `GetUsage` 适用同一缓存 / 幂等规则（EOF 后有效；Active 期访问同报
  `'completion not drained — drain NextDelta until False before GetUsage'`）。
- Active 期调用 `GetMessage` / `GetUsage` 属消费方时序违反：直接 raise
  `EAgentError[aecProtocol]`，`message` 以 `'completion not drained'` 起头
  （完整文案：`'completion not drained — drain NextDelta until False before GetMessage/GetUsage'`），不新增公开错误码位 — 语义清晰，可断言前缀。
- Cancel 在任意状态幂等；Terminal 后调用无副作用。

## 2. 流式全链路时序（真增量）

```
Consumer        Completion        Transport         http.Client      sse.Feed    Decoder
   │ OpenStream(经 provider 编码)  │                  │               │           │
   │──────────────→│ POST 发出，响应头到达             │               │           │
   │               │─────────────────→│ IReader 就绪   │               │           │
   │ NextDelta()   │                  │               │               │           │
   │──────────────→│ Read(32KB) ←阻塞──┼──────────────→│ socket chunk 1 │           │
   │               │                  │  Feed(chunk) ────────────────→│ 完整帧     │
   │               │                  │  DecodeEvent(frame) ─────────────────────→│ deltas
   │               │ ←delta 就绪立即返回（不等待 EOF）  │               │           │
   │←── delta(s)───│                  │               │               │           │
   │  …循环…        │                  │               │               │           │
   │               │ EOF: Finalize() 合成终帧          │               │           │
   │←── False ─────│ 连接归还池        │               │               │           │
```

验收点（对应 test_transport_stream）：chunk N 到达即产出其 delta，
NextDelta 返回时刻 ≤ chunk N+1 发出时刻（用 scripted transport 的投喂日志断言）。

## 3. Decoder 帧序列校验（协议 FSM 落点）

各厂商 decoder 维护最小帧序状态，违例抛 aecProtocol：

| 厂商 | 状态约束 |
|------|---------|
| openai | 任意帧序宽容（兼容网关乱象多）；仅校验 tool_calls index 单调非回退、[DONE] 后无帧 |
| anthropic | message_start 必须为首有效帧；content_block_* 的 index 必须匹配当前开块；message_stop 后无帧；error 后无帧 |

## 4. Loop 轮次状态机

```
Run()（阻塞直至终态）:
  RoundStart → Infer(provider.Stream + drain)
     ├─ 无工具调用 → Done(roCompleted)
     └─ 有工具调用 → ToolExecPhase:
            分组调度（相邻 tcParallel 段整段并行，非 tcParallel
            调用独占执行；数组序即执行序，串/并行都经线程池，§5）
            for each call: PreHook → Validate → Execute → PostHook → Truncate
            （hvStop 立即收束 → Done）
        终止检查（预算耗尽 / 防打转 ≥N / MaxRounds 用尽）
          → 任一触发：追加 system 引导消息 → 禁工具推理一次
             成功 → FinalMessage=引导回复，Done(触发原因对应的
                     roBudgetExhausted / roDoomLoop / roRoundsExhausted)
             失败 → Done(roFailed, LastError 就位)
  任意点令牌触发 → Cancelled 收尾（已写入 transcript 的消息保留）
  Infer 抛不可恢复错误 → Failed（LastError 非 nil）
```

## 5. 工具执行设施与超时/弃置语义（决策 D14，经 SELECTION C9 修订）

- **决定**：全部工具调用（串行批次同样）经 L1 线程池直提（`SubmitDirect`
  逐任务 + `SignalWorkers`），轮线程以 `WaitAllTimeout(200µs 切片)` 轮询汇合，
  并做时钟感知的逐项截止判定——每项到期即当场合成，不等整批；截止基准在
  提交前采样，时钟可注入（fake clock 由桩工具在执行体内 Advance 驱动确定性
  超时）。池实例由 loop 构造注入（未注入则构造自有池随实例 Shutdown）。
  统一执行路径使超时语义对串/并行一致。（W3 施工修订：原 SubmitBatch +
  批级一次汇合措辞与实现不符。）
- **批内调度（W13 修订）**：`tcParallel` 从"全有全无"精化为分组——按调用序
  贪心分组：相邻 `tcParallel` 段整段并行（RunToolBatch 一次提交），非
  `tcParallel` 调用独占执行（单元素批）。修复旧规则下一个非并行调用把整批
  拖成全串行的并行度塌缩。声明语义严格保持：任一时刻要么恰好一个非并行任务
  独占运行，要么只有 `tcParallel` 任务在跑——工具的并发声明永不被违反。
  全并行/全串行两特例与旧行为一致（单组/逐个）。各组经同一 RunToolBatch
  管线，超时/取消/合成语义不变。
- **为何不是 async.taskgroup**：已核实其工厂绑定 `TAsyncLoop`，面向事件循环
  runtime；同步阻塞的工具批次用它需凭空造 Loop，属设施错配。
- **失败隔离**：每工具持有父令牌的子令牌（async.cancellation.CreateChildToken），
  单工具失败/超时不取消兄弟任务，各自合成 result 回喂。
- **超时是合成不是抢占**：Pascal 无法安全杀死线程。某项截止到期后，该槽位
  合成 timeout error result 回喂模型并 Cancel 其子令牌，**工作线程被弃置**——
  继续后台运行直至自然结束或进程退出（文档化代价：不协作工具可泄漏 CPU/IO
  至其自然终点）；其迟到结果经写权仲裁不回读已合成载荷。协作式取消（令牌）
  始终是首选路径。排水看门狗：`AToken=nil` 且剩余任务无 Timeout 时排水期以
  `AClock.NowMs - LDrainStart >= 5000` 硬截并合成 cancelled（防 `TAgentLoop.Run` 永久阻塞）。
- **跨线程中断机制**：流读取被另一线程 Cancel 时，transport.Cancel 关闭 socket，
  阻塞中的 IReader.Read 以错误返回，由执行读的线程自身完成清理与连接归还——
  满足"资源不得跨线程释放"。
- loop 本身仍单线程编排（事件回调在轮线程触发，消费者无需加锁）。
- 边界：并行度 = 批大小，不做全局并发上限（v1 明确不支持，inbox 记录）。

## 6. 资源所有权与释放顺序表

| 对象 | 拥有者 | 释放时机 | 幂等 |
|------|--------|---------|------|
| http 连接 | transport（借自 client 池）| EOF/Cancel/Failed 即归还 | 是 |
| WireDecoder 实例 | 创建方角色线程 | 接口引用计数自动 | — |
| TAssistantBuild | completion 内部 | GetMessage 缓存后可复用缓冲 | — |
| Transcript 数组 | loop run 对象 | IAgentLoopRun 存活期 | — |
| FakeProvider 脚本 | 值语义拷贝 | 随记录 | — |
| 工具任务句柄 | IThreadPool 批任务 | Run 返回前 WaitAllTimeout 汇合；到期弃置（§5）| 是 |

通用规则（ARCHITECTURE §6 重申+细化）：Close/Free 幂等；析构路径 best-effort
吞异常并走 log.intf warn；任何资源不得跨线程释放（谁拥有谁释放）。

## 7. 并发场景速查

| 场景 | 支持 | 说明 |
|------|------|------|
| 同 provider 并发多 Stream | 是 | 每流独立连接/decoder/状态 |
| 单流多消费者同时 NextDelta | 否 | pull 所有权单一；需要广播由消费方自行扇出 |
| 同 loop 实例并发两次 Run | 否 | run 间共享 transcript 与选项；并发宿主每 agent 建 loop 实例（实例作用域原则）|
| Cancel 与 NextDelta 跨线程 | 是 | 核心设计场景（§ERRORS 5 表）|
| FromEnv/工厂函数并发调用 | 是 | 只读 env + 纯构造 |

## 8. 交互示例

> 本节为可跑伪码——演示 `sdkThinkingDelta` 思考态与 `tcParallel` 分组防塌缩
> 的真实时序；与 `PROMPT-BUDGET.md` 有界快照预算正交，可直接贴入 `core/tests` 做单测骨架。

### 8.1 sdkThinkingDelta：思考中 → 首 TextDelta 生成中（`task888:752`）

`task888:752` 的 TUI 细节——`thinking` 段到达即切「思考中」态，首个 `sdkTextDelta` 到达切「生成中」：

```pascal
uses nextpas.core.agent;

procedure StreamWithThinking(const AProvider: IAgentProvider);
var
  LComp: IAgentCompletion;
  LD: TStreamDelta;
  LThinking, LAnswer: string;
  LInThinking: Boolean;
begin
  LComp := AProvider.Stream(
    TCompletionRequest.New('claude-sonnet-4')
      .WithSystem('你是一个简洁的助手')
      .WithUserText('用一句话介绍 TLS 1.3')
      .WithThinking(tsTrue, 2048));
  LInThinking := False;
  while LComp.NextDelta(LD) do
    case LD.Kind of
      sdkThinkingDelta:
        begin
          if not LInThinking then begin LInThinking := True; WriteLn('[思考中]'); end;
          LThinking := LThinking + LD.TextDelta; // 增量追加，簇安全渲染见 PERFORMANCE §7.1
          // Signature 透传：LD.Signature 随 thinking delta 携带，fold 时并入 pkThinking.Signature
        end;
      sdkTextDelta:
        begin
          if LInThinking then begin LInThinking := False; WriteLn('[生成中]'); end;
          LAnswer := LAnswer + LD.TextDelta;
          Write(LD.TextDelta); // 首 token 即时（PERFORMANCE §1 真增量）
        end;
      sdkToolCallStart, sdkToolCallDelta, sdkToolCallEnd: ; // fold 内部累积
      sdkFinish: WriteLn(#10'[finish:', Ord(LD.FinishReason), ']');
      sdkUsage: ; // usage/finish 异序由 fold 抹平，GetUsage 统一读取
    end;
  if LComp.GetCancelled then Exit; // 取消归并为 EOF 形态（§1）
  WriteLn(#10'Final: ', MessageText(LComp.GetMessage));
end;
```

要点：`sdkThinkingDelta` 与 `sdkTextDelta` 在 `fold.TAssistantBuild` 中分属 `btkThinking` / `btkText` 槽，`FlushCurrentPart` 在类别切换时才开新 `pkThinking`/`pkText` part——
思考与正文交错时各自成段，思考段 `Signature` 透传保留（`API.md §4`）。

### 8.2 tcParallel 分组防塌缩 + 预算预警 + UsageSink 可跑伪码

`W13` 前「全有全无」：一批中有一个非并行声明即整批串行（并行度塌缩）；
`W13` 后贪心分组——相邻 `tcParallel` 段整段并行，非并行独占执行（`§5`）：

```pascal
uses nextpas.core.agent, nextpas.core.agent.pricing, nextpas.core.thread.pool;

type
  TMySink = class(TInterfacedObject, IAgentUsageSink)
    procedure RecordUsage(const AProvider: string; const AReq: TCompletionRequest;
      const AUsage: TTokenUsage; ACostUsd6: Int64);
  end;

procedure TMySink.RecordUsage(const AProvider: string; const AReq: TCompletionRequest;
  const AUsage: TTokenUsage; ACostUsd6: Int64);
begin
  // 线程安全且不抛异常（API.md §3.4 约定）；nil 退化由 loop 侧 Assigned 守卫
  WriteLn(Format('[usage] %s in=%d out=%d cost=%d μUSD', [AProvider, AUsage.InputTokens, AUsage.OutputTokens, ACostUsd6]));
end;

procedure RunWithBudgetAndGrouping;
var
  LProvider: IAgentProvider;
  LLoop: TAgentLoop;
  LRun: IAgentLoopRun;
  LPool: IThreadPool;
begin
  LProvider := NewFakeProvider(
    '[{"deltas":[{"kind":"tool_call_start","index":0,"id":"c1","name":"search"},' +
    '{"kind":"tool_call_start","index":1,"id":"c2","name":"fetch"},' + // P,P
    '{"kind":"tool_call_start","index":2,"id":"c3","name":"confirm"},' + // N
    '{"kind":"tool_call_start","index":3,"id":"c4","name":"search"},' +
    '{"kind":"tool_call_start","index":4,"id":"c5","name":"search"},' + // P,P
    '{"kind":"finish","reason":"tool_calls"}]},' +
    '{"deltas":[{"kind":"text_delta","text":"done"},{"kind":"finish","reason":"stop"}]}]');
  LPool := CreateThreadPool(4); // 需真并行请注入 ≥2 线程池；一参构造自建池为 1 线程串行退化（ARCHITECTURE §6）
  LLoop := TAgentLoop.Create(LProvider, LPool);
  // 注册工具：search/fetch 声明 tcParallel，confirm 不声明 → 分组为 [P,P] [N] [P,P]
  LLoop.AddTool(TSearchTool.Create);  // Spec.Capabilities := [tcParallel]
  LLoop.AddTool(TFetchTool.Create);   // [tcParallel]
  LLoop.AddTool(TConfirmTool.Create); // []

  LLoop.Options.RequestBase := TCompletionRequest.New('fake-model')
    .WithSystem('你是助手'); // BuildSystemText 去重见 PROMPT-BUDGET.md §2
  LLoop.Options.MaxOutputTokens := 6000; // 预算；80% 时 levBudgetWarning 一次
  LLoop.Options.UsageSink := TMySink.Create; // 每轮 AccumulateUsage 后 EstimateCost 透传
  LLoop.SetEventHook(procedure(const E: TLoopEvent)
    begin
      if E.Kind = levBudgetWarning then WriteLn(Format('[warn] round %d budget 80%%', [E.Round]));
    end);

  LRun := LLoop.Run('查资料并确认');
  // 断言：P,P 组内并发、N 独占、后 P,P 再并发；全程经同一 RunToolBatch 管线，超时/取消/合成语义不变（§5）
  // 预算：OutUsed ≥ MaxOutputTokens 时触发引导收尾 → 禁工具再推理一次 → roBudgetExhausted
  WriteLn('Outcome=', Ord(LRun.Outcome), ' Final=', MessageText(LRun.FinalMessage));
  WriteLn('Usage out=', LRun.TotalUsage.OutputTokens, ' cost μUSD=', EstimateCost(LRun.TotalUsage));
  LLoop.Free;
  LPool.Shutdown;
end;
```

该伪码可直接以 `NewFakeProvider` 脚本离线验证三点：

1. `sdkThinkingDelta` 首段与 `sdkTextDelta` 首段的态切分；
2. `[P,P][N][P,P]` 三组时序（`§5` 贪心分组探针：组内并发闸门、独占探针不饿死）；
3. `levBudgetWarning` 80% 一次性与 `UsageSink` 的 `EstimateCost` 联动（`PROMPT-BUDGET.md §7`）。
