{**
 * nextpas.core.agent.loop.types - 循环词表：纯类型与常量，零逻辑。
 *
 * 职责：承载 TAgentLoopOptions / TLoopEvent / TLoopOutcome / TLoopEventKind
 * / hook 类型与 IAgentLoopRun 契约，供 budget / exec / facade 共享。
 * 契约权威：core/docs/agent/API.md §6；ARCHITECTURE §3.3/§5；DESIGN D14。
 * 分层：仅依赖 base / intf / clock / log / cancellation，无循环。
 *}

unit nextpas.core.agent.loop.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock;

type
  TLoopOutcome = (
    roCompleted,          { 模型给出无工具调用的最终回答 }
    roCancelled,          { 令牌取消（轮界/工具界）}
    roBudgetExhausted,    { 输出预算或工具调用数达限 → 引导收尾成功 }
    roDoomLoop,           { 连续相同调用达阈值 → 引导收尾成功 }
    roRoundsExhausted,    { MaxRounds 用尽仍有工具调用 → 引导收尾成功 }
    roFailed              { 轮内提供方错误/引导轮失败；LastError 就位 }
  );

  TLoopEventKind = (levRunStart, levRoundStart, levRoundEnd,
    levToolCallStart, levToolCallEnd, levBudgetWarning, levRunEnd);
  { 无 levRetry——重试发生在 WithRetry 装饰器层，loop 不可见 }

  TLoopEvent = record
    Kind: TLoopEventKind;
    Round: Integer;
    ToolName: string;
    ToolCallId: string;              { 工具事件关联键；非工具事件为空 }
    ElapsedMs: Int64;
    DetailJson: TJsonText;
  end;

  TLoopEventHandler = reference to procedure(const AEvent: TLoopEvent);
  TLoopEventHandlerMethod = procedure(const AEvent: TLoopEvent) of object;
  TLoopEventHandlerProc = procedure(const AEvent: TLoopEvent);

  THookVerdict = (hvProceed,       { 正常执行 }
    hvBlock,                       { 合成 error result 回喂，循环继续 }
    hvStop);                       { 结束整次 run（当前 assistant 即终点）}

  TLoopHook = reference to function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict;
  TLoopHookMethod = function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict of object;
  TLoopHookProc = function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict;

  TAgentLoopOptions = record
    RequestBase: TCompletionRequest; { 请求模板：loop 每轮以其为底、追加
                                       transcript 为 Messages、注入注册工具；
                                       Model 必填（Run 时校验）}
    MaxRounds: Integer;              { 工具轮上限；构造默认 10 }
    MaxOutputTokens: Int64;          { 跨轮累计输出预算；CMaxTokensUnset=不限 }
    MaxToolCalls: Integer;           { 整次 run 实际执行的工具调用总数；0=不限 }
    DoomLoopThreshold: Integer;      { 连续相同批签名阈值，构造默认 3；0=关闭 }
    TruncateLines: Integer;          { 工具结果截断行数上限，构造默认 2000；0=关 }
    TruncateBytes: Integer;          { 截断字节上限，构造默认 65536；0=关 }
    Clock: IAgentClock;              { nil → 真实时钟 }
    Logger: ILogger;                 { nil → NullLogger（同 C15 纪律）}
    Cancel: IAsyncCancellationToken;  { 可选运行令牌 }
    UsageSink: IAgentUsageSink;      { T1.4：可选用量汇，nil 退化，线程安全不 raise }
  end;

  IAgentLoopRun = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000003}']
    function FinalMessage: TMessage;     { 最终 assistant 文本消息；无产出空记录 }
    function TryGetFinalMessage(out AMsg: TMessage): Boolean;
    function Transcript: TMessageArray;  { 全程消息（含 tool 往返）}
    function Outcome: TLoopOutcome;
    function TotalUsage: TTokenUsage;
    function LastError: EAgentError;     { roFailed 时非 nil }
  end;

const
  { 引导收尾的 system 提示（ARCHITECTURE §5：code888 UX 教训——先明示再禁工具）}
  CLOOP_GUIDANCE_TEXT =
    'Operational budget reached. Stop calling tools and summarize the ' +
    'findings so far in plain text.';

implementation

end.
