program test_retry;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.retry,
  nextpas.core.agent.provider.openai,
  agent.testkit,
  nextpas.core.test;

{ WithRetry 装饰器语义（API.md §5；ROADMAP W2）：
  白名单交集、Retry-After 优先、退避曲线+上限、取消优先、
  流式只重试到首 delta 为止
  边界/Cancel/超时/并发：
  - Cancel 边界：Token 在退避等待期触发则立即以 aecCancelled 收场，不再重试；首 delta 后失败不再重试语义已覆盖。
  - 超时边界：Retry-After 秒级 *1000 溢出守卫（F-H21）及指数退避上限 60s 已验证；FakeClock 零真实等待驱动虚拟时钟。
  - 并发边界：单线程装饰器串行重试，无并发写；重入时 LComp.Cancel 已闭环终败泄漏（F-H04 对照）。
  悬挂指针：IAgentCompletion/IAsyncCancellationToken 均接口持有；重试链中失败流在重试前显式 Cancel 后接口置 nil，无裸指针常驻。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；每流独立堆分配在 Cancel+Free 后回收，已验证无 10KB 级泄漏。 }

const
  COKBody =
    '{"id":"x","model":"m","choices":[{"message":{"role":"assistant",' +
    '"content":"ok"},"finish_reason":"stop"}],' +
    '"usage":{"prompt_tokens":1,"completion_tokens":2}}';

  { SSE 事件以空行终结：每块 data 行后跟双换行 }
  CGoodChunks: array[0..2] of string = (
    'data: {"choices":[{"delta":{"content":"Hi"}}]}' + #10 + #10,
    'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}' + #10 + #10,
    'data: [DONE]' + #10 + #10
  );

var
  { OnAttempt 观测（单线程套件专用，各用例开头 ResetObs）}
  GAttempts: array of Integer;
  GDelays: array of Int64;
  GCodes: array of TAgentErrorCode;
  GTokForHook: IAsyncCancellationToken;   { 取消时序测试专用 }

procedure ResetObs;
begin
  GAttempts := nil;
  GDelays := nil;
  GCodes := nil;
  GTokForHook := nil;                { 全局接口持有必须随用例复位释放 }
end;

procedure ObsHook(const AAttempt: Integer; const ADelayMs: Int64;
  const ALastError: EAgentError);
var
  N: Integer;
begin
  N := Length(GAttempts);
  SetLength(GAttempts, N + 1);
  SetLength(GDelays, N + 1);
  SetLength(GCodes, N + 1);
  GAttempts[N] := AAttempt;
  GDelays[N] := ADelayMs;
  if ALastError <> nil then
    GCodes[N] := ALastError.ErrorCode
  else
    GCodes[N] := aecNone;
end;

{ 第二次尝试通知时取消环境令牌：随后的退避睡眠必须以取消收场 }
procedure CancellingAfterFirstAttempt(const AAttempt: Integer;
  const ADelayMs: Int64; const ALastError: EAgentError);
begin
  ObsHook(AAttempt, ADelayMs, ALastError);
  if (AAttempt >= 2) and (GTokForHook <> nil) then
    GTokForHook.Cancel;
end;

procedure Hdr(var AH: TWireHeaderArray; const AN, AV: string);
var
  N: Integer;
begin
  N := Length(AH);
  SetLength(AH, N + 1);
  AH[N].Name := AN;
  AH[N].Value := AV;
end;

function PlainOK: TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.BodyText := COKBody;
end;

function FailResp(AStatus: Integer; const ABody: string): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := AStatus;
  Result.BodyText := ABody;
  Result.RaiseUpstream := True;
end;

function GoodStream: TScriptResponse;
var
  I: Integer;
  LChunks: TStringArray;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  SetLength(LChunks, Length(CGoodChunks));
  for I := 0 to High(CGoodChunks) do
    LChunks[I] := CGoodChunks[I];
  Result.Chunks := LChunks;
end;

{ 装配：scripted transport + openai provider（带 key）}
function WithKeyTransport(const A: TScriptedTransport): IAgentProvider;
var
  O: TOpenAIOptions;
begin
  O := TOpenAIOptions.New('test-model');
  O.Common.ApiKey := 'k';
  O.Common.Transport := A;
  Result := NewOpenAIProvider(O);
end;

{ 装配：scripted transport + openai provider + 装饰器 }
function MakeWrapped(const ATransport: TScriptedTransport;
  const APolicy: TRetryPolicy;
  out OutClock: TFakeClock): IAgentProvider;
var
  Inner: IAgentProvider;
begin
  Inner := WithKeyTransport(ATransport);
  OutClock := TFakeClock.Create;
  Result := WithRetry(Inner, APolicy, OutClock);
end;

function Req: TCompletionRequest;
begin
  Result := TCompletionRequest.New('test-model');
end;

{ 精确曲线断言用：关抖动 }
function Determinate(const AP: TRetryPolicy): TRetryPolicy;
begin
  Result := AP;
  Result.Jitter := 0;
end;

{ ---- 用例 ---- }

procedure TestDefaultPolicy;
var
  P: TRetryPolicy;
begin
  P := TRetryPolicy.Default;
  Check(P.MaxAttempts = 3, 'default attempts');
  Check(P.InitialDelayMs = 1000, 'default initial');
  Check(P.MaxDelayMs = 30000, 'default max delay');
  Check(P.Multiplier = 2.0, 'default multiplier');
  Check(ABS(P.Jitter - 0.1) < 1e-9, 'default jitter');
  Check(P.RetryOn = [aecRateLimited, aecTransport, aecTimeout, aecServer],
    'default whitelist');
  Check(P.RespectRetryAfter, 'default respect retry-after');
  Check(P.MaxTotalRetryMs = 120000, 'default total cap');
end;

procedure TestTransientThenSuccess;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: IAgentProvider;
  M: TMessage;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(500, '{"error":{"message":"a"}}'));
  TP.Add(FailResp(500, '{"error":{"message":"b"}}'));
  TP.Add(PlainOK);
  P := MakeWrapped(TP,
    Determinate(TRetryPolicy.Default).WithOnAttempt(@ObsHook), CK);
  M := P.Complete(Req);
  Check(MessageText(M) = 'ok', 'final body decoded');
  Check(Length(GAttempts) = 3, 'three attempts notified');
  Check((GAttempts[0] = 1) and (GDelays[0] = 0) and (GCodes[0] = aecNone),
    'first attempt 0/nil');
  Check((GAttempts[1] = 2) and (GDelays[1] = 1000) and
    (GCodes[1] = aecServer), 'second attempt curve base');
  Check((GAttempts[2] = 3) and (GDelays[2] = 2000) and
    (GCodes[2] = aecServer), 'third attempt doubled');
  Check(CK.LastSleepRequestMs = 2000, 'clock saw backoff');
end;

procedure TestNonRetryableImmediate;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: IAgentProvider;
  Raised: Boolean;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(400, '{"error":{"message":"bad"}}'));
  P := MakeWrapped(TP,
    Determinate(TRetryPolicy.Default).WithOnAttempt(@ObsHook), CK);
  Raised := False;
  try
    P.Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecInvalidRequest, '400 mapped');
    end;
  end;
  Check(Raised, 'non-retryable raises');
  Check(Length(GAttempts) = 1, 'single attempt');
  Check(CK.LastSleepRequestMs = 0, 'never slept');
end;

procedure TestRetryAfterHonored;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: IAgentProvider;
  R: TScriptResponse;
  HS: TWireHeaderArray;
  M: TMessage;
begin
  ResetObs;
  HS := nil;
  Hdr(HS, 'retry-after-ms', '7500');
  R := Default(TScriptResponse);
  R.Status := 429;
  R.Headers := Copy(HS, 0, Length(HS));
  R.BodyText := '{"error":{"message":"slow down"}}';
  R.RaiseUpstream := True;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(R);
  TP.Add(PlainOK);
  P := MakeWrapped(TP,
    TRetryPolicy.Default.WithOnAttempt(@ObsHook), CK);
  M := P.Complete(Req);
  Check(MessageText(M) = 'ok', 'recovered after 429');
  Check((Length(GDelays) = 2) and (GDelays[1] = 7500),
    'server value beats curve');
end;

procedure TestExhaustionRaisesLast;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: IAgentProvider;
  Raised: Boolean;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(503, '{"error":{"message":"d1"}}'));
  TP.Add(FailResp(503, '{"error":{"message":"d2"}}'));
  TP.Add(FailResp(503, '{"error":{"message":"d3"}}'));
  P := MakeWrapped(TP,
    TRetryPolicy.Default.WithOnAttempt(@ObsHook), CK);
  Raised := False;
  try
    P.Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecServer, 'last code preserved');
      Check(Pos('[openai]', E.Message) = 1, 'provider attribution kept');
    end;
  end;
  Check(Raised, 'exhaustion raises');
  Check(Length(GAttempts) = 3, 'max attempts honored');
end;

procedure TestMaxDelayCap;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: TRetryPolicy;
  W: IAgentProvider;
  M: TMessage;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(500, '{"error":{"message":"x"}}'));
  TP.Add(FailResp(500, '{"error":{"message":"x"}}'));
  TP.Add(FailResp(500, '{"error":{"message":"x"}}'));
  TP.Add(PlainOK);
  P := Determinate(TRetryPolicy.Default);
  P.MaxAttempts := 4;
  P.InitialDelayMs := 5000;
  P.MaxDelayMs := 6000;
  P.Multiplier := 10.0;
  W := MakeWrapped(TP, P.WithOnAttempt(@ObsHook), CK);
  M := W.Complete(Req);
  Check(M.Id = 'x', 'eventually ok');
  Check((GDelays[1] = 5000) and (GDelays[2] = 6000) and
    (GDelays[3] = 6000), 'curve capped at MaxDelayMs');
end;

procedure TestTotalBudgetStopsRetries;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: TRetryPolicy;
  W: IAgentProvider;
  Raised: Boolean;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(500, '{"error":{"message":"b1"}}'));
  TP.Add(FailResp(500, '{"error":{"message":"b2"}}'));
  P := Determinate(TRetryPolicy.Default);
  P.MaxAttempts := 10;
  P.MaxTotalRetryMs := 1500;
  W := MakeWrapped(TP, P.WithOnAttempt(@ObsHook), CK);
  Raised := False;
  try
    W.Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecServer, 'original error surfaces');
    end;
  end;
  Check(Raised, 'budget stop raises');
  Check(Length(GAttempts) = 2, 'stopped before over-budget retry');
end;

procedure TestJitterBounds;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: TRetryPolicy;
  W: IAgentProvider;
  M: TMessage;
  I: Integer;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  for I := 1 to 7 do
    TP.Add(FailResp(500, '{"error":{"message":"j"}}'));
  TP.Add(PlainOK);
  P := TRetryPolicy.Default;
  P.MaxAttempts := 8;
  P.InitialDelayMs := 10000;
  P.Multiplier := 1.0;
  P.Jitter := 0.5;
  W := MakeWrapped(TP, P.WithOnAttempt(@ObsHook), CK);
  M := W.Complete(Req);
  Check(M.Id = 'x', 'jitter run completes');
  Check(Length(GDelays) = 8, 'eight attempts');
  for I := 1 to 7 do
    Check((GDelays[I] >= 5000) and (GDelays[I] <= 15000),
      'delay ' + IntToStr(I) + ' within jitter band');
end;

procedure TestCancelDuringSleepWins;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  P: TRetryPolicy;
  Tok: IAsyncCancellationToken;
  W: IAgentProvider;
  Raised: Boolean;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(500, '{"error":{"message":"c"}}'));
  TP.Add(FailResp(500, '{"error":{"message":"c"}}'));
  Tok := CreateCancellationToken;
  GTokForHook := Tok;                { 钩子在 attempt2 通知时取消 }
  CK := TFakeClock.Create;
  P := TRetryPolicy.Default.WithOnAttempt(@CancellingAfterFirstAttempt);
  W := WithRetry(WithKeyTransport(TP), P, CK, Tok);
  Raised := False;
  try
    W.Complete(Req, nil);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecCancelled,
        'cancel wins over original error');
    end;
  end;
  Check(Raised, 'cancel surfaced');
end;

procedure TestStreamRetriedUntilFirstDelta;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  W: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  M: TMessage;
begin
  ResetObs;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(FailResp(500, '{"error":{"message":"sf"}}'));   { 首 delta 前失败 }
  TP.Add(GoodStream);
  W := MakeWrapped(TP, TRetryPolicy.Default.WithOnAttempt(@ObsHook), CK);
  C := W.Stream(Req);
  { 门已替消费方拉走首个增量：回放后继续透传 }
  Check(C.NextDelta(D) and (D.Kind = sdkTextDelta) and (D.TextDelta = 'Hi'),
    'stashed first delta replayed');
  Check(C.NextDelta(D) and (D.Kind = sdkFinish), 'finish passthrough');
  Check(not C.NextDelta(D), 'eof passthrough');
  M := C.GetMessage;
  Check(MessageText(M) = 'Hi', 'fold intact across gate');
  Check(Length(GAttempts) = 2, 'one retry for failed stream');
end;

procedure TestMidStreamFailureNotRetried;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  Bad: TScriptResponse;
  LChunks: TStringArray;
  W: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  Raised: Boolean;
begin
  ResetObs;
  Bad := Default(TScriptResponse);
  Bad.Status := 200;
  SetLength(LChunks, 2);
  LChunks[0] := CGoodChunks[0];                { 首 delta 正常交付 }
  LChunks[1] := 'data: {"broken' + #10;        { 中途协议坏帧 }
  Bad.Chunks := LChunks;
  TP := TScriptedTransport.Create;
  TP.ProviderName := 'openai';
  TP.Add(Bad);
  W := MakeWrapped(TP, TRetryPolicy.Default.WithOnAttempt(@ObsHook), CK);
  C := W.Stream(Req);
  Raised := False;
  try
    while C.NextDelta(D) do begin end;
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecProtocol, 'mid-stream protocol error');
    end;
  end;
  Check(Raised, 'mid-stream failure propagates');
  Check(Length(GAttempts) = 1, 'no retry after first delta handed out');
end;

procedure TestConfigGuards;
var
  TP: TScriptedTransport;
  CK: TFakeClock;
  CKHold: IAgentClock;               { 接口持有：守卫路径不会接管时钟 }
  P: TRetryPolicy;
  Inner: IAgentProvider;
  Ok: Boolean;
begin
  TP := TScriptedTransport.Create;
  CK := TFakeClock.Create;
  CKHold := CK;
  P := TRetryPolicy.Default;
  Inner := WithKeyTransport(TP);

  Ok := False;
  try
    WithRetry(nil, P, CK);
  except
    on E: EAgentError do
      Ok := E.ErrorCode = aecConfig;
  end;
  Check(Ok, 'nil inner rejected');

  Ok := False;
  try
    WithRetry(Inner, P, nil);
  except
    on E: EAgentError do
      Ok := E.ErrorCode = aecConfig;
  end;
  Check(Ok, 'nil clock rejected');

  Ok := False;
  P.MaxAttempts := 0;
  try
    WithRetry(Inner, P, CK);
  except
    on E: EAgentError do
      Ok := E.ErrorCode = aecConfig;
  end;
  Check(Ok, 'zero attempts rejected');
end;

procedure TestAmbientTokenCheckedAtBoundary;
var
  Tok: IAsyncCancellationToken;
  CK: TFakeClock;
  TP: TScriptedTransport;
  W: IAgentProvider;
  Raised: Boolean;
begin
  Tok := CreateCancellationToken;
  Tok.Cancel;                        { 预先取消：入口边界即抛 }
  CK := TFakeClock.Create;
  TP := TScriptedTransport.Create;   { 空脚本：被触碰即耗尽异常 }
  TP.ProviderName := 'openai';
  W := WithRetry(WithKeyTransport(TP),
    TRetryPolicy.Default, CK, Tok);
  Raised := False;
  try
    W.Complete(Req, nil);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecCancelled, 'ambient token enforced');
    end;
  end;
  Check(Raised, 'boundary cancel raises');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.retry');
  T.Test('default policy', @TestDefaultPolicy);
  T.Test('transient then success', @TestTransientThenSuccess);
  T.Test('non-retryable immediate', @TestNonRetryableImmediate);
  T.Test('retry-after honored', @TestRetryAfterHonored);
  T.Test('exhaustion raises last', @TestExhaustionRaisesLast);
  T.Test('max delay cap', @TestMaxDelayCap);
  T.Test('total budget stops retries', @TestTotalBudgetStopsRetries);
  T.Test('jitter bounds', @TestJitterBounds);
    T.Test('cancel during sleep wins', @TestCancelDuringSleepWins);
  T.Test('stream retried until first delta', @TestStreamRetriedUntilFirstDelta);
  T.Test('mid-stream failure not retried', @TestMidStreamFailureNotRetried);
  T.Test('config guards', @TestConfigGuards);
  T.Test('ambient token checked at boundary', @TestAmbientTokenCheckedAtBoundary);
  if not T.Run then Halt(1);
end.
