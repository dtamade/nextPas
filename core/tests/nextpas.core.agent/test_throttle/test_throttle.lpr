program test_throttle;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.throttle,
  nextpas.core.test;

{ WithThrottle 客户端限流语义（API.md §装饰器组合；TESTING §3 test_throttle 行）：
  有票直通零等待、拒绝后按 gate 建议睡（fake clock 零真实睡眠）、
  建议未指明走轮询步长、累计等待超窗/重取次数封顶→本地 aecRateLimited
  （'throttled: ' 前缀归因分离，RetryAfterMs 保真）、取消打断等待、
  NewTokenBucketGate 真桶突发语义。全程离线零真实睡眠 }

type
  { 脚本化 gate：按队首建议值拒绝 N 次后恒放行；或进入粘滞恒拒模式 }
  TFakeGate = class(TInterfacedObject, IAgentRateGate)
  private
    FScript: array of Int64;         { 待拒绝序列（元素=本次建议毫秒）}
    FStickySuggest: Int64;           { >0：脚本耗尽后仍恒拒并给此建议 }
    FScriptPos: Integer;
  public
    AcquireCalls: Integer;
    function TryAcquire(out ARetryAfterMs: Int64): Boolean;
    procedure RejectNext(ASuggestMs: Int64);
    procedure RejectForever(ASuggestMs: Int64);
  end;

  { 成功桩 provider：计数调用 }
  TStubProvider = class(TInterfacedObject, IAgentProvider)
  public
    Calls: Integer;
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

var
  GWaitNo: array of Integer;
  GWaitMs: array of Int64;

procedure ResetObs;
begin
  GWaitNo := nil;
  GWaitMs := nil;
end;

procedure RecordWait(AWaitNo: Integer; ANextMs: Int64);
begin
  SetLength(GWaitNo, Length(GWaitNo) + 1);
  SetLength(GWaitMs, Length(GWaitMs) + 1);
  GWaitNo[High(GWaitNo)] := AWaitNo;
  GWaitMs[High(GWaitMs)] := ANextMs;
end;

function TFakeGate.TryAcquire(out ARetryAfterMs: Int64): Boolean;
begin
  Inc(AcquireCalls);
  if FScriptPos <= High(FScript) then
  begin
    ARetryAfterMs := FScript[FScriptPos];
    Inc(FScriptPos);
    Exit(False);
  end;
  if FStickySuggest > 0 then
  begin
    ARetryAfterMs := FStickySuggest;
    Exit(False);
  end;
  ARetryAfterMs := 0;
  Result := True;
end;

procedure TFakeGate.RejectNext(ASuggestMs: Int64);
begin
  SetLength(FScript, Length(FScript) + 1);
  FScript[High(FScript)] := ASuggestMs;
end;

procedure TFakeGate.RejectForever(ASuggestMs: Int64);
begin
  FStickySuggest := ASuggestMs;
end;

function TStubProvider.GetName: string;
begin
  Result := 'stub';
end;

function TStubProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TStubProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  Inc(Calls);
  Result := Default(TMessage);
  SetLength(Result.Parts, 1);
  Result.Parts[0] := Default(TPart);
  Result.Parts[0].Kind := pkText;
  Result.Parts[0].Text := 'stub';
end;

function TStubProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := nil;                     { 本套件不经流式断言取票路径 }
end;

function TStubProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := Stream(AReq);
end;

function Req: TCompletionRequest;
begin
  Result := TCompletionRequest.New('m').WithUserText('hi');
end;

{ 有票直通：gate 一问即放，零等待零钩子 }
procedure TestTicketPassesImmediately;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  M: TMessage;
begin
  ResetObs;
  G := TFakeGate.Create;
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  M := NewThrottledProvider(P, G, C, TThrottlePolicy.Default).Complete(Req);
  Check(MessageText(M) = 'stub', 'inner answer passes through');
  Check((G.AcquireCalls = 1) and (P.Calls = 1), 'single acquire, inner hit');
  Check(Length(GWaitNo) = 0, 'no wait hook fired');
end;

{ 单次拒绝：按建议值睡后重取成功，OnWait 上报 (1, 建议) }
procedure TestRejectedOnceThenSucceeds;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  Pol: TThrottlePolicy;
  M: TMessage;
begin
  ResetObs;
  G := TFakeGate.Create;
  G.RejectNext(40);
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  Pol := TThrottlePolicy.Default.WithOnWait(
    procedure(AWaitNo: Integer; ANextRetryAfterMs: Int64)
    begin
      RecordWait(AWaitNo, ANextRetryAfterMs);
    end);
  M := NewThrottledProvider(P, G, C, Pol).Complete(Req);
  Check(MessageText(M) = 'stub', 'succeeds after one wait');
  Check(G.AcquireCalls = 2, 're-acquired after sleep');
  Check(C.LastSleepRequestMs = 40, 'slept exactly suggested ms');
  CheckEqual(1, Length(GWaitNo), 'one wait reported');
  CheckEqual(1, GWaitNo[0], 'wait number is 1-based');
  CheckEqual(Int64(40), GWaitMs[0], 'wait duration equals suggestion');
end;

{ 建议未指明（<=0）：按轮询步长兜底而非盲睡 0 }
procedure TestUnknownSuggestionPollStep;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  Pol: TThrottlePolicy;
  M: TMessage;
begin
  ResetObs;
  G := TFakeGate.Create;
  G.RejectNext(0);                   { gate 明示"未指明" }
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  Pol := TThrottlePolicy.Default.WithOnWait(
    procedure(AWaitNo: Integer; ANextRetryAfterMs: Int64)
    begin
      RecordWait(AWaitNo, ANextRetryAfterMs);
    end);
  M := NewThrottledProvider(P, G, C, Pol).Complete(Req);
  Check(MessageText(M) = 'stub', 'poll path succeeds');
  Check(C.LastSleepRequestMs = 25, 'idle poll step used (25ms)');
  CheckEqual(Int64(25), GWaitMs[0], 'hook sees poll step too');
end;

{ 累计等待超 MaxWaitMs：本地 aecRateLimited——'throttled: ' 前缀 +
  RetryAfterMs=gate 最近建议值；inner 从未被触 }
procedure TestWaitBudgetExceededLocalRateLimited;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  Pol: TThrottlePolicy;
  Raised: Boolean;
begin
  ResetObs;
  G := TFakeGate.Create;
  G.RejectForever(60);
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  Pol := TThrottlePolicy.Default;
  Pol.MaxWaitMs := 50;
  Pol.OnWait :=
    procedure(AWaitNo: Integer; ANextRetryAfterMs: Int64)
    begin
      RecordWait(AWaitNo, ANextRetryAfterMs);
    end;
  Raised := False;
  try
    NewThrottledProvider(P, G, C, Pol).Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecRateLimited, 'local shaping code');
      Check(Pos('throttled:', E.Message) = 1, 'attribution prefix');
      Check(E.RetryAfterMs = 60, 'retry-after from last suggestion');
    end;
  end;
  Check(Raised, 'raised');
  Check((P.Calls = 0) and (G.AcquireCalls = 1),
    'never reached network or inner');
  CheckEqual(1, Length(GWaitNo), 'budget blown on first wait');
end;

{ 重取次数封顶：MaxAcquires 内未得票即拒，即使预算尚余 }
procedure TestMaxAcquiresCap;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  Pol: TThrottlePolicy;
  Raised: Boolean;
begin
  ResetObs;
  G := TFakeGate.Create;
  G.RejectForever(1);
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  Pol := TThrottlePolicy.Default;
  Pol.MaxWaitMs := 1000000;          { 预算充足：只考察次数上限 }
  Pol.MaxAcquires := 3;
  Pol.OnWait :=
    procedure(AWaitNo: Integer; ANextRetryAfterMs: Int64)
    begin
      RecordWait(AWaitNo, ANextRetryAfterMs);
    end;
  Raised := False;
  try
    NewThrottledProvider(P, G, C, Pol).Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecRateLimited, 'capped by acquire count');
    end;
  end;
  Check(Raised and (P.Calls = 0), 'raised without inner call');
  CheckEqual(3, Length(GWaitNo), 'exactly MaxAcquires wait rounds');
  Check(G.AcquireCalls = 3, 'one acquire per round, raise on last');
end;

{ 取消打断等待：首次 OnWait 即取消令牌 → SleepMs 入口判否，
  立即以 EAgentCancelled 收场 }
procedure TestCancelInterruptsWait;
var
  G: TFakeGate;
  C: TFakeClock;
  P: TStubProvider;
  Pol: TThrottlePolicy;
  Tok: IAsyncCancellationToken;
  Raised: Boolean;
begin
  ResetObs;
  G := TFakeGate.Create;
  G.RejectNext(30);
  C := TFakeClock.Create;
  P := TStubProvider.Create;
  Tok := CreateCancellationToken;
  Pol := TThrottlePolicy.Default.WithOnWait(
    procedure(AWaitNo: Integer; ANextRetryAfterMs: Int64)
    begin
      RecordWait(AWaitNo, ANextRetryAfterMs);
      Tok.Cancel;                    { 睡前打断：等待必须可取消穿透 }
    end);
  Raised := False;
  try
    NewThrottledProvider(P, G, C, Pol).Complete(Req, Tok);
  except
    on E: EAgentCancelled do
      Raised := True;
  end;
  Check(Raised, 'cancelled during wait surfaces as cancellation');
  Check((P.Calls = 0) and (Length(GWaitNo) = 1),
    'hook fired once, inner never reached');
end;

{ NewTokenBucketGate：真桶突发语义——burst=2 内连取两票真、第三票拒且
  建议值未指明（适配器契约）}
procedure TestTokenBucketGateBurstTwo;
var
  Gate: IAgentRateGate;
  S: Int64;
begin
  ResetObs;
  Gate := NewTokenBucketGate(1000, 2);
  Check(Gate.TryAcquire(S), 'first burst token');
  Check(Gate.TryAcquire(S), 'second burst token');
  Check(not Gate.TryAcquire(S), 'third immediate take refused');
  Check(S = 0, 'bucket adapter suggests unknown (0)');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.throttle');
  T.Test('ticket passes immediately', @TestTicketPassesImmediately);
  T.Test('rejected once then succeeds', @TestRejectedOnceThenSucceeds);
  T.Test('unknown suggestion poll step', @TestUnknownSuggestionPollStep);
  T.Test('wait budget exceeded local rate limited',
    @TestWaitBudgetExceededLocalRateLimited);
  T.Test('max acquires cap', @TestMaxAcquiresCap);
  T.Test('cancel interrupts wait', @TestCancelInterruptsWait);
  T.Test('token bucket gate burst two', @TestTokenBucketGateBurstTwo);
  if not T.Run then Halt(1);
end.
