{**
 * nextpas.core.agent.loop - 多轮工具循环（预算/钩子/事件/防打转/引导收尾）。
 *
 * 契约权威：core/docs/agent/API.md §6；ARCHITECTURE §3.3/§5；DESIGN D14；
 * LIFECYCLE §4/§5。实现与文档冲突时先改文档。
 *
 * 分层纪律：loop 只消费 intf 词表，绝不感知 wire 细节。
 * 单线程编排：事件回调全部在轮线程触发，消费方无需加锁。
 *}

unit nextpas.core.agent.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.tools;

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

type
  { 回调不在 Options 里：SetXxx 是唯一注入通道，避免双通道绕过归一化 }
  TAgentLoop = class
  private
    FProvider: IAgentProvider;
    FPool: IThreadPool;
    FOwnsPool: Boolean;
    FTools: array of IAgentTool;
    FSpecs: TToolSpecArray;
    FOnEvent: TLoopEventHandler;
    FPreHook: TLoopHook;
    FPostHook: TLoopHook;
    procedure InitOptions;
    procedure Fire(const AKind: TLoopEventKind; ARound: Integer;
      const AToolName, AToolCallId: string; AElapsedMs: Int64);
    function HasSpec(const AName: string): Boolean;
    function FindSpec(const AName: string): TToolSpec;
    function FindTool(const AName: string): IAgentTool;
    function CompleteRound(const AReq: TCompletionRequest;
      out AMsg: TMessage): Boolean;    { False=运行令牌已取消 }
  public
    constructor Create(const AProvider: IAgentProvider); overload;
    constructor Create(const AProvider: IAgentProvider;
      const APool: IThreadPool); overload;
    destructor Destroy; override;
    { 注册即校验 spec/schema → aecConfig；重名拒绝 }
    procedure AddTool(const ATool: IAgentTool);
    procedure SetEventHook(AHandler: TLoopEventHandler); overload;
    procedure SetEventHook(AHandler: TLoopEventHandlerMethod); overload;
    procedure SetEventHook(AHandler: TLoopEventHandlerProc); overload;
    procedure SetPreToolCall(AHook: TLoopHook); overload;
    procedure SetPreToolCall(AHook: TLoopHookMethod); overload;
    procedure SetPreToolCall(AHook: TLoopHookProc); overload;
    procedure SetPostToolResult(AHook: TLoopHook); overload;
    procedure SetPostToolResult(AHook: TLoopHookMethod); overload;
    procedure SetPostToolResult(AHook: TLoopHookProc); overload;

  public
    Options: TAgentLoopOptions;        { 构造时预置默认值；Run 前直赋合法 }

    function Run(const AUserText: string): IAgentLoopRun; overload;
    function Run(const AMessages: TMessageArray): IAgentLoopRun; overload;
  end;

implementation

const
  CDEFAULT_MAX_ROUNDS = 10;
  CDEFAULT_DOOM_THRESHOLD = 3;
  CDEFAULT_TRUNCATE_LINES = 2000;
  CDEFAULT_TRUNCATE_BYTES = 65536;

type
  TSlotKind = (skExec, skBlocked, skInvalid, skUnknown);

  TSlot = record
    Kind: TSlotKind;
    CallPartIdx: Integer;            { assistant 消息内的 pkToolCall 下标 }
    Spec: TToolSpec;
    Res: TToolResult;                { 最终回喂载荷（已截断信封化）}
  end;

  TLoopRun = class(TInterfacedObject, IAgentLoopRun)
  private
    FOutcome: TLoopOutcome;
    FFinal: TMessage;
    FHasFinal: Boolean;
    FTranscript: TMessageArray;
    FTotal: TTokenUsage;
    FLastError: EAgentError;
  public
    destructor Destroy; override;
    { 零值会误判 Known：初始化为全哨兵；累计合并跳过未知项 }
    procedure InitUsageUnknowns;
    procedure AccumulateUsage(const AU: TTokenUsage);
    function FinalMessage: TMessage;
    function TryGetFinalMessage(out AMsg: TMessage): Boolean;
    function Transcript: TMessageArray;
    function Outcome: TLoopOutcome;
    function TotalUsage: TTokenUsage;
    function LastError: EAgentError;
    property WOutcome: TLoopOutcome read FOutcome write FOutcome;
    property WFinal: TMessage read FFinal write FFinal;
    property WHasFinal: Boolean read FHasFinal write FHasFinal;
    property WTranscript: TMessageArray read FTranscript write FTranscript;
    property WLastError: EAgentError read FLastError write FLastError;
  end;

procedure TLoopRun.InitUsageUnknowns;
begin
  FTotal := Default(TTokenUsage);
  FTotal.InputTokens := CUsageUnknown;
  FTotal.OutputTokens := CUsageUnknown;
  FTotal.CacheReadInputTokens := CUsageUnknown;
  FTotal.CacheWriteInputTokens := CUsageUnknown;
  FTotal.ReasoningTokens := CUsageUnknown;
end;

{ 累计合并：未知项透明（sentinel 不参与算术）}
procedure TLoopRun.AccumulateUsage(const AU: TTokenUsage);

  function Sum2(AAcc, AInc: Int64): Int64;
  begin
    if AInc = CUsageUnknown then
      Exit(AAcc);
    if AAcc = CUsageUnknown then
      Exit(AInc);
    Result := AAcc + AInc;
  end;

begin
  if not AU.Known then
    Exit;
  FTotal.InputTokens := Sum2(FTotal.InputTokens, AU.InputTokens);
  FTotal.OutputTokens := Sum2(FTotal.OutputTokens, AU.OutputTokens);
  FTotal.CacheReadInputTokens :=
    Sum2(FTotal.CacheReadInputTokens, AU.CacheReadInputTokens);
  FTotal.CacheWriteInputTokens :=
    Sum2(FTotal.CacheWriteInputTokens, AU.CacheWriteInputTokens);
end;

destructor TLoopRun.Destroy;
begin
  FLastError.Free;
  inherited Destroy;
end;

function TLoopRun.FinalMessage: TMessage;
begin
  Result := FFinal;
end;

function TLoopRun.TryGetFinalMessage(out AMsg: TMessage): Boolean;
begin
  AMsg := FFinal;
  Result := FHasFinal;
end;

function TLoopRun.Transcript: TMessageArray;
begin
  Result := Copy(FTranscript, 0, Length(FTranscript));
end;

function TLoopRun.Outcome: TLoopOutcome;
begin
  Result := FOutcome;
end;

function TLoopRun.TotalUsage: TTokenUsage;
begin
  Result := FTotal;
end;

function TLoopRun.LastError: EAgentError;
begin
  Result := FLastError;
end;

{ ---- TAgentLoop ---- }

procedure TAgentLoop.InitOptions;
begin
  Options := Default(TAgentLoopOptions);
  Options.MaxRounds := CDEFAULT_MAX_ROUNDS;
  Options.DoomLoopThreshold := CDEFAULT_DOOM_THRESHOLD;
  Options.TruncateLines := CDEFAULT_TRUNCATE_LINES;
  Options.TruncateBytes := CDEFAULT_TRUNCATE_BYTES;
end;

constructor TAgentLoop.Create(const AProvider: IAgentProvider);
begin
  inherited Create;
  FProvider := AProvider;
  InitOptions;
  FPool := CreateThreadPool(1);        { 自有池随实例生命周期 Shutdown }
  FOwnsPool := True;
end;

constructor TAgentLoop.Create(const AProvider: IAgentProvider;
  const APool: IThreadPool);
begin
  inherited Create;
  FProvider := AProvider;
  InitOptions;
  if APool <> nil then
    FPool := APool
  else
  begin
    FPool := CreateThreadPool(1);      { 自有池随实例生命周期 Shutdown }
    FOwnsPool := True;
  end;
end;

destructor TAgentLoop.Destroy;
begin
  if FOwnsPool and (FPool <> nil) then
    FPool.Shutdown;
  inherited Destroy;
end;

procedure TAgentLoop.AddTool(const ATool: IAgentTool);
var
  N, I: Integer;
begin
  if ATool = nil then
    raise EAgentError.CreateLocal(aecConfig, 'tool is nil');
  ValidateToolSpec(ATool.Spec);
  for I := 0 to High(FSpecs) do
    if FSpecs[I].Name = ATool.Spec.Name then
      raise EAgentError.CreateLocal(aecConfig,
        'duplicate tool "' + ATool.Spec.Name + '"');
  N := Length(FTools);
  SetLength(FTools, N + 1);
  FTools[N] := ATool;
  SetLength(FSpecs, N + 1);
  FSpecs[N] := ATool.Spec;
end;

procedure TAgentLoop.SetEventHook(AHandler: TLoopEventHandler);
begin
  FOnEvent := AHandler;
end;

procedure TAgentLoop.SetEventHook(AHandler: TLoopEventHandlerMethod);
begin
  FOnEvent := procedure(const AE: TLoopEvent)
    begin
      AHandler(AE);
    end;
end;

procedure TAgentLoop.SetEventHook(AHandler: TLoopEventHandlerProc);
begin
  FOnEvent := procedure(const AE: TLoopEvent)
    begin
      AHandler(AE);
    end;
end;

procedure TAgentLoop.SetPreToolCall(AHook: TLoopHook);
begin
  FPreHook := AHook;
end;

procedure TAgentLoop.SetPreToolCall(AHook: TLoopHookMethod);
begin
  FPreHook := function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict
    begin
      Result := AHook(ASpec, AArgsJson);
    end;
end;

procedure TAgentLoop.SetPreToolCall(AHook: TLoopHookProc);
begin
  FPreHook := function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict
    begin
      Result := AHook(ASpec, AArgsJson);
    end;
end;

procedure TAgentLoop.SetPostToolResult(AHook: TLoopHook);
begin
  FPostHook := AHook;
end;

procedure TAgentLoop.SetPostToolResult(AHook: TLoopHookMethod);
begin
  FPostHook := function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict
    begin
      Result := AHook(ASpec, AArgsJson);
    end;
end;

procedure TAgentLoop.SetPostToolResult(AHook: TLoopHookProc);
begin
  FPostHook := function(const ASpec: TToolSpec;
    const AArgsJson: TJsonText): THookVerdict
    begin
      Result := AHook(ASpec, AArgsJson);
    end;
end;

procedure TAgentLoop.Fire(const AKind: TLoopEventKind; ARound: Integer;
  const AToolName, AToolCallId: string; AElapsedMs: Int64);
var
  E: TLoopEvent;
begin
  if FOnEvent = nil then
    Exit;
  E := Default(TLoopEvent);
  E.Kind := AKind;
  E.Round := ARound;
  E.ToolName := AToolName;
  E.ToolCallId := AToolCallId;
  E.ElapsedMs := AElapsedMs;
  FOnEvent(E);                         { 回调异常不吞：直接冒泡 }
end;

function TAgentLoop.HasSpec(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FSpecs) do
    if FSpecs[I].Name = AName then
      Exit(True);
  Result := False;
end;

function TAgentLoop.FindSpec(const AName: string): TToolSpec;
var
  I: Integer;
begin
  for I := 0 to High(FSpecs) do
    if FSpecs[I].Name = AName then
      Exit(FSpecs[I]);
  Result := Default(TToolSpec);
end;

function TAgentLoop.FindTool(const AName: string): IAgentTool;
var
  I: Integer;
begin
  for I := 0 to High(FTools) do
    if FTools[I].Spec.Name = AName then
      Exit(FTools[I]);
  Result := nil;
end;

{ 一轮推理：Stream 排水至 EOF；折叠由完成对象内部经 fold 完成（D1 唯一实现）。
  False = 运行令牌已取消 }
function TAgentLoop.CompleteRound(const AReq: TCompletionRequest;
  out AMsg: TMessage): Boolean;
var
  C: IAgentCompletion;
  D: TStreamDelta;
begin
  Result := True;
  C := FProvider.Stream(AReq, Options.Cancel);
  while C.NextDelta(D) do
    ;                                  { 排水：增量由内部 fold 累积 }
  if Assigned(Options.Cancel) and Options.Cancel.IsCancelled then
    Exit(False);
  AMsg := C.GetMessage;
end;

function TAgentLoop.Run(const AUserText: string): IAgentLoopRun;
var
  Seed: TMessageArray;
begin
  SetLength(Seed, 1);
  Seed[0] := Default(TMessage);
  Seed[0].Role := mrUser;
  SetLength(Seed[0].Parts, 1);
  Seed[0].Parts[0] := Default(TPart);
  Seed[0].Parts[0].Kind := pkText;
  Seed[0].Parts[0].Text := AUserText;
  Result := Run(Seed);
end;

function TAgentLoop.Run(const AMessages: TMessageArray): IAgentLoopRun;
var
  R: TLoopRun;
  LClock: IAgentClock;
  Transcript: TMessageArray;
  RunStartMs: Int64;
  Req: TCompletionRequest;
  M, Asst: TMessage;
  Round: Integer;
  RoundsDone: Integer;
  Calls: array of Integer;
  I, N, CI, J: Integer;
  BatchSig, PrevSig: string;
  Streak: Integer;
  OutUsed: Int64;
  Warned: Boolean;
  CalledCount: Integer;
  GuidedReason: TLoopOutcome;
  DoGuided: Boolean;
  Allowance: Integer;
  Slots: array of TSlot;
  Jobs: array of TToolJob;
  SlotJob: array of Integer;           { Slots[i] → Jobs 下标；-1=无 job }
  One: array[0..0] of TToolJob;
  AllParallel: Boolean;
  LStopped: Boolean;
  Verdict: THookVerdict;
  ChildTok: IAsyncCancellationToken;
  Env: TToolResult;
  TM: TMessage;
  LOpt: TAgentLoopOptions;

  procedure SynthErr(var ASlot: TSlot; const AMsg: string);
  var
    LB: IJsonBuilder;
  begin
    LB := JsonBuilder;
    LB.BeginObject;
    LB.Key('error');
    LB.Str(AMsg);
    LB.EndObject;
    ASlot.Res := Default(TToolResult);
    ASlot.Res.ContentJson := LB.ToString;
    ASlot.Res.IsError := True;
  end;

  { job 对象仅由 Jobs 数组持有：任何路径离开本轮都必须释放（含异常冒泡）}
  procedure FreeJobs;
  var
    K: Integer;
  begin
    for K := 0 to High(Jobs) do
      Jobs[K].Free;
    SetLength(Jobs, 0);
  end;

  { 批签名：全部工具调用的 name+args 有序串（防打转判定用）}
  function SigOf(const AMsg: TMessage): string;
  var
    K: Integer;
    LB: IJsonBuilder;
  begin
    LB := JsonBuilder;
    LB.BeginArray;
    for K := 0 to High(AMsg.Parts) do
      if AMsg.Parts[K].Kind = pkToolCall then
      begin
        LB.Str(AMsg.Parts[K].ToolName);
        LB.Str(AMsg.Parts[K].ArgumentsJson);
      end;
    LB.EndArray;
    Result := LB.ToString;
  end;

  function TokenTripped: Boolean;
  begin
    Result := Assigned(LOpt.Cancel) and LOpt.Cancel.IsCancelled;
  end;

  function Elapsed: Int64;
  begin
    Result := LClock.NowMs - RunStartMs;
  end;

  procedure AppendToolTurn;
  var
    K: Integer;
  begin
    if Length(Slots) = 0 then
      Exit;
    TM := Default(TMessage);
    TM.Role := mrTool;
    for K := 0 to High(Slots) do
    begin
      SetLength(TM.Parts, K + 1);
      TM.Parts[K] := Default(TPart);
      TM.Parts[K].Kind := pkToolResult;
      TM.Parts[K].ToolCallId :=
        Asst.Parts[Slots[K].CallPartIdx].ToolCallId;
      TM.Parts[K].ResultJson := Slots[K].Res.ContentJson;
      TM.Parts[K].IsError := Slots[K].Res.IsError;
    end;
    N := Length(Transcript);
    SetLength(Transcript, N + 1);
    Transcript[N] := TM;
  end;

  { 引导收尾（normative 统一路径）：追加 system 引导 → 禁工具推理一次。
    成功 → FinalMessage=引导回复、Outcome=触发原因；失败 → roFailed +
    LastError；取消 → False（调用方转 roCancelled）}
  function GuidedFinish(AReason: TLoopOutcome;
    const ACurrentAssistant: TMessage): Boolean;
  var
    G, M2: TMessage;
    Req2: TCompletionRequest;
    N2: Integer;
  begin
    G := Default(TMessage);
    G.Role := mrSystem;
    SetLength(G.Parts, 1);
    G.Parts[0] := Default(TPart);
    G.Parts[0].Kind := pkText;
    G.Parts[0].Text := CLOOP_GUIDANCE_TEXT;
    N2 := Length(Transcript);
    SetLength(Transcript, N2 + 1);
    Transcript[N2] := G;

    Req2 := LOpt.RequestBase;
    Req2.Messages := Copy(Transcript, 0, Length(Transcript));
    Req2.Tools := nil;                 { 禁工具推理 }
    if not CompleteRound(Req2, M2) then
      Exit(False);

    N2 := Length(Transcript);
    SetLength(Transcript, N2 + 1);
    Transcript[N2] := M2;
    if MessageText(M2) <> '' then
    begin
      R.WFinal := M2;
      R.WHasFinal := True;
    end
    else
    begin
      { 引导轮无文本产出：以触发时的 assistant 兜底 }
      R.WFinal := ACurrentAssistant;
      R.WHasFinal := not ACurrentAssistant.IsEmpty;
    end;
    R.WOutcome := AReason;
    Result := True;
  end;

begin
  if FProvider = nil then
    raise EAgentError.CreateLocal(aecConfig, 'provider is required');
  if Options.RequestBase.Model = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'loop options RequestBase.Model is required');

  R := TLoopRun.Create;
  Result := R;
  R.InitUsageUnknowns;                 { 零值会误判 Known（哨兵=-1）}

  LOpt := Options;
  if LOpt.Clock <> nil then
    LClock := LOpt.Clock
  else
    LClock := NewSystemClock;

  Transcript := Copy(AMessages, 0, Length(AMessages));
  RunStartMs := LClock.NowMs;
  RoundsDone := 0;
  OutUsed := 0;
  Warned := False;
  CalledCount := 0;
  PrevSig := '';
  Streak := 0;
  R.WOutcome := roFailed;              { 兜底：未显式收尾的路径必须响亮 }

  Fire(levRunStart, 0, '', '', Elapsed);

  for Round := 1 to LOpt.MaxRounds do
  begin
    Inc(RoundsDone);
    if TokenTripped() then
    begin
      R.WOutcome := roCancelled;
      Break;
    end;

    Req := LOpt.RequestBase;
    Req.Messages := Copy(Transcript, 0, Length(Transcript));
    Req.Tools := FSpecs;
    Fire(levRoundStart, Round, '', '', Elapsed);

    try
      if not CompleteRound(Req, M) then
      begin
        R.WOutcome := roCancelled;
        Fire(levRoundEnd, Round, '', '', Elapsed);
        Break;
      end;
    except
      on Ex: EAgentError do
      begin
        AcquireExceptionObject;          { 所有权移交 TLoopRun（析构 Free）}
        R.WLastError := Ex;
        R.WOutcome := roFailed;
        Fire(levRoundEnd, Round, '', '', Elapsed);
        Break;
      end;
    end;

    Asst := M;
    N := Length(Transcript);
    SetLength(Transcript, N + 1);
    Transcript[N] := Asst;

    { 预算结算：已知 usage 字段累计；输出预算 80% 触发一次性预警 }
    if Asst.Usage.Known then
    begin
      R.AccumulateUsage(Asst.Usage);
      if Asst.Usage.OutputTokens <> CUsageUnknown then
        OutUsed := OutUsed + Asst.Usage.OutputTokens;
      if (LOpt.MaxOutputTokens > 0) and (not Warned) and
        (OutUsed * 5 > LOpt.MaxOutputTokens * 4) then
      begin
        Warned := True;
        Fire(levBudgetWarning, Round, '', '', Elapsed);
      end;
    end;

    { 收集本轮工具调用 }
    SetLength(Calls, 0);
    for I := 0 to High(Asst.Parts) do
      if Asst.Parts[I].Kind = pkToolCall then
      begin
        N := Length(Calls);
        SetLength(Calls, N + 1);
        Calls[N] := I;
      end;

    if Length(Calls) = 0 then
    begin
      R.WOutcome := roCompleted;
      R.WFinal := Asst;
      R.WHasFinal := not Asst.IsEmpty;
      Fire(levRoundEnd, Round, '', '', Elapsed);
      Break;
    end;

    { 三终止统一判定（执行前）：防打转 / 输出预算 / 调用数达限 / 轮数用尽 }
    BatchSig := SigOf(Asst);
    if BatchSig = PrevSig then
      Inc(Streak)
    else
      Streak := 1;
    PrevSig := BatchSig;

    Allowance := Length(Calls);
    DoGuided := False;
    GuidedReason := roRoundsExhausted;

    if (LOpt.DoomLoopThreshold > 0) and (Streak >= LOpt.DoomLoopThreshold) then
    begin
      DoGuided := True;
      GuidedReason := roDoomLoop;
    end
    else if (LOpt.MaxOutputTokens > 0) and
      (OutUsed >= LOpt.MaxOutputTokens) then
    begin
      DoGuided := True;
      GuidedReason := roBudgetExhausted;
    end
    else if (LOpt.MaxToolCalls > 0) and
      (CalledCount >= LOpt.MaxToolCalls) then
    begin
      DoGuided := True;
      GuidedReason := roBudgetExhausted;
    end
    else if LOpt.MaxToolCalls > 0 then
    begin
      Allowance := LOpt.MaxToolCalls - CalledCount;
      if Allowance > Length(Calls) then
        Allowance := Length(Calls);
    end
    else if Round >= LOpt.MaxRounds then
    begin
      DoGuided := True;                { 最后仍带调用：轮数用尽 }
      GuidedReason := roRoundsExhausted;
    end;

    if DoGuided then
    begin
      { 引导轮失败 → roFailed 就位不冒泡；取消 → roCancelled }
      try
        if GuidedFinish(GuidedReason, Asst) then
          Fire(levRoundEnd, Round, '', '', Elapsed)
        else
        begin
          R.WOutcome := roCancelled;
          Fire(levRoundEnd, Round, '', '', Elapsed);
        end;
      except
        on Ex: EAgentError do
        begin
          AcquireExceptionObject;        { 所有权移交 TLoopRun（析构 Free）}
          R.WLastError := Ex;
          R.WOutcome := roFailed;
          Fire(levRoundEnd, Round, '', '', Elapsed);
        end;
      end;
      Break;
    end;

    { ---- 批装配（轮线程）：pre-hook → 校验 → 建 job 或合成结果 ----
      job 对象仅由 Jobs 持有：本轮任何离开路径（含异常冒泡）经 finally 释放 }
    SetLength(Slots, 0);
    SetLength(Jobs, 0);
    SetLength(SlotJob, 0);
    LStopped := False;
    try
      for CI := 0 to Allowance - 1 do
      begin
        I := Calls[CI];
        N := Length(Slots);
        SetLength(Slots, N + 1);
        Slots[N] := Default(TSlot);
        Slots[N].Kind := skExec;
        Slots[N].CallPartIdx := I;
        Slots[N].Spec := FindSpec(Asst.Parts[I].ToolName);
        SetLength(SlotJob, N + 1);
        SlotJob[N] := -1;

        Fire(levToolCallStart, Round, Asst.Parts[I].ToolName,
          Asst.Parts[I].ToolCallId, Elapsed);

        if not HasSpec(Asst.Parts[I].ToolName) then
        begin
          Slots[N].Kind := skUnknown;
          SynthErr(Slots[N], 'unknown tool "' +
            Asst.Parts[I].ToolName + '"');
        end
        else
        begin
          Verdict := hvProceed;
          if FPreHook <> nil then
            Verdict := FPreHook(Slots[N].Spec,
              Asst.Parts[I].ArgumentsJson);
          case Verdict of
            hvBlock:
              begin
                Slots[N].Kind := skBlocked;
                SynthErr(Slots[N], 'blocked by pre-tool-call hook');
              end;
            hvStop:
              begin
                LStopped := True;
                Break;
              end;
            hvProceed:
              begin
                Slots[N].Res :=
                  ValidateToolArguments(Slots[N].Spec,
                    Asst.Parts[I].ArgumentsJson);
                if Slots[N].Res.IsError then
                  Slots[N].Kind := skInvalid
                else
                begin
                  if Assigned(LOpt.Cancel) then
                    ChildTok := LOpt.Cancel.CreateChildToken
                  else
                    ChildTok := nil;
                  J := Length(Jobs);
                  SetLength(Jobs, J + 1);
                  Jobs[J] := TToolJob.Create(FindTool(Slots[N].Spec.Name),
                    Asst.Parts[I].ArgumentsJson,
                    NewToolContext(ChildTok, CI), ChildTok,
                    Slots[N].Spec.TimeoutMs);
                  SlotJob[N] := J;
                end;
              end;
          end;
        end;
      end;

      if LStopped then
        SetLength(Slots, Length(Slots) - 1); { stop 的调用不执行不回喂 }

      { ---- 执行：全 tcParallel 才整批并行；否则逐个单元素批保序
        （LIFECYCLE §5：串/并行都经线程池）。取消在切片边界生效，
        未完成项已被合成 cancelled error result ---- }
      if Length(Jobs) > 0 then
      begin
        AllParallel := True;
        for I := 0 to High(Jobs) do
          if not (tcParallel in Slots[SlotJob[I]].Spec.Capabilities) then
          begin
            AllParallel := False;
            Break;
          end;
        if AllParallel then
          RunToolBatch(Jobs, FPool, LClock, LOpt.Cancel)
        else
          for I := 0 to High(Jobs) do
          begin
            One[0] := Jobs[I];
            RunToolBatch(One, FPool, LClock, LOpt.Cancel);
          end;
      end;

      { ---- 截断信封化 → post-hook（只见截断后载荷，DoS 时序）→ 定槽 ---- }
      for I := 0 to High(Slots) do
      begin
        if (Slots[I].Kind <> skExec) or (SlotJob[I] < 0) then
          Continue;
        Env := EnvelopeTruncation(Jobs[SlotJob[I]].Res,
          LOpt.TruncateLines, LOpt.TruncateBytes);
        if FPostHook <> nil then
        begin
          Verdict := FPostHook(Slots[I].Spec, Env.ContentJson);
          if Verdict = hvBlock then
          begin
            SynthErr(Slots[I], 'blocked by post-tool-result hook');
            Env := Slots[I].Res;
          end
          else if Verdict = hvStop then
            LStopped := True;          { 本结果保留，run 就此结束 }
        end;
        Slots[I].Res := Env;
        Inc(CalledCount);              { 预算只计实际执行的调用 }
      end;
    finally
      FreeJobs;
    end;

    for I := 0 to High(Slots) do
      Fire(levToolCallEnd, Round,
        Asst.Parts[Slots[I].CallPartIdx].ToolName,
        Asst.Parts[Slots[I].CallPartIdx].ToolCallId, Elapsed);

    AppendToolTurn;
    Fire(levRoundEnd, Round, '', '', Elapsed);

    if TokenTripped() then
    begin
      R.WOutcome := roCancelled;
      Break;
    end;
    if LStopped then
    begin
      { hook stop：当前 assistant 即终点（未执行的后续调用不回喂）}
      R.WOutcome := roCompleted;
      R.WFinal := Asst;
      R.WHasFinal := not Asst.IsEmpty;
      Break;
    end;
  end;{for}

  Fire(levRunEnd, RoundsDone, '', '', Elapsed);
  R.WTranscript := Transcript;
end;

end.
