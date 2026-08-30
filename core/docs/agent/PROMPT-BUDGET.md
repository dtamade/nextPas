# PROMPT-BUDGET：有界快照预算模式

> 施工依据：有界快照预算的落点是「系统提示合并去重 + 加权 token 估算 + 簇安全截断」
> 三段式管线；与 `PERFORMANCE.md` 缓冲契约、`ARCHITECTURE.md` 分层纪律、
> `API.md §1.3` 的 `TCompletionRequest` builder 配套使用。
> 本文档是客户端零依赖的本地预算策略——不引入 tokenizer 依赖、
> 不触网，必要时经 `IAgentTokenCounter` 探测式升级为精确计数。

## 1. 为何 6000 B 预算

`gtd888.tui.ai.pas:AiSnapshotBuild` 的 6000 B 有界快照是本模式原型——
**不是模型上下文窗口的硬阈值，而是客户端侧"可预测成本/延迟/缓存命中"的软预算**：

| 维度 | 取 6000 B 的理由 |
|------|------------------|
| 成本 | 约 `6000/4 ≈ 1500 tokens`（`textutil.AgentEstimateTokens` 口径），按 `pricing.EstimateCost` 默认费率约 3.75–15 mUSD/token 段，单快照成本可控且可离线估算；超窗即截断而非上游 `aecContextOverflow` |
| 延迟 | 6 KiB 载荷在 32 KiB `CReadChunkBytes` 单块内，SSE 单遍 `O(bytes)` 零回扫，上送体序列化 `IStringBuilder` 单遍写出无 DOM 二次拷贝（`PERFORMANCE.md §3`） |
| 缓存 | 预算内快照与 `PERFORMANCE.md §6` 前缀稳定不变量正交——历史只追加、`BuildSystemText` 去重保证 system 段字节稳定，多轮间 provider 侧 prefix cache 命中率不受预算抖动影响 |
| 容错 | 6 KiB 是"完整 system + 关键历史摘要 + 工具描述"三段式预算的经验平衡点，小于 4 KiB 易丢工具 schema，大于 10 KiB 则吞噬后续 `MaxOutputTokens` 预算窗口 |

> 参考 `token888` 的预算管线：服务端以真实 tokenizer 计费为准；客户端侧以
> `WeightedTokens` 粗估做**本地守卫**，保持零依赖（不链接 tokenizer native 库）。

## 2. BuildSystemText 合并去重

权威实现：`nextpas.core.agent.base.AgentBuildSystemText`（单一真源，`base` → `provider` 共用）。

```pascal
function AgentBuildSystemText(const ASystem: string;
  const AMessages: TMessageArray): string;
```

语义：

1. `ASystem`（`TCompletionRequest.System` 顶层便利字段）先行；
2. 扫描 `AMessages` 中全部 `mrSystem` 消息，取 `MessageText(each)` 非空文本；
3. **去重**：线性扫描已收集 `LParts`（小表 `O(n²)` 最优，`n` 通常 ≤ 4），命中即丢弃——保证跨轮重发历史时重复 system 不膨胀前缀；
4. 以 `#10#10`（双换行）连接，`IStringBuilder(CAgentSystemTextInitialCap=512)` 单遍写出，零中间字符串拼接。

```pascal
// 调用点（provider.encode 三家共用）：
LSysText := AgentBuildSystemText(AReq.System, AReq.Messages);
```

不变量：同一会话内已完成轮次的 system 内容永不重写，`BuildSystemText` 的输出字节跨轮稳定（`PERFORMANCE.md §6-1`）。

## 3. WeightedTokens 估算

轻量估算：`nextpas.core.agent.textutil.AgentEstimateTokens` / `pricing.AgentEstimateTokens`。

```pascal
function AgentEstimateTokens(const S: string): Int64; inline;
begin
  Result := (Int64(Length(S)) + 3) div 4;  // ~4 字符/token，F-M16 同口径
end;
```

- **输入域**：UTF-8 字节长度（`Length(S)`），非字符数——与 `pricing.EstimateCost` 的输入同尺度；
- **精度**：英文 ~4 char/token 贴近，CJK / 代码场景偏高估（安全侧：宁多计不少计）；
- **成本**：`inline` 纯函数零分配，可在热路径每轮调用（loop 预算预警同款）；
- **演进**：`code888` 的 `weightedTokens` 在此口径上加权 system/tools 段，本模块保持纯文本估算，复杂加权由消费方在外层叠加（保持客户端零依赖）。

## 4. Need 精确 Builder 何时切

`Need` 语义源自 `AiSnapshotBuild` 的 `Need` 阈值——**粗估越限才切精确**：

| 场景 | 策略 |
|------|------|
| 粗估 `WeightedTokens ≤ 预算` 且未触发 `levBudgetWarning`（80% 预警） | 保持 `AgentEstimateTokens`，零 IO 快速路径 |
| 粗估越限、或 loop 已触发预算预警、或消费方显式要求计费精度 | 探测 `IAgentTokenCounter`（`API.md §3.3`，仅 anthropic 实现）：`Supports(Provider, IAgentTokenCounter, LCounter)` 成功则 `LCounter.CountTokens(LReq)` 取厂商口径精确值；失败回落粗估（诚实边界：不伪造） |

```pascal
function EstimateTokensFallback(const AText: string): Int64;
var
  LCounter: IAgentTokenCounter;
  LReq: TCompletionRequest;
begin
  if Supports(FProvider, IAgentTokenCounter, LCounter) then
  try
    LReq := TCompletionRequest.New('').WithUserText(AText);
    Result := LCounter.CountTokens(LReq);
    Exit;
  except
    // 探测失败回落自有估算（API.md §3.3 诚实边界）
  end;
  Result := AgentEstimateTokens(AText);
end;
```

该分支在 `loop.pas:CompleteRound` 预算结算中已落地——已知 usage 累计，未知时优先探测、失败回落单一真源（`F-M16`）。

## 5. 有界截断策略（簇安全）

预算越限时的截断必须满足：**字节预算内、UTF-8 合法、Grapheme 簇完整、EAW 列宽不塌**。

### 5.1 截断原语

- `AgentUtf8SafeCutLen(S, AMaxBytes): Integer` / `AgentUtf8SafeTruncate(S, AMaxBytes): string`——`textutil` 单一真源，`inline` 零开销，沿尾部回退到合法 UTF-8 边界（`$C0=$80` 延续字节跳过 + 多字节头期望长度校验）。
- `nextpas.core.text.grapheme.GraphemeNext(PByte, ALen)`——UAX #29 簇边界真源（`GraphemeClusterByteLen`），覆盖 ZWJ / Regional Indicator / Extend / SpacingMark / keycap / VS16 变体。

### 5.2 有界快照截断步骤

1. 先算 `LSysText := AgentBuildSystemText(...)` 全量；
2. 若 `Length(LSysText) > 6000`：先 `AgentUtf8SafeCutLen(LSysText, 6000)` 得字节安全切点，再向前对齐到 `GraphemeNext` 簇边界（避免 `👨‍👩‍👧` / `🇨🇳` / `é+◌́` 被半切）；
3. 截断后补 `'…'` 语义省略标记（若预算允许），并置 `Truncated=True` 信封；
4. 长度截断（`TruncateLines`）与字节截断（`TruncateBytes`）双阈值正交——行截断先求 `LLineLen`（零分配单遍），再在前缀内做簇安全字节截断（`base.AgentTruncateEnvelope` 同款时序）。

> 警示（`task888:721`）：`GraphemeNext` 前向计宽与 `AgentUtf8SafeCutLen` 后向回退必须配对使用；单用 `Copy(S,1,N)` 会半切 emoji 序列导致终端 EAW 列宽错位与 JSON 非法（`PERFORMANCE.md §7a` 详述）。

## 6. 实例代码

```pascal
uses nextpas.core.agent, nextpas.core.agent.pricing;

var
  LReq: TCompletionRequest;
  LBudget: Integer;
  LSysText: string;
  LTokens: Int64;
  LCost: Int64;
begin
  LBudget := 6000;
  LReq := TCompletionRequest.New('claude-sonnet-4')
    .WithSystem('你是一个简洁的助手，优先用中文回答。')
    .WithUserText('用一句话介绍 TLS 1.3')
    .WithTools(WithTools([TWeatherTool.Create])); // tools 自由函数，F-M13

  // 有界快照：system 去重拼接 + 预算内簇安全截断
  LSysText := AgentBuildSystemText(LReq.System, LReq.Messages);
  if Length(LSysText) > LBudget then
    LSysText := AgentUtf8SafeTruncate(LSysText, LBudget);

  // 加权估算 + 精确分支（Need 阈值）
  LTokens := AgentEstimateTokens(LSysText);
  if LTokens * 4 > LBudget then
    LTokens := EstimateTokensFallback(LSysText); // 探测 IAgentTokenCounter

  // 成本联动（见 §7）
  LCost := EstimateCost(LTokens, 0);
end;
```

要点：`WithSystem` / `WithUserText` / `WithTools` 链式 `advancedrecords` 值语义（`API.md §1.3`），`WithTools(array of IAgentTool)` 第二形态经 `tools` 自由函数不断链；`WithMessages` 批量覆盖与 `WithMessage` 附加语义互补。

## 7. 与 pricing.EstimateCost 联动

```pascal
// pricing.pas T1.1/T1.4 双口径
function EstimateCost(const APricing: TModelPricing;
  APromptTokens, ACompletionTokens: Int64;
  ARateMultiplier: Int64 = 10000): Int64; overload;
function EstimateCost(const AUsage: TTokenUsage): Int64; overload; // 未知按 0 计
function AgentEstimateTokens(const S: string): Int64; inline;
```

- **loop 侧**：每轮 `AccumulateUsage` 后 `if Known then EstimateCost(Usage) else EstimateCost(0, AgentEstimateTokens(MessageText))`，经 `IAgentUsageSink.RecordUsage(Provider, Req, Usage, CostUsd6)` 透传（`nil` 退化/吞异常不 raise，`API.md §3.4`）；
- **预算侧**：有界快照的 `WeightedTokens` 直接作为 `EstimateCost` 的 `APromptTokens` 入参，`ACostUsd6` 为 μUSD 整数（`(prompt*per1k+500) div 1000` 四舍五入，同源 `tk888.billing.pas:22,212`），消费方可据此做本地预算告警与 `levBudgetWarning` 联动；
- **分层**：`pricing` 域零 IO 纯函数，无堆分配；`loop` 仅在 `Assigned(UsageSink)` 时调用，热路径零开销。

## 8. 与 token888 的关系与零依赖边界

| 侧 | 职责 | 实现 |
|----|------|------|
| `token888` 服务端 | 真实 tokenizer 计费、上下文窗口硬截断、账单落库 | 服务端 tokenizer native 库 + DB |
| `nextpas.core.agent` 客户端 | 有界快照预算本地守卫、合并去重、加权粗估、簇安全截断、成本预估透传 | `base.AgentBuildSystemText` + `textutil.AgentEstimateTokens` + `pricing.EstimateCost` + `text.grapheme.GraphemeNext`，零第三方依赖 |

客户端**永不**链接 tokenizer、不做服务端计费口径的伪精确；需精确时走 `IAgentTokenCounter` 能力探测（`Supports`），未支持即诚实回落粗估——该边界与 `token888` 的 `IUsageSink` 同契约（`contracts:609`），保证可单测与可移植。

## 9. 校验清单与变更纪律

- 修改 `AgentBuildSystemText` 去重规则或 `CAgentSystemTextInitialCap` 时必跑 `test_provider_openai` / `test_provider_anthropic` / `test_provider_responses` 三家编码快照；
- 修改 `AgentEstimateTokens` 系数或 `pricing.EstimateCost` 舍入时必跑 `test_loop` 预算预警与 `test_transport_trace` 成本透传；
- 修改簇安全截断时必以 `nextpas.core.text.grapheme` 的 `GraphemeBreakTest.txt` 全量用例为回归（`make -C core/tests/nextpas.core.text clean test`）；
- `make hygiene` 拦截 `PROMPT-BUDGET.md` 之后的待办标记残留——见 `grep -rn` 零命中 gate；
- 任何默认值变更必同步 `API.md §10` / `SECURITY.md §3` / `BENCHMARKS.md §2` 三处（`F-L07`）。
