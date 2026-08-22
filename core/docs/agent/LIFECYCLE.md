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
- Active 期调用 GetMessage/GetUsage 属消费方时序违反：直接 raise
  `EAgentError[aecProtocol]`，message 固定 `'completion not drained'`
  （不新增公开错误码位）。
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
Run() → roRunning:
  RoundStart → Infer(provider.Stream + drain)
     ├─ 无工具调用 → Done(roCompleted)
     └─ 有工具调用 → ToolExecPhase:
            并行判定（全 tcParallel 才并行）
            for each call: PreHook → Validate → Execute → PostHook → Truncate
            （hvStop 立即收束 → Done）
        预算检查 → 超 → 引导总结轮（禁工具推理一次）→ Done(roBudgetExhausted)
        防打转检查 → 连续相同 call ≥ N → Done(roDoomLoop)
        MaxRounds 用尽 → 同预算路径（引导总结）→ Done
  任意点令牌触发 → Cancelled 收尾（已写入 transcript 的消息保留）
  Infer 抛不可恢复错误 → Failed（LastError 非 nil）
```

## 5. 并行工具执行设施（补定决策 D14）

- **决定**：loop 的并行工具批次经底座 **`nextpas.core.async` 任务设施**
  （taskgroup 语义）执行：每工具一个任务，轮线程提交后等待全部完成；
  取消令牌为父令牌的子令牌（单工具失败不取消兄弟任务——错误各自合成 result 回喂）。
- **理由**：不自造线程池（底座已有）；子令牌树天然表达"批内隔离"。
- **边界**：并行度 = 批大小，不做全局并发上限（v1 明确不支持，inbox 记录）；
  工具实现内部再开线程与本模块无关。
- loop 本身仍单线程编排（事件回调在轮线程触发，消费者无需加锁）。

## 6. 资源所有权与释放顺序表

| 对象 | 拥有者 | 释放时机 | 幂等 |
|------|--------|---------|------|
| http 连接 | transport（借自 client 池）| EOF/Cancel/Failed 即归还 | 是 |
| WireDecoder 实例 | 创建方角色线程 | 接口引用计数自动 | — |
| TAssistantBuild | completion 内部 | GetMessage 缓存后可复用缓冲 | — |
| Transcript 数组 | loop run 对象 | IAgentLoopRun 存活期 | — |
| FakeProvider 脚本 | 值语义拷贝 | 随记录 | — |
| 工具任务句柄 | taskgroup | Run 返回前 Join 全部 | 是 |

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
