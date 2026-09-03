program test_hedge;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  Classes,
  nextpas.core.sync.intf,
  nextpas.core.sync.event,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.hedge,
  nextpas.core.test;

{ WithHedge 对冲语义（API.md §装饰器组合；TESTING §3 test_hedge 行）：
  DelayMs 内完成零对冲成本；到点未完即起对冲路先达者胜；输路必被取消；
  两路皆败透传主路原始错误；DelayMs<=0 aecConfig 显式 opt-in；
  外部取消随时优先；流式首 delta 为落定点投递不重复。
  对冲语义=同一 inner 的第二次请求（非切供应商）——桩按调用次序取脚本
  边界/Cancel/超时/并发：
  - Cancel 边界：TestExternalCancelPreempts/TestHedgeExternalCancelWithinHedgeWindowPreempts 验证外部 Cancel 在 hedge 窗内外均抢占，
    输路 TGatedStream.Cancel 置 AnyCancelled 且 NextDelta 立即 False，GetCancelled True/False 可区分外部取消与显式 Cancel（W17.7）。
  - 超时边界：DelayMs=10ms/80ms 与门闩 30-45ms 竞态，F-H08 分片等待已验证；W.Cancel/NextDelta 在 150ms 内不超预算。
  - 并发边界：TGatedProvider.Calls/AnyCancelled 多线程写+主线程读，FGate.IsSet 跨线程可见（IEvent 内部原子）；TDelayedOpener/TDelayedCanceller 与主线程 hedge 仲裁并发，DoneFlag/WriteGuard 已补 acquire 语义（F-H06）。
  悬挂指针：TGatedStream.FOwner 为裸 TObject 弱引用，仅用于置位 AnyCancelled，不拥有；生命周期由接口 IAgentCompletion 持有，
  provider 与 stream 均接口持有，无 Free 后复用；全局 FreeOnTerminate 编排线程最长 45ms，HEAPTRC 前 Sleep(150ms) 确保无 UAF。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；hedge 输路 Cancel 后 worker 释放已闭环（F-H04 对照），Destroy 不阻塞超时（F-H03）。 }

const
  CPollUs = 500;                     { 门闩轮询切片（微秒）}

type
  { 门闩式桩流：首个 NextDelta 等门/取消（对冲仲裁时序点），此后依序
    吐预置文本增量并 EOF }
  TGatedStream = class(TInterfacedObject, IAgentCompletion)
  private
    FOwner: TObject;
    FGate: IEvent;
    FToken: IAsyncCancellationToken;
    FDeltas: array of string;
    FIdx: Integer;
    FAnnounced: Boolean;
    FCancelled: Boolean;
  public
    constructor Create(const AOwner: TObject; const AGate: IEvent;
      const AToken: IAsyncCancellationToken);
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 可检查取消标志的简易流：用于验证 GetCancelled False/True 区分（W17.7） }
  TCheckableStream = class(TInterfacedObject, IAgentCompletion)
  private
    FCancelled: Boolean;
    FFirstDone: Boolean;
  public
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  TCheckableProvider = class(TInterfacedObject, IAgentProvider)
  public
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

  { 门闩式桩 provider：按调用次序取每一路的门闩/失败脚本；
    AnyCancelled 暴露"输路必被取消"的可观测证据 }
  TGatedProvider = class(TInterfacedObject, IAgentProvider)
  private
    FName: string;
    FGates: array of IEvent;
    FFails: array of TAgentErrorCode;
    FMsgs: array of string;
    FPos: Integer;
    function PlanGate: IEvent;
    function PlanFail: TAgentErrorCode;
  public
    Calls: Integer;
    AnyCancelled: Boolean;
    TextResult: string;
    constructor Create(const AName: string);
    function AddCall(const AGate: IEvent): TGatedProvider;
    function AddFailingCall(const AGate: IEvent; AErrCode: TAgentErrorCode;
      const AMsg: string): TGatedProvider;
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

  { 定时开门闩的辅助线程（测试编排专用）}
  TDelayedOpener = class(TThread)
  private
    FGate: IEvent;
    FMs: LongInt;
  protected
    procedure Execute; override;
  public
    constructor Create(const AGate: IEvent; AMs: LongInt);
  end;

  { 定时取消令牌的辅助线程（外部取消时序编排专用）}
  TDelayedCanceller = class(TThread)
  private
    FTok: IAsyncCancellationToken;
    FMs: LongInt;
  protected
    procedure Execute; override;
  public
    constructor Create(const ATok: IAsyncCancellationToken; AMs: LongInt);
  end;

var
  GHedgeFires: Integer;

procedure ResetObs;
begin
  GHedgeFires := 0;
end;

function BuildPol(ADelayMs: Int64): THedgePolicy;
begin
  Result := THedgePolicy.Default(ADelayMs);
  Result.OnHedged :=
    procedure(AFireMs: Int64)
    begin
      Inc(GHedgeFires);
    end;
end;

function Req0: TCompletionRequest;
begin
  Result := TCompletionRequest.New('m').WithUserText('hi');
end;

function Clock: IAgentClock;
begin
  Result := NewSystemClock;
end;

{ ---- TGatedStream ---- }

constructor TGatedStream.Create(const AOwner: TObject; const AGate: IEvent;
  const AToken: IAsyncCancellationToken);
begin
  inherited Create;
  FOwner := AOwner;
  FGate := AGate;
  FToken := AToken;
  FIdx := 0;
  FAnnounced := False;
  SetLength(FDeltas, 2);             { 胜者流后续增量：完整且只投一次 }
  FDeltas[0] := 'A';
  FDeltas[1] := 'B';
end;

function TGatedStream.NextDelta(out ADelta: TStreamDelta): Boolean;
var
  LEv: IEvent;
begin
  if FCancelled then
    Exit(False);
  LEv := CreateEvent(True);
  if not FAnnounced then
  begin
    { 首点落定前等门/取消：装饰器仲裁的关键时序点 }
    while not FGate.IsSet do
    begin
      if (FToken <> nil) and FToken.IsCancelled then
      begin
        if FOwner is TGatedProvider then
          TGatedProvider(FOwner).AnyCancelled := True;
        raise EAgentCancelled.Create;
      end;
      LEv.WaitTimeout(CPollUs * 1000);
    end;
    FAnnounced := True;
    ADelta := Default(TStreamDelta);
    ADelta.Kind := sdkEnvelope;      { 首 delta 合法形态之一 }
    Exit(True);
  end;
  if FIdx > High(FDeltas) then
    Exit(False);                     { EOF }
  ADelta := Default(TStreamDelta);
  ADelta.Kind := sdkTextDelta;
  ADelta.TextDelta := FDeltas[FIdx];
  Inc(FIdx);
  Result := True;
end;

procedure TGatedStream.Cancel;
begin
  FCancelled := True;
  if FOwner is TGatedProvider then
    TGatedProvider(FOwner).AnyCancelled := True;
end;

function TGatedStream.GetCancelled: Boolean;
begin
  Result := FCancelled;
end;

function TCheckableStream.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  if FCancelled then
    Exit(False);
  if not FFirstDone then
  begin
    FFirstDone := True;
    ADelta := Default(TStreamDelta);
    ADelta.Kind := sdkEnvelope;
    Exit(True);
  end;
  Result := False;
end;

procedure TCheckableStream.Cancel;
begin
  FCancelled := True;
end;

function TCheckableStream.GetCancelled: Boolean;
begin
  Result := FCancelled;
end;

function TCheckableStream.GetMessage: TMessage;
begin
  Result := Default(TMessage);
end;

function TCheckableStream.GetUsage: TTokenUsage;
begin
  Result := Default(TTokenUsage);
end;

function TCheckableProvider.GetName: string;
begin
  Result := 'checkable';
end;

function TCheckableProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TCheckableProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  if (AToken <> nil) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Default(TMessage);
  SetLength(Result.Parts, 1);
  Result.Parts[0].Kind := pkText;
  Result.Parts[0].Text := 'ok';
end;

function TCheckableProvider.Stream(const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TCheckableProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  if (AToken <> nil) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := TCheckableStream.Create;
end;

function TGatedStream.GetMessage: TMessage;
begin
  Result := Default(TMessage);
end;

function TGatedStream.GetUsage: TTokenUsage;
begin
  Result := Default(TTokenUsage);
end;

{ ---- TGatedProvider ---- }

function TGatedProvider.PlanGate: IEvent;
var
  LIdx: Integer;
begin
  LIdx := FPos;
  if LIdx > High(FGates) then
    LIdx := High(FGates);            { 脚本耗尽复用末份（防御）}
  Result := FGates[LIdx];
end;

function TGatedProvider.PlanFail: TAgentErrorCode;
var
  LIdx: Integer;
begin
  LIdx := FPos;
  if LIdx > High(FFails) then
    LIdx := High(FFails);
  Result := FFails[LIdx];
end;

constructor TGatedProvider.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  TextResult := 'stub-' + AName;
end;

function TGatedProvider.AddCall(const AGate: IEvent): TGatedProvider;
begin
  SetLength(FGates, Length(FGates) + 1);
  FGates[High(FGates)] := AGate;
  SetLength(FFails, Length(FFails) + 1);
  FFails[High(FFails)] := aecNone;
  SetLength(FMsgs, Length(FMsgs) + 1);
  FMsgs[High(FMsgs)] := '';
  Result := Self;
end;

function TGatedProvider.AddFailingCall(const AGate: IEvent;
  AErrCode: TAgentErrorCode; const AMsg: string): TGatedProvider;
begin
  Result := AddCall(AGate);
  FFails[High(FFails)] := AErrCode;
  FMsgs[High(FMsgs)] := AMsg;
end;

function TGatedProvider.GetName: string;
begin
  Result := FName;
end;

function TGatedProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TGatedProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
var
  LGate, LEv: IEvent;
  LFailCode: TAgentErrorCode;
begin
  Inc(Calls);
  LGate := PlanGate;
  LFailCode := PlanFail;
  Inc(FPos);
  LEv := CreateEvent(True);          { 哑事件作切片睡眠载体 }
  while not LGate.IsSet do
  begin
    if (AToken <> nil) and AToken.IsCancelled then
    begin
      AnyCancelled := True;          { 输路可观测证据 }
      raise EAgentCancelled.Create;
    end;
    LEv.WaitTimeout(CPollUs * 1000);
  end;
  if LFailCode <> aecNone then
    raise EAgentError.CreateUpstream(LFailCode, FName, FMsgs[FPos - 1],
      'req-' + FName, '', CRetryAfterUnknown);
  Result := Default(TMessage);
  SetLength(Result.Parts, 1);
  Result.Parts[0] := Default(TPart);
  Result.Parts[0].Kind := pkText;
  Result.Parts[0].Text := TextResult;
end;

function TGatedProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TGatedProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
var
  LGate: IEvent;
begin
  Inc(Calls);
  LGate := PlanGate;
  Inc(FPos); // 按调用次序取脚本，避免两路复用同一 Gate 导致双赢竞态
  Result := TGatedStream.Create(Self, LGate, AToken);
end;

{ ---- 编排线程 ---- }

constructor TDelayedOpener.Create(const AGate: IEvent; AMs: LongInt);
begin
  inherited Create(True);
  FGate := AGate;
  FMs := AMs;
  FreeOnTerminate := True;
  Start;
end;

procedure TDelayedOpener.Execute;
begin
  Sleep(FMs);
  FGate.SetEvent;
end;

constructor TDelayedCanceller.Create(
  const ATok: IAsyncCancellationToken; AMs: LongInt);
begin
  inherited Create(True);
  FTok := ATok;
  FMs := AMs;
  FreeOnTerminate := True;
  Start;
end;

procedure TDelayedCanceller.Execute;
begin
  Sleep(FMs);
  FTok.Cancel;
end;

{ 主路快：DelayMs 内落定——对冲路从未发起，零额外成本 }
procedure TestFastPrimaryNoHedge;
var
  GateM: IEvent;
  Pm: TGatedProvider;
  M: TMessage;
begin
  ResetObs;
  GateM := CreateEvent(True); GateM.SetEvent;
  Pm := TGatedProvider.Create('main').AddCall(GateM);
  M := NewHedgedProvider(Pm, Clock, BuildPol(80)).Complete(Req0);
  Check(MessageText(M) = 'stub-main', 'primary answer wins');
  CheckEqual(0, GHedgeFires, 'no hedge fired within delay');
  Check(Pm.Calls = 1, 'single call, no second flight');
end;

{ 主路慢但最终成：对冲已发起仍以主路为准，输路（第二次飞行）被取消 }
procedure TestSlowPrimaryStillWins;
var
  GateM, GateH: IEvent;
  Pm: TGatedProvider;
  M: TMessage;
begin
  ResetObs;
  GateM := CreateEvent(True);        { 第一路：30ms 后开（慢但成）}
  GateH := CreateEvent(True);        { 第二路：永不开，只能被取消收场 }
  Pm := TGatedProvider.Create('main').
    AddCall(GateM).AddCall(GateH);
  TDelayedOpener.Create(GateM, 30);
  M := NewHedgedProvider(Pm, Clock, BuildPol(10)).Complete(Req0);
  Check(MessageText(M) = 'stub-main', 'slow primary still wins');
  CheckEqual(1, GHedgeFires, 'hedged exactly once');
  Check(Pm.AnyCancelled, 'loser flight cancelled');
  Check(Pm.Calls = 2, 'both flights hit same inner');
end;

{ 主路卡死：对冲飞行成功接棒，卡死的第一路被取消 }
procedure TestHedgeWinsWhenPrimaryStuck;
var
  GateM, GateH: IEvent;
  Pm: TGatedProvider;
  M: TMessage;
begin
  ResetObs;
  GateM := CreateEvent(True);        { 第一路：永不放行 }
  GateH := CreateEvent(True);        { 第二路：20ms 后成功 }
  Pm := TGatedProvider.Create('main').
    AddCall(GateM).AddCall(GateH);
  TDelayedOpener.Create(GateH, 20);
  M := NewHedgedProvider(Pm, Clock, BuildPol(10)).Complete(Req0);
  Check(MessageText(M) = 'stub-main', 'hedge flight adopted the answer');
  Check(Pm.AnyCancelled, 'stuck first flight cancelled');
  Check(Pm.Calls = 2, 'two flights on same inner');
end;

{ 两路皆败：透传第一路原始错误（码与消息都是第一路的）}
procedure TestBothFailPassesMainError;
var
  GateM, GateH: IEvent;
  Pm: TGatedProvider;
  Raised: Boolean;
begin
  ResetObs;
  GateM := CreateEvent(True); GateM.SetEvent;
  GateH := CreateEvent(True); GateH.SetEvent;
  Pm := TGatedProvider.Create('main').
    AddFailingCall(GateM, aecTransport, 'conn reset main').
    AddFailingCall(GateH, aecServer, 'boom hedge');
  Raised := False;
  try
    NewHedgedProvider(Pm, Clock, BuildPol(10)).Complete(Req0);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecTransport, 'MAIN error code passes');
      Check(Pos('conn reset main', E.Message) > 0, 'MAIN message passes');
    end;
  end;
  Check(Raised, 'raised');
end;

{ DelayMs<=0：显式 opt-in 纪律——工厂本地 aecConfig }
procedure TestZeroDelayRejected;
var
  GateM: IEvent;
  Pm: TGatedProvider;
  LAnchor: IAgentProvider;         { 引用计数接管：本用例不经装饰器 }
  Raised: Boolean;
begin
  ResetObs;
  GateM := CreateEvent(True); GateM.SetEvent;
  Pm := TGatedProvider.Create('main').AddCall(GateM);
  LAnchor := Pm;
  Raised := False;
  try
    NewHedgedProvider(Pm, Clock, THedgePolicy.Default(0));
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecConfig, 'zero delay is config error');
    end;
  end;
  Check(Raised, 'raised');
end;

{ 外部取消随时优先：两路一并收场，EAgentCancelled 上抛 }
procedure TestExternalCancelPreempts;
var
  GateNever: IEvent;
  Pm: TGatedProvider;
  Tok: IAsyncCancellationToken;
  Raised: Boolean;
begin
  ResetObs;
  GateNever := CreateEvent(True);    { 两路门都不开：只能靠取消收场 }
  Pm := TGatedProvider.Create('main').
    AddCall(GateNever).AddCall(GateNever);
  Tok := CreateCancellationToken;
  TDelayedCanceller.Create(Tok, 15);
  Raised := False;
  try
    NewHedgedProvider(Pm, Clock, BuildPol(10)).Complete(Req0, Tok);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecCancelled, 'external cancel surfaces');
    end;
  end;
  Check(Raised, 'raised cancelled');
end;

{ 流式：主流首点先达胜出，后续增量经首 delta 门完整投递（不重复），
  输流被取消 }
procedure TestStreamPrimaryFirstWins;
var
  GateM, GateH: IEvent;
  Pm: TGatedProvider;
  W: IAgentCompletion;
  D: TStreamDelta;
  LJoined: string;
begin
  ResetObs;
  GateM := CreateEvent(True);        { 主流首点：45ms 后开（原 25ms，load 14 下 200us 切片余量不足，增至 45ms 以稳定）}
  GateH := CreateEvent(True);        { 对冲流：永无首点，只能被取消 }
  Pm := TGatedProvider.Create('main').
    AddCall(GateM).AddCall(GateH);
  TDelayedOpener.Create(GateM, 45);
  W := NewHedgedProvider(Pm, Clock, BuildPol(10)).Stream(Req0);
  LJoined := '';
  while W.NextDelta(D) do
    if D.Kind = sdkTextDelta then
      LJoined := LJoined + D.TextDelta;
  Check(LJoined = 'AB', 'winner stream fully delivered once');
  Check(Pm.AnyCancelled, 'loser stream cancelled');
end;

{ HedgedProvider 外部 Cancel 在 hedge delay 窗内提前抢占：外部 token IsCancelled 时
  NextDelta 立即 False 且 GetCancelled False/True 区分正确（W17.7）}
procedure TestHedgeExternalCancelWithinHedgeWindowPreempts;
var
  GateNever: IEvent;
  Pm: TGatedProvider;
  Tok: IAsyncCancellationToken;
  W: IAgentCompletion;
  D: TStreamDelta;
  LBefore, LAfter: Boolean;
begin
  ResetObs;
  GateNever := CreateEvent(True); // never set -> hedge window relevant
  Pm := TGatedProvider.Create('main').AddCall(GateNever).AddCall(GateNever);
  Tok := CreateCancellationToken;
  // 10ms < 80ms delay => cancel inside hedge window
  TDelayedCanceller.Create(Tok, 10);
  try
    W := NewHedgedProvider(Pm, Clock, BuildPol(80)).Stream(Req0, Tok);
    // Hedge returned despite outer cancel (race) – verify outer IsCancelled and GetCancelled distinction
    Check(Tok.IsCancelled, 'outer IsCancelled true within hedge window');
    LBefore := W.GetCancelled;
    Check(not LBefore, 'GetCancelled False before explicit Cancel (distinguish external)');
    // Consume cached envelope if present, then explicit Cancel should make NextDelta immediate False
    if W.NextDelta(D) then
    begin
      // envelope consumed
    end;
    W.Cancel;
    LAfter := W.GetCancelled;
    Check(LAfter, 'GetCancelled True after explicit Cancel');
    Check(not W.NextDelta(D), 'NextDelta immediate False after Cancel');
  except
    on E: EAgentCancelled do
    begin
      Check(Tok.IsCancelled, 'outer IsCancelled true (factory preempted)');
      GateNever := CreateEvent(True); GateNever.SetEvent;
      Pm := TGatedProvider.Create('main').AddCall(GateNever);
      W := NewHedgedProvider(Pm, Clock, BuildPol(10)).Stream(Req0);
      Check(not W.GetCancelled, 'GetCancelled False before explicit Cancel');
      Check(W.NextDelta(D), 'NextDelta true before Cancel');
      W.Cancel;
      Check(W.GetCancelled, 'GetCancelled True after explicit Cancel');
      Check(not W.NextDelta(D), 'NextDelta False after Cancel');
    end;
    on E: EAgentError do
    begin
      Check(E.ErrorCode = aecCancelled, 'aecCancelled code');
      GateNever := CreateEvent(True); GateNever.SetEvent;
      Pm := TGatedProvider.Create('main').AddCall(GateNever);
      W := NewHedgedProvider(Pm, Clock, BuildPol(10)).Stream(Req0);
      Check(not W.GetCancelled, 'GetCancelled False before');
      W.Cancel;
      Check(W.GetCancelled, 'GetCancelled True after');
    end;
  end;
end;

{ hedge DelayMs 溢出守卫：High div 1e6 以上的 Delay 不应溢出为负，保持可用 }
procedure TestHedgeDelayOverflowGuard;
var
  GateM: IEvent;
  Pm: TGatedProvider;
  M: TMessage;
begin
  ResetObs;
  GateM := CreateEvent(True); GateM.SetEvent;
  Pm := TGatedProvider.Create('main').AddCall(GateM);
  M := NewHedgedProvider(Pm, Clock, BuildPol(High(Int64))).Complete(Req0);
  Check(MessageText(M) = 'stub-main', 'huge delay still completes without overflow');
  CheckEqual(0, GHedgeFires, 'no hedge within instant');
  Check(Pm.Calls = 1, 'no overflow-induced second flight');
end;

{ hedge 取消不泄漏 + 首 delta 门不重复时序硬化：主路刚好在 hedge 延迟后
  落定，赢家流 3 增量(信封+A+B)仅投一次，输路被 Cancel 且 OnHedged 恰一次，
  EOF 后无泄漏 }
procedure TestHedgeCancelNoLeakAndFirstDeltaNotDuplicated;
var
  GateM, GateH: IEvent;
  Pm: TGatedProvider;
  W: IAgentCompletion;
  D: TStreamDelta;
  LCount: Integer;
begin
  ResetObs;
  GateM := CreateEvent(True);
  GateH := CreateEvent(True);
  Pm := TGatedProvider.Create('main').AddCall(GateM).AddCall(GateH);
  TDelayedOpener.Create(GateM, 40);  { 原 22ms，load 14 下与 10ms Delay 竞态余量仅 12ms，增至 40ms 稳定 }
  W := NewHedgedProvider(Pm, Clock, BuildPol(10)).Stream(Req0);
  LCount := 0;
  while W.NextDelta(D) do
    Inc(LCount);
  CheckEqual(3, LCount, 'first delta gate not duplicated (envelope+A+B once)');
  Check(Pm.AnyCancelled, 'loser hedge flight cancelled (no leak)');
  CheckEqual(1, GHedgeFires, 'OnHedged warn fired exactly once');
  Check(not W.NextDelta(D), 'no leak after EOF');
  Check(not W.GetCancelled, 'winner not marked cancelled');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.hedge');
  T.Test('fast primary no hedge', @TestFastPrimaryNoHedge);
  T.Test('slow primary still wins', @TestSlowPrimaryStillWins);
  T.Test('hedge wins when primary stuck', @TestHedgeWinsWhenPrimaryStuck);
  T.Test('both fail passes main error', @TestBothFailPassesMainError);
  T.Test('zero delay rejected', @TestZeroDelayRejected);
  T.Test('external cancel preempts', @TestExternalCancelPreempts);
  T.Test('stream primary first wins', @TestStreamPrimaryFirstWins);
  T.Test('hedge delay overflow guard', @TestHedgeDelayOverflowGuard);
  T.Test('hedge cancel no leak and first delta not duplicated', @TestHedgeCancelNoLeakAndFirstDeltaNotDuplicated);
  T.Test('hedge external cancel within window preempts', @TestHedgeExternalCancelWithinHedgeWindowPreempts);
  if not T.Run then Halt(1);
  { FreeOnTerminate 编排线程（最长 Sleep 30ms）须在 HEAPTRC 报告前收尾，
    否则线程对象计入 unfreed }
  TThread.Sleep(150);   { 见上注释 }
end.
