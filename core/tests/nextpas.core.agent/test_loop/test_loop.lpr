program test_loop;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.atomic.core,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.tools,
  nextpas.core.agent.loop,
  nextpas.core.test;

{ 工具循环（TESTING §3 test_loop 行）：预算/钩子/事件/防打转/引导收尾。
  假 Provider 在词表层直接回放 assistant 消息（不涉 wire/SSE），每次
  Stream 快照请求供 Tools=nil / transcript 增长断言；串/并行判定用共享
  原子闸门证明——真并行时 B 放行 A，退化为串行则 A 饿死以错误暴露 }

type
  { 脚本条目：正常回合回放 Msg；DoRaise 时 Stream 即抛指定 EAgentError }
  TScriptEntry = record
    Msg: TMessage;
    DoRaise: Boolean;
    RaiseCode: TAgentErrorCode;
    RaiseMsg: string;
  end;

  { 词表级假 Provider：loop 单线程调用 Stream，无需加锁 }
  TFakeProvider = class(TInterfacedObject, IAgentProvider)
  private
    FScript: array of TScriptEntry;
    FNext: Integer;
    FReqs: array of TCompletionRequest;
    function NextCompletion: TMessage;
  public
    procedure Add(const AMsg: TMessage);
    procedure AddRaise(const ACode: TAgentErrorCode; const AMsg: string);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
    function ServedCount: Integer;
    function RequestAt(AIdx: Integer): TCompletionRequest;
    function LastRequest: TCompletionRequest;
  end;

  { 一次性完成对象：增量排水即 EOF，GetMessage 回放脚本消息 }
  TFakeCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FMsg: TMessage;
  public
    constructor Create(const AMsg: TMessage);
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 事件记录器：'kind|round|tool|callid' 行；可选在指定 roundEnd 触发取消
    （轮界取消）、在指定 roundStart 抛异常（回调异常冒泡）}
  TEvRecorder = class
  private
    FLines: TStringArray;
    FWarnCount: Integer;
    FCancelOnRoundEnd: Integer;
    FRaiseOnRoundStart: Integer;
    FCancelToken: IAsyncCancellationToken;
    procedure Note(const ALine: string);
  public
    constructor Create;
    procedure OnEvent(const AE: TLoopEvent);
    function Lines: TStringArray;
    function Joined: string;
    function WarnCount: Integer;
    property CancelOnRoundEnd: Integer read FCancelOnRoundEnd
      write FCancelOnRoundEnd;
    property RaiseOnRoundStart: Integer read FRaiseOnRoundStart
      write FRaiseOnRoundStart;
    property CancelToken: IAsyncCancellationToken read FCancelToken
      write FCancelToken;
  end;

  { 固定裁决的钩子桩：记录每次被询 'name|args-or-payload' }
  THookStub = class
  private
    FVerdict: THookVerdict;
    FSeen: TStringArray;
  public
    constructor Create(AVerdict: THookVerdict);
    function Hook(const ASpec: TToolSpec;
      const AArgsJson: TJsonText): THookVerdict;
    function SeenJoined: string;
  end;

  { 计数型桩工具：Execute 记数并回 JSON 载荷；多行变体供截断测试 }
  TSimpleTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
    FName: string;
    FMultiLine: Boolean;
    FExecCount: Integer;
  public
    constructor Create(const AName: string;
      ACaps: TToolCapabilities = []; AMultiLine: Boolean = False);
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
    property ExecCount: Integer read FExecCount;
  end;

  { 并行证明闸门：A 自旋等 Go；B 进入后稍候放行。真并行 → A 快速醒转；
    若退化为串行，A 等满 guard 后以 a-starved 错误暴露 }
  TGates = class
  public
    Entered: Int32;
    GoFlag: Int32;
    constructor Create;
    function Enter: Int32;
    procedure Open;
    function IsOpen: Boolean;
  end;

  TGateToolA = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
    FGates: TGates;
  public
    constructor Create(const AGates: TGates);
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

  TGateToolB = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
    FGates: TGates;
  public
    constructor Create(const AGates: TGates);
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

{ ---- 消息构造助手 ---- }

function NewAsst(AOutTokens: Int64): TMessage;
begin
  Result := Default(TMessage);
  Result.Role := mrAssistant;
  { 不设 usage 的消息必须显式哨兵化：零值会误判 Known }
  Result.Usage.InputTokens := CUsageUnknown;
  Result.Usage.OutputTokens := CUsageUnknown;
  Result.Usage.CacheReadInputTokens := CUsageUnknown;
  Result.Usage.CacheWriteInputTokens := CUsageUnknown;
  Result.Usage.ReasoningTokens := CUsageUnknown;
  if AOutTokens >= 0 then
    Result.Usage.OutputTokens := AOutTokens;
end;

procedure AddText(var AMsg: TMessage; const AText: string);
var
  N: Integer;
begin
  N := Length(AMsg.Parts);
  SetLength(AMsg.Parts, N + 1);
  AMsg.Parts[N] := Default(TPart);
  AMsg.Parts[N].Kind := pkText;
  AMsg.Parts[N].Text := AText;
end;

procedure AddCall(var AMsg: TMessage; const AId, AName,
  AArgsJson: string);
var
  N: Integer;
begin
  N := Length(AMsg.Parts);
  SetLength(AMsg.Parts, N + 1);
  AMsg.Parts[N] := Default(TPart);
  AMsg.Parts[N].Kind := pkToolCall;
  AMsg.Parts[N].ToolCallId := AId;
  AMsg.Parts[N].ToolName := AName;
  AMsg.Parts[N].ArgumentsJson := AArgsJson;
end;

function TextTurn(const AText: string): TMessage;
begin
  Result := NewAsst(-1);
  AddText(Result, AText);
end;

function CallTurn(const AId, AName, AArgsJson: string;
  AOutTokens: Int64): TMessage;
begin
  Result := NewAsst(AOutTokens);
  AddCall(Result, AId, AName, AArgsJson);
end;

function TextOf(const AMsg: TMessage): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
      Result := Result + AMsg.Parts[I].Text;
end;

function KindStr(AKind: TLoopEventKind): string;
begin
  case AKind of
    levRunStart:      Result := 'runStart';
    levRoundStart:    Result := 'roundStart';
    levRoundEnd:      Result := 'roundEnd';
    levToolCallStart: Result := 'toolCallStart';
    levToolCallEnd:   Result := 'toolCallEnd';
    levBudgetWarning: Result := 'budgetWarning';
    levRunEnd:        Result := 'runEnd';
  end;                               { 枚举全覆盖，无需 else 分支 }
end;

{ ---- TFakeProvider / TFakeCompletion ---- }

procedure TFakeProvider.Add(const AMsg: TMessage);
var
  N: Integer;
begin
  N := Length(FScript);
  SetLength(FScript, N + 1);
  FScript[N] := Default(TScriptEntry);
  FScript[N].Msg := AMsg;
end;

procedure TFakeProvider.AddRaise(const ACode: TAgentErrorCode;
  const AMsg: string);
var
  N: Integer;
begin
  N := Length(FScript);
  SetLength(FScript, N + 1);
  FScript[N] := Default(TScriptEntry);
  FScript[N].DoRaise := True;
  FScript[N].RaiseCode := ACode;
  FScript[N].RaiseMsg := AMsg;
end;

function TFakeProvider.NextCompletion: TMessage;
var
  E: TScriptEntry;
begin
  if FNext >= Length(FScript) then
    raise EAgentError.CreateLocal(aecProtocol,
      'fake provider: script exhausted');
  E := FScript[FNext];
  Inc(FNext);
  if E.DoRaise then
    raise EAgentError.CreateLocal(E.RaiseCode, E.RaiseMsg);
  Result := E.Msg;
end;

function TFakeProvider.GetName: string;
begin
  Result := 'fake';
end;

function TFakeProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Default(TMessage);
  raise EAgentError.CreateLocal(aecProtocol,
    'fake provider is stream-only');
end;

function TFakeProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  Result := Default(TMessage);
  raise EAgentError.CreateLocal(aecProtocol,
    'fake provider is stream-only');
end;

function TFakeProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TFakeCompletion.Create(NextCompletion);
end;

function TFakeProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
var
  N: Integer;
begin
  N := Length(FReqs);
  SetLength(FReqs, N + 1);
  FReqs[N] := AReq;
  Result := TFakeCompletion.Create(NextCompletion);
end;

function TFakeProvider.ServedCount: Integer;
begin
  Result := Length(FReqs);
end;

function TFakeProvider.RequestAt(AIdx: Integer): TCompletionRequest;
begin
  Result := FReqs[AIdx];
end;

function TFakeProvider.LastRequest: TCompletionRequest;
begin
  Result := FReqs[High(FReqs)];
end;

constructor TFakeCompletion.Create(const AMsg: TMessage);
begin
  inherited Create;
  FMsg := AMsg;
end;

function TFakeCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  Result := False;
end;

procedure TFakeCompletion.Cancel;
begin
  { no-op：脚本回放不可取消 }
end;

function TFakeCompletion.GetCancelled: Boolean;
begin
  Result := False;
end;

function TFakeCompletion.GetMessage: TMessage;
begin
  Result := FMsg;
end;

function TFakeCompletion.GetUsage: TTokenUsage;
begin
  Result := FMsg.Usage;
end;

{ ---- TEvRecorder ---- }

constructor TEvRecorder.Create;
begin
  inherited Create;
  FCancelOnRoundEnd := 0;
  FRaiseOnRoundStart := 0;
end;

procedure TEvRecorder.Note(const ALine: string);
var
  N: Integer;
begin
  N := Length(FLines);
  SetLength(FLines, N + 1);
  FLines[N] := ALine;
end;

procedure TEvRecorder.OnEvent(const AE: TLoopEvent);
begin
  Note(KindStr(AE.Kind) + '|' + IntToStr(AE.Round) + '|' +
    AE.ToolName + '|' + AE.ToolCallId);
  if AE.Kind = levBudgetWarning then
    Inc(FWarnCount);
  if (AE.Kind = levRoundEnd) and (AE.Round = FCancelOnRoundEnd) and
    (FCancelToken <> nil) then
    FCancelToken.Cancel;
  if (AE.Kind = levRoundStart) and (AE.Round = FRaiseOnRoundStart) then
    raise EAgentError.CreateLocal(aecConfig, 'hook blew up');
end;

function TEvRecorder.Lines: TStringArray;
begin
  Result := Copy(FLines, 0, Length(FLines));
end;

function TEvRecorder.Joined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLines) do
  begin
    if I > 0 then
      Result := Result + #10;
    Result := Result + FLines[I];
  end;
end;

function TEvRecorder.WarnCount: Integer;
begin
  Result := FWarnCount;
end;

{ ---- THookStub ---- }

constructor THookStub.Create(AVerdict: THookVerdict);
begin
  inherited Create;
  FVerdict := AVerdict;
end;

function THookStub.Hook(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): THookVerdict;
var
  N: Integer;
begin
  N := Length(FSeen);
  SetLength(FSeen, N + 1);
  FSeen[N] := ASpec.Name + '|' + AArgsJson;
  Result := FVerdict;
end;

function THookStub.SeenJoined: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FSeen) do
  begin
    if I > 0 then
      Result := Result + #10;
    Result := Result + FSeen[I];
  end;
end;

{ ---- TSimpleTool ---- }

constructor TSimpleTool.Create(const AName: string;
  ACaps: TToolCapabilities; AMultiLine: Boolean);
begin
  inherited Create;
  FName := AName;
  FMultiLine := AMultiLine;
  FExecCount := 0;
  FSpec := Default(TToolSpec);
  FSpec.Name := AName;
  FSpec.Description := 'simple';
  FSpec.Capabilities := ACaps;
  FSpec.TimeoutMs := 0;
end;

function TSimpleTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TSimpleTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  Inc(FExecCount);
  Result := Default(TToolResult);
  if FMultiLine then
    Result.ContentJson :=
      'alpha'#10'beta'#10'gamma'#10'delta'#10'epsilon'
  else
    Result.ContentJson := '{"tool":"' + FName + '"}';
end;

{ ---- 并行证明闸门 ---- }

constructor TGates.Create;
begin
  inherited Create;
  Entered := 0;
  GoFlag := 0;
end;

function TGates.Enter: Int32;
begin
  Result := _backend_xadd_i32(Entered, 1);
end;

procedure TGates.Open;
begin
  _backend_xchg_i32(GoFlag, 1);
end;

function TGates.IsOpen: Boolean;
begin
  Result := _backend_xadd_i32(GoFlag, 0) <> 0;
end;

constructor TGateToolA.Create(const AGates: TGates);
begin
  inherited Create;
  FGates := AGates;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'ga';
  FSpec.Capabilities := [tcParallel];
end;

function TGateToolA.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TGateToolA.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
var
  Guard: Integer;
begin
  FGates.Enter;
  Guard := 0;
  while (not FGates.IsOpen) and (Guard < 1000) do
  begin
    NewSystemClock.SleepMs(2, nil);
    Inc(Guard);
  end;
  Result := Default(TToolResult);
  if FGates.IsOpen then
    Result.ContentJson := '"a-ok"'
  else
  begin
    Result.IsError := True;
    Result.ContentJson := '"a-starved"';
  end;
end;

constructor TGateToolB.Create(const AGates: TGates);
begin
  inherited Create;
  FGates := AGates;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'gb';
  FSpec.Capabilities := [tcParallel];
end;

function TGateToolB.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TGateToolB.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  FGates.Enter;
  { 让 A 先进入等待再放行：若串行执行，A 等不到这一刻 }
  NewSystemClock.SleepMs(5, nil);
  FGates.Open;
  Result := Default(TToolResult);
  Result.ContentJson := '"b-ok"';
end;

{ ---- 测试体 ---- }

procedure TestEventOrderSnapshot;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: IAgentTool;
  Rec: TEvRecorder;
  Run: IAgentLoopRun;
  FM: TMessage;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Rec := TEvRecorder.Create;
  try
    Prov.Add(CallTurn('c1', 'echo', '{"x":1}', -1));
    Prov.Add(TextTurn('done'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    Loop.SetEventHook(@Rec.OnEvent);
    Run := Loop.Run('hello');

    CheckEqual('runStart|0||'#10 +
      'roundStart|1||'#10 +
      'toolCallStart|1|echo|c1'#10 +
      'toolCallEnd|1|echo|c1'#10 +
      'roundEnd|1||'#10 +
      'roundStart|2||'#10 +
      'roundEnd|2||'#10 +
      'runEnd|2||', Rec.Joined, 'event sequence snapshot');
    Check(Run.Outcome = roCompleted, 'two-round run completes');
    CheckTrue(Run.TryGetFinalMessage(FM), 'final message present');
    CheckEqual('done', TextOf(Run.FinalMessage), 'final text');
    CheckFalse(Run.TotalUsage.Known,
      'usage stays unknown when provider sends none');

    CheckEqual(2, Prov.ServedCount, 'two rounds served');
    CheckLength(1, Length(Prov.RequestAt(0).Messages),
      'first request carries seed only');
    CheckLength(1, Length(Prov.RequestAt(0).Tools),
      'registered tools injected on request');
    CheckEqual('echo', Prov.RequestAt(0).Tools[0].Name,
      'tool spec name travels to request');
    CheckLength(3, Length(Prov.RequestAt(1).Messages),
      'second request sees transcript incl tool turn');
    { 厂商 prompt cache 前缀稳定性（PERFORMANCE §6）：历史消息跨轮
      字节不变、只追加 }
    CheckEqual(Prov.RequestAt(0).Messages[0].Parts[0].Text,
      Prov.RequestAt(1).Messages[0].Parts[0].Text,
      'seed user message byte-stable across rounds');
    CheckLength(1, Length(Prov.RequestAt(1).Tools),
      'tools section constant across rounds');

    TR := Run.Transcript;
    CheckLength(4, Length(TR), 'transcript user/asst/tool/asst');
    Check(TR[0].Role = mrUser, 'transcript[0] user');
    Check(TR[1].Role = mrAssistant, 'transcript[1] assistant');
    Check(TR[2].Role = mrTool, 'transcript[2] tool turn');
    Check(TR[3].Role = mrAssistant, 'transcript[3] final assistant');
  finally
    Rec.Free;
    Loop.Free;
  end;
end;

{ W10：CacheControl 经 RequestBase 模板逐轮透传——loop 零改动消费，
  打点位置由各适配器编码器决定（test_provider_anthropic §2.6 覆盖）}
procedure TestCacheControlTemplateW10;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Run: IAgentLoopRun;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  try
    Prov.Add(TextTurn('done'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.RequestBase.CacheControl := ccmAuto;
    Run := Loop.Run('hello');
    Check(Run.Outcome = roCompleted, 'run completes');
    CheckEqual(1, Prov.ServedCount, 'one round served');
    Check(Prov.RequestAt(0).CacheControl = ccmAuto,
      'template cache flag rides on round request');
  finally
    Loop.Free;
  end;
end;

procedure TestParallelBatchExecution;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Pool: IThreadPool;
  Gates: TGates;
  Asst1: TMessage;
  ToolA, ToolB: IAgentTool;
  Run: IAgentLoopRun;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Pool := CreateThreadPool(2);
  Gates := TGates.Create;
  Loop := TAgentLoop.Create(Prov, Pool);
  ToolA := TGateToolA.Create(Gates);
  ToolB := TGateToolB.Create(Gates);
  try
    Asst1 := NewAsst(-1);
    AddCall(Asst1, 'c-a', 'ga', '{}');
    AddCall(Asst1, 'c-b', 'gb', '{}');
    Prov.Add(Asst1);
    Prov.Add(TextTurn('parallel ok'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(ToolA);
    Loop.AddTool(ToolB);
    Run := Loop.Run('go');

    Check(Run.Outcome = roCompleted, 'gated batch completes');
    TR := Run.Transcript;
    CheckLength(2, Length(TR[2].Parts), 'both tool results fed back');
    Check(TR[2].Parts[0].ResultJson = '"a-ok"',
      'tool A woke via parallel hand-off (serial would starve it)');
    Check(TR[2].Parts[1].ResultJson = '"b-ok"', 'tool B payload intact');
    CheckFalse(TR[2].Parts[0].IsError, 'no synthesized errors');
    CheckEqual(2, Gates.Entered, 'both tools entered execution');
  finally
    Loop.Free;
    Pool.Shutdown;
    Gates.Free;
  end;
end;

procedure TestBudgetWarningOnce;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: IAgentTool;
  Rec: TEvRecorder;
  Run: IAgentLoopRun;
  FM: TMessage;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Rec := TEvRecorder.Create;
  try
    Prov.Add(CallTurn('c1', 'echo', '{"n":1}', 9));
    Prov.Add(CallTurn('c2', 'echo', '{"n":2}', 9));
    Prov.Add(CallTurn('c3', 'echo', '{"n":3}', 5));
    Prov.Add(TextTurn('wrap'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.MaxOutputTokens := 20;
    Loop.AddTool(Tool);
    Loop.SetEventHook(@Rec.OnEvent);
    Run := Loop.Run('hello');

    CheckEqual(1, Rec.WarnCount, 'budget warning fires exactly once');
    Check(Pos('budgetWarning|2||', Rec.Joined) > 0,
      'warning raised at round 2 (18/20 past 80%)');
    Check(Run.Outcome = roBudgetExhausted,
      'output budget triggers guided finish');
    CheckTrue(Run.TryGetFinalMessage(FM), 'guided reply is final');
    CheckEqual('wrap', TextOf(Run.FinalMessage), 'guided text');
    CheckTrue(Run.TotalUsage.Known, 'usage accumulated');
    CheckEqual(Int64(23), Run.TotalUsage.OutputTokens,
      'output tokens summed across rounds');
    CheckEqual(CUsageUnknown, Run.TotalUsage.InputTokens,
      'unknown input tokens stay sentinel');
    CheckEqual(4, Prov.ServedCount, 'three rounds + guided round');
  finally
    Rec.Free;
    Loop.Free;
  end;
end;

procedure TestDoomLoopGuidedFinish;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Rec: TEvRecorder;
  Run: IAgentLoopRun;
  FM: TMessage;
  TR: TMessageArray;
  LastReq: TCompletionRequest;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Rec := TEvRecorder.Create;
  try
    Prov.Add(CallTurn('c1', 'echo', '{"x":9}', 1));
    Prov.Add(CallTurn('c2', 'echo', '{"x":9}', 1));
    Prov.Add(CallTurn('c3', 'echo', '{"x":9}', 1));
    Prov.Add(TextTurn('doom summary'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    Loop.SetEventHook(@Rec.OnEvent);
    Run := Loop.Run('hello');

    Check(Run.Outcome = roDoomLoop,
      'third identical batch hits doom threshold');
    CheckTrue(Run.TryGetFinalMessage(FM), 'guided reply present');
    CheckEqual('doom summary', TextOf(Run.FinalMessage),
      'final is the guided summary');
    CheckEqual(2, Tool.ExecCount,
      'batch executed at streak 1 and 2 only');
    CheckEqual(0, Rec.WarnCount, 'no budget warning on doom path');

    TR := Run.Transcript;
    CheckLength(8, Length(TR),
      'user+3x(asst/tool)+guidance+summary transcript');
    Check(TR[6].Role = mrSystem, 'guidance injected as system role');
    CheckEqual(CLOOP_GUIDANCE_TEXT, TextOf(TR[6]),
      'guidance text verbatim');

    LastReq := Prov.LastRequest;
    CheckLength(0, Length(LastReq.Tools),
      'guided round runs with tools disabled');
    CheckLength(7, Length(LastReq.Messages),
      'guided request sees transcript incl guidance');
    Check(LastReq.Messages[6].Role = mrSystem,
      'guidance travels inside request');
    Check(Pos('runEnd|3||', Rec.Joined) > 0,
      'run ends after three rounds');
  finally
    Rec.Free;
    Loop.Free;
  end;
end;

procedure TestMaxToolCallsTrimsBatch;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Run: IAgentLoopRun;
  Asst1, Asst2: TMessage;
  FM: TMessage;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  try
    Asst1 := NewAsst(-1);
    AddCall(Asst1, 'c-a', 'echo', '{"i":1}');
    AddCall(Asst1, 'c-b', 'echo', '{"i":2}');
    Asst2 := NewAsst(-1);
    AddCall(Asst2, 'c-c', 'echo', '{"i":3}');
    Prov.Add(Asst1);
    Prov.Add(Asst2);
    Prov.Add(TextTurn('call cap'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.MaxToolCalls := 1;
    Loop.AddTool(Tool);
    Run := Loop.Run('hello');

    Check(Run.Outcome = roBudgetExhausted,
      'call-count cap routes into guided finish');
    CheckTrue(Run.TryGetFinalMessage(FM), 'guided reply present');
    CheckEqual('call cap', TextOf(Run.FinalMessage), 'guided text');
    CheckEqual(1, Tool.ExecCount, 'only first call ever executed');
    TR := Run.Transcript;
    CheckLength(1, Length(TR[2].Parts),
      'batch trimmed to remaining allowance');
    CheckEqual('c-a', TR[2].Parts[0].ToolCallId,
      'kept call is the first of the batch');
    CheckEqual(3, Prov.ServedCount,
      'r1 + r2 completion + guided round served');
  finally
    Loop.Free;
  end;
end;

procedure TestRoundsExhaustedGuidedFinish;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Run: IAgentLoopRun;
  FM: TMessage;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  try
    Prov.Add(CallTurn('c1', 'echo', '{"n":1}', -1));
    Prov.Add(CallTurn('c2', 'echo', '{"n":2}', -1));
    Prov.Add(TextTurn('rounds done'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.MaxRounds := 2;
    Loop.AddTool(Tool);
    Run := Loop.Run('hello');

    Check(Run.Outcome = roRoundsExhausted,
      'max rounds with pending calls guided-finishes');
    CheckTrue(Run.TryGetFinalMessage(FM), 'guided reply present');
    CheckEqual('rounds done', TextOf(Run.FinalMessage),
      'guided text');
    CheckEqual(1, Tool.ExecCount, 'only round 1 batch executed');
    CheckEqual(3, Prov.ServedCount,
      'r1 + r2 completion + guided round served');
  finally
    Loop.Free;
  end;
end;

procedure TestPreHookBlock;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Hook: THookStub;
  Run: IAgentLoopRun;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('danger');
  Hook := THookStub.Create(hvBlock);
  try
    Prov.Add(CallTurn('c1', 'danger', '{"k":1}', -1));
    Prov.Add(TextTurn('blocked path'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    Loop.SetPreToolCall(@Hook.Hook);
    Run := Loop.Run('hello');

    CheckEqual('danger|{"k":1}', Hook.SeenJoined,
      'pre hook consulted once with raw args');
    CheckEqual(0, Tool.ExecCount, 'blocked call never executes');
    TR := Run.Transcript;
    CheckTrue(TR[2].Parts[0].IsError, 'blocked result fed as error');
    Check(Pos('blocked by pre-tool-call hook',
      TR[2].Parts[0].ResultJson) > 0, 'block reason named in payload');
    Check(Run.Outcome = roCompleted, 'loop continues after block');
    CheckEqual('blocked path', TextOf(Run.FinalMessage),
      'next round text becomes final');
  finally
    Hook.Free;
    Loop.Free;
  end;
end;

procedure TestPreHookStopEndsRun;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool1, Tool2: TSimpleTool;
  Hook: THookStub;
  Run: IAgentLoopRun;
  Asst1: TMessage;
  FM: TMessage;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool1 := TSimpleTool.Create('t1');
  Tool2 := TSimpleTool.Create('t2');
  Hook := THookStub.Create(hvStop);
  try
    Asst1 := NewAsst(-1);
    AddCall(Asst1, 'e1', 't1', '{}');
    AddCall(Asst1, 'e2', 't2', '{}');
    Prov.Add(Asst1);
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool1);
    Loop.AddTool(Tool2);
    Loop.SetPreToolCall(@Hook.Hook);
    Run := Loop.Run('hello');

    Check(Run.Outcome = roCompleted, 'hook stop ends run cleanly');
    CheckTrue(Run.TryGetFinalMessage(FM), 'assistant is final');
    Check(FM.Role = mrAssistant, 'final is the calling assistant');
    CheckLength(2, Length(FM.Parts),
      'final assistant keeps both declared calls');
    CheckEqual('t1', FM.Parts[0].ToolName,
      'stopped call is the first declared slot');
    CheckLength(2, Length(Run.Transcript),
      'no tool turn appended after stop');
    CheckEqual(0, Tool1.ExecCount, 'stopped call not executed');
    CheckEqual(0, Tool2.ExecCount, 'later calls never reached');
    CheckEqual(1, Prov.ServedCount, 'run ended before second round');
  finally
    Hook.Free;
    Loop.Free;
  end;
end;

procedure TestPostHookSeesTruncatedPayload;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Hook: THookStub;
  Run: IAgentLoopRun;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('multi', [], True);
  Hook := THookStub.Create(hvProceed);
  try
    Prov.Add(CallTurn('c1', 'multi', '{}', -1));
    Prov.Add(TextTurn('seen'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.TruncateLines := 2;
    Loop.AddTool(Tool);
    Loop.SetPostToolResult(@Hook.Hook);
    Run := Loop.Run('hello');

    Check(Pos('"truncated":true', Hook.SeenJoined) > 0,
      'post hook sees truncated envelope (DoS ordering)');
    Check(Pos('gamma', Hook.SeenJoined) = 0,
      'payload already cut to line budget before hook');
    TR := Run.Transcript;
    CheckFalse(TR[2].Parts[0].IsError, 'envelope is a success result');
    Check(Pos('"truncated":true', TR[2].Parts[0].ResultJson) > 0,
      'truncated envelope is what gets fed back');
    Check(Run.Outcome = roCompleted, 'run completes normally');
  finally
    Hook.Free;
    Loop.Free;
  end;
end;

procedure TestUnknownToolSynthesized;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Run: IAgentLoopRun;
  TR: TMessageArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  try
    Prov.Add(CallTurn('c1', 'nosuch', '{}', -1));
    Prov.Add(TextTurn('recovered'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    Run := Loop.Run('hello');

    CheckEqual(0, Tool.ExecCount, 'nothing executed');
    TR := Run.Transcript;
    CheckTrue(TR[2].Parts[0].IsError, 'unknown tool feeds error');
    Check(Pos('unknown tool', TR[2].Parts[0].ResultJson) > 0,
      'error names the failure class');
    Check(Pos('nosuch', TR[2].Parts[0].ResultJson) > 0,
      'error names the tool');
    Check(Run.Outcome = roCompleted, 'model recovers next round');
    CheckEqual('recovered', TextOf(Run.FinalMessage), 'final text');
  finally
    Loop.Free;
  end;
end;

procedure TestProviderFailureSetsLastError;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Run: IAgentLoopRun;
  FM: TMessage;
  Raised: Boolean;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Raised := False;
  try
    Prov.Add(CallTurn('c1', 'echo', '{}', -1));
    Prov.AddRaise(aecRateLimited, '429 slow down');
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    try
      Run := Loop.Run('hello');
    except
      on Ex: EAgentError do
        Raised := True;
    end;
    CheckFalse(Raised, 'round failure must not escape Run');
    Check(Assigned(Run), 'run result still returned');
    Check(Run.Outcome = roFailed, 'outcome is failed');
    CheckNotNil(Pointer(Run.LastError), 'last error attached');
    Check(Run.LastError.ErrorCode = aecRateLimited,
      'error code preserved through loop');
    Check(Pos('429 slow down', Run.LastError.Message) > 0,
      'error message preserved');
    CheckFalse(Run.TryGetFinalMessage(FM), 'no final message on failure');
  finally
    Loop.Free;
  end;
end;

procedure TestCancelAtRoundBoundary;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Rec: TEvRecorder;
  Tok: IAsyncCancellationToken;
  Run: IAgentLoopRun;
  FM: TMessage;
  Lines: TStringArray;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Rec := TEvRecorder.Create;
  Tok := CreateCancellationToken;
  try
    Prov.Add(CallTurn('c1', 'echo', '{"n":1}', -1));
    Prov.Add(CallTurn('c2', 'echo', '{"n":2}', -1));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.Options.Cancel := Tok;
    Loop.AddTool(Tool);
    Rec.CancelToken := Tok;
    Rec.CancelOnRoundEnd := 1;
    Loop.SetEventHook(@Rec.OnEvent);
    Run := Loop.Run('hello');

    Check(Run.Outcome = roCancelled, 'boundary cancel reported');
    CheckFalse(Run.TryGetFinalMessage(FM),
      'cancelled run has no final message');
    CheckFalse(Run.TotalUsage.Known,
      'usage untouched when provider sends none');
    CheckLength(3, Length(Run.Transcript),
      'round 1 tool exchange kept in transcript');
    CheckEqual(1, Prov.ServedCount, 'second round never requested');
    Lines := Rec.Lines;
    CheckLength(6, Length(Lines),
      'events stop at boundary round end + run end');
    CheckEqual('roundEnd|1||', Lines[4], 'round end recorded');
    CheckEqual('runEnd|1||', Lines[5], 'run end closes cancelled run');
  finally
    Rec.Free;
    Loop.Free;
  end;
end;

procedure TestCallbackExceptionBubbles;
var
  Prov: TFakeProvider;
  Loop: TAgentLoop;
  Tool: TSimpleTool;
  Rec: TEvRecorder;
  Raised: Boolean;
  Msg: string;
begin
  Prov := TFakeProvider.Create;
  Loop := TAgentLoop.Create(Prov);
  Tool := TSimpleTool.Create('echo');
  Rec := TEvRecorder.Create;
  try
    Prov.Add(CallTurn('c1', 'echo', '{}', -1));
    Prov.Add(TextTurn('never reached'));
    Loop.Options.RequestBase.Model := 'fake-model';
    Loop.AddTool(Tool);
    Rec.RaiseOnRoundStart := 1;
    Loop.SetEventHook(@Rec.OnEvent);
    Raised := False;
    try
      Loop.Run('hello');
    except
      on Ex: EAgentError do
      begin
        Raised := True;
        Msg := Ex.Message;
      end;
    end;
    Check(Raised, 'callback exception propagates out of Run');
    Check(Pos('hook blew up', Msg) > 0, 'original exception surfaces');
  finally
    Rec.Free;
    Loop.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.loop');
  T.Test('event order snapshot', @TestEventOrderSnapshot);
  T.Test('cache control template W10', @TestCacheControlTemplateW10);
  T.Test('parallel batch execution', @TestParallelBatchExecution);
  T.Test('budget warning once', @TestBudgetWarningOnce);
  T.Test('doom loop guided finish', @TestDoomLoopGuidedFinish);
  T.Test('max tool calls trims batch', @TestMaxToolCallsTrimsBatch);
  T.Test('rounds exhausted guided finish',
    @TestRoundsExhaustedGuidedFinish);
  T.Test('pre hook block', @TestPreHookBlock);
  T.Test('pre hook stop ends run', @TestPreHookStopEndsRun);
  T.Test('post hook sees truncated payload',
    @TestPostHookSeesTruncatedPayload);
  T.Test('unknown tool synthesized', @TestUnknownToolSynthesized);
  T.Test('provider failure sets last error',
    @TestProviderFailureSetsLastError);
  T.Test('cancel at round boundary', @TestCancelAtRoundBoundary);
  T.Test('callback exception bubbles', @TestCallbackExceptionBubbles);
  if not T.Run then Halt(1);
end.
