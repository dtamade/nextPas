{**
 * nextpas.core.agent.loop.impl - 多轮工具循环实现：状态机与编排本体。
 *
 * 契约权威：core/docs/agent/API.md §6；ARCHITECTURE §3.3/§5；DESIGN D14；
 * LIFECYCLE §4/§5。实现与文档冲突时先改文档。
 *
 * 分工：类型由 loop.types、预算判定由 loop.budget、工具批执行由
 * loop.exec 承载；本单元聚合三者完成 Run→Infer→ToolExec→终止判定。
 * 薄门面见 nextpas.core.agent.loop（re-export）。
 *}

unit nextpas.core.agent.loop.impl;

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
  nextpas.core.agent.tools,
  nextpas.core.agent.loop.types,
  nextpas.core.agent.loop.budget,
  nextpas.core.agent.loop.exec;

type
  TLoopOutcome = nextpas.core.agent.loop.types.TLoopOutcome;
  TLoopEventKind = nextpas.core.agent.loop.types.TLoopEventKind;
  TLoopEvent = nextpas.core.agent.loop.types.TLoopEvent;
  TLoopEventHandler = nextpas.core.agent.loop.types.TLoopEventHandler;
  TLoopEventHandlerMethod = nextpas.core.agent.loop.types.TLoopEventHandlerMethod;
  TLoopEventHandlerProc = nextpas.core.agent.loop.types.TLoopEventHandlerProc;
  THookVerdict = nextpas.core.agent.loop.types.THookVerdict;
  TLoopHook = nextpas.core.agent.loop.types.TLoopHook;
  TLoopHookMethod = nextpas.core.agent.loop.types.TLoopHookMethod;
  TLoopHookProc = nextpas.core.agent.loop.types.TLoopHookProc;
  TAgentLoopOptions = nextpas.core.agent.loop.types.TAgentLoopOptions;
  IAgentLoopRun = nextpas.core.agent.loop.types.IAgentLoopRun;

const
  CLOOP_GUIDANCE_TEXT = nextpas.core.agent.loop.types.CLOOP_GUIDANCE_TEXT;

type
  { 回调不在 Options 里：SetXxx 是唯一注入通道，避免双通道绕过归一化 }
  { F-H22/F-L04：OwnsPool 语义——一参构造自建 CreateThreadPool(1) 随实例 Shutdown；二参注入外部池不接管。
    默认单线程池使 [P,P] 并行静默退化为串行：文档化为显式约束，需真并行请注入 Pool(>=2)。 }
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
      out AMsg: TMessage): Boolean;
  public
    constructor Create(const AProvider: IAgentProvider); overload;
    constructor Create(const AProvider: IAgentProvider;
      const APool: IThreadPool); overload;
    destructor Destroy; override;
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
    Options: TAgentLoopOptions;
    function Run(const AUserText: string): IAgentLoopRun; overload;
    function Run(const AMessages: TMessageArray): IAgentLoopRun; overload;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.agent.pricing,
  nextpas.core.agent.textutil,
  nextpas.core.agent.loop.run;

const
  CDEFAULT_MAX_ROUNDS = 10;
  CDEFAULT_DOOM_THRESHOLD = 3;
  CDEFAULT_TRUNCATE_LINES = 2000;
  CDEFAULT_TRUNCATE_BYTES = 65536;

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
  FPool := CreateThreadPool(1);
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
    FPool := CreateThreadPool(1);
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
  FOnEvent(E);
end;

function TAgentLoop.HasSpec(const AName: string): Boolean;
begin
  Result := LoopHasSpec(FSpecs, AName);
end;

function TAgentLoop.FindSpec(const AName: string): TToolSpec;
begin
  Result := LoopFindSpec(FSpecs, AName);
end;

function TAgentLoop.FindTool(const AName: string): IAgentTool;
begin
  Result := LoopFindTool(FTools, AName);
end;

function TAgentLoop.CompleteRound(const AReq: TCompletionRequest;
  out AMsg: TMessage): Boolean;
var
  C: IAgentCompletion;
  D: TStreamDelta;
begin
  Result := True;
  C := FProvider.Stream(AReq, Options.Cancel);
  while C.NextDelta(D) do
    ;
  if (Assigned(Options.Cancel) and Options.Cancel.IsCancelled) or C.GetCancelled then
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
  Round, RoundsDone, I, N, CI, LIdx: Integer;
  BatchSig, PrevSig: string;
  Streak: Integer;
  OutUsed: Int64;
  Warned: Boolean;
  CalledCount: Integer;
  GuidedReason: TLoopOutcome;
  DoGuided, LStopped, PostStopped: Boolean;
  Allowance, JCount, SCount: Integer;
  Slots: array of TSlot;
  Jobs: array of TToolJob;
  SlotJob: array of Integer;
  Verdict: THookVerdict;
  ChildTok: IAsyncCancellationToken;
  Env: TToolResult;
  TM: TMessage;
  LOpt: TAgentLoopOptions;
  LCost: Int64;
  Calls: array of Integer;

  procedure FreeJobs;
  var
    K: Integer;
  begin
    for K := 0 to High(Jobs) do
      Jobs[K].Free;
    SetLength(Jobs, 0);
  end;

  function SigOf(const AMsg: TMessage): string; inline;
  begin
    Result := AgentBuildBatchSignature(AMsg);
  end;

  function TokenTripped: Boolean; inline;
  begin
    Result := Assigned(LOpt.Cancel) and LOpt.Cancel.IsCancelled;
  end;

  function Elapsed: Int64; inline;
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
    SetLength(TM.Parts, Length(Slots));
    for K := 0 to High(Slots) do
    begin
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

  function GuidedFinish(AReason: TLoopOutcome;
    const ACurrentAssistant: TMessage): Boolean;
  var
    G: TMessage;
    Req2: TCompletionRequest;
    M2: TMessage;
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
    Req2.Messages := System.Copy(Transcript, 0, Length(Transcript));
    Req2.Tools := nil;
    if not CompleteRound(Req2, M2) then
      Exit(False);
    R.AccumulateUsage(M2.Usage);
    if Assigned(LOpt.UsageSink) then
    try
      LCost := LoopCostForMessage(M2);
      LOpt.UsageSink.RecordUsage(FProvider.GetName, Req2, M2.Usage, LCost);
    except
    end;
    OutUsed := LoopAddOutUsed(OutUsed, M2, FProvider);
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
  R.InitUsageUnknowns;
  LOpt := Options;
  if LOpt.MaxRounds <= 0 then
    raise EAgentError.CreateLocal(aecConfig, 'loop MaxRounds must be >=1');
  if LOpt.MaxToolCalls < 0 then
    raise EAgentError.CreateLocal(aecConfig, 'loop MaxToolCalls must be >=0');
  if LOpt.Clock <> nil then
    LClock := LOpt.Clock
  else
    LClock := NewSystemClock;
  Transcript := System.Copy(AMessages, 0, Length(AMessages));
  RunStartMs := LClock.NowMs;
  RoundsDone := 0;
  OutUsed := 0;
  Warned := False;
  CalledCount := 0;
  PrevSig := '';
  Streak := 0;
  R.WOutcome := roFailed;
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
    Req.Messages := System.Copy(Transcript, 0, Length(Transcript));
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
        AcquireExceptionObject;
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
    R.AccumulateUsage(Asst.Usage);
    OutUsed := LoopAddOutUsed(OutUsed, Asst, FProvider);
    if LoopShouldWarn(OutUsed, LOpt.MaxOutputTokens, Warned) then
    begin
      Warned := True;
      Fire(levBudgetWarning, Round, '', '', Elapsed);
    end;
    if Assigned(LOpt.UsageSink) then
    try
      LCost := LoopCostForMessage(Asst);
      LOpt.UsageSink.RecordUsage(FProvider.GetName, Req, Asst.Usage, LCost);
    except
    end;
    N := 0;
    for I := 0 to High(Asst.Parts) do
      if Asst.Parts[I].Kind = pkToolCall then
        Inc(N);
    SetLength(Calls, N);
    N := 0;
    for I := 0 to High(Asst.Parts) do
      if Asst.Parts[I].Kind = pkToolCall then
      begin
        Calls[N] := I;
        Inc(N);
      end;
    if Length(Calls) = 0 then
    begin
      R.WOutcome := roCompleted;
      R.WFinal := Asst;
      R.WHasFinal := not Asst.IsEmpty;
      Fire(levRoundEnd, Round, '', '', Elapsed);
      Break;
    end;
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
    else if LoopBudgetExhausted(OutUsed, LOpt.MaxOutputTokens) then
    begin
      DoGuided := True;
      GuidedReason := roBudgetExhausted;
    end
    else if (LOpt.MaxToolCalls > 0) and (CalledCount >= LOpt.MaxToolCalls) then
    begin
      DoGuided := True;
      GuidedReason := roBudgetExhausted;
    end;
    if not DoGuided and (LOpt.MaxToolCalls > 0) then
    begin
      Allowance := LOpt.MaxToolCalls - CalledCount;
      if Allowance > Length(Calls) then
        Allowance := Length(Calls);
      if Allowance < 0 then Allowance := 0;
    end;
    if not DoGuided and (Round >= LOpt.MaxRounds) then
    begin
      DoGuided := True;
      GuidedReason := roRoundsExhausted;
    end;
    if DoGuided then
    begin
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
          AcquireExceptionObject;
          R.WLastError := Ex;
          R.WOutcome := roFailed;
          Fire(levRoundEnd, Round, '', '', Elapsed);
        end;
      end;
      Break;
    end;
    SetLength(Slots, Length(Calls));
    SetLength(SlotJob, Length(Calls));
    SetLength(Jobs, Allowance);
    for I := 0 to High(Slots) do
    begin
      SlotJob[I] := -1;
      Slots[I] := Default(TSlot);
    end;
    for I := Allowance to High(Slots) do
    begin
      Slots[I].Kind := skBlocked;
      Slots[I].CallPartIdx := Calls[I];
      Slots[I].Spec := LoopFindSpec(FSpecs, Asst.Parts[Calls[I]].ToolName);
      LoopSynthErr(Slots[I], 'tool budget exceeded (MaxToolCalls=' + nextpas.core.text.conv.IntToStr(LOpt.MaxToolCalls) + ')');
    end;
    SCount := Length(Calls);
    JCount := 0;
    LStopped := False;
    try
      for CI := 0 to Allowance - 1 do
      begin
        I := Calls[CI];
        Slots[CI].Kind := skExec;
        Slots[CI].CallPartIdx := I;
        Slots[CI].Spec := LoopFindSpec(FSpecs, Asst.Parts[I].ToolName);
        Fire(levToolCallStart, Round, Asst.Parts[I].ToolName,
          Asst.Parts[I].ToolCallId, Elapsed);
        if not LoopHasSpec(FSpecs, Asst.Parts[I].ToolName) then
        begin
          Slots[CI].Kind := skUnknown;
          LoopSynthErr(Slots[CI], 'unknown tool "' + Asst.Parts[I].ToolName + '"');
        end
        else
        begin
          Verdict := hvProceed;
          if FPreHook <> nil then
            Verdict := FPreHook(Slots[CI].Spec, Asst.Parts[I].ArgumentsJson);
          case Verdict of
            hvBlock:
              begin
                Slots[CI].Kind := skBlocked;
                LoopSynthErr(Slots[CI], 'blocked by pre-tool-call hook');
              end;
            hvStop:
              begin
                LStopped := True;
                Slots[CI].Kind := skBlocked;
                LoopSynthErr(Slots[CI], 'stopped by pre-tool-call hook');
                for LIdx := CI + 1 to Allowance - 1 do
                begin
                  Slots[LIdx].Kind := skBlocked;
                  Slots[LIdx].CallPartIdx := Calls[LIdx];
                  Slots[LIdx].Spec := LoopFindSpec(FSpecs, Asst.Parts[Calls[LIdx]].ToolName);
                  LoopSynthErr(Slots[LIdx], 'stopped by pre-tool-call hook');
                end;
                Break;
              end;
            hvProceed:
              begin
                Slots[CI].Res := ValidateToolArguments(Slots[CI].Spec,
                  Asst.Parts[I].ArgumentsJson);
                if Slots[CI].Res.IsError then
                  Slots[CI].Kind := skInvalid
                else
                begin
                  if Assigned(LOpt.Cancel) then
                    ChildTok := LOpt.Cancel.CreateChildToken
                  else
                    ChildTok := nil;
                  Jobs[JCount] := TToolJob.Create(
                    LoopFindTool(FTools, Slots[CI].Spec.Name),
                    Asst.Parts[I].ArgumentsJson,
                    NewToolContext(ChildTok, CI), ChildTok,
                    Slots[CI].Spec.TimeoutMs);
                  SlotJob[CI] := JCount;
                  Inc(JCount);
                end;
              end;
          end;
        end;
      end;
      SetLength(Jobs, JCount);
      if Length(Jobs) > 0 then
        LoopRunGrouped(Jobs, FPool, LClock, LOpt.Cancel);
      PostStopped := False;
      I := LoopFinalizeSlots(Slots, SlotJob, Jobs,
        LOpt.TruncateLines, LOpt.TruncateBytes, FPostHook, PostStopped);
      Inc(CalledCount, I);
      LStopped := LStopped or PostStopped;
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
      R.WOutcome := roCompleted;
      R.WFinal := Asst;
      R.WHasFinal := not Asst.IsEmpty;
      Break;
    end;
  end;
  Fire(levRunEnd, RoundsDone, '', '', Elapsed);
  R.WTranscript := Transcript;
end;

end.
