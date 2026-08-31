program test_fallback;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fallback,
  nextpas.core.test;

{ WithFallback 容灾链语义（API.md §装饰器组合；TESTING §3 test_fallback 行）：
  主成不触备、白名单内切备、白名单外直通、全链耗尽透传最后原始错误、
  流式首 delta 后失败不降级、取消后不切、OnSwitch 钩子序。
  全程离线：本地可控桩 provider，零网络零睡眠 }

type
  { 恒行为桩：Complete/Stream 按配置抛错或回一行文本；计数调用 }
  TStubProvider = class(TInterfacedObject, IAgentProvider)
  private
    FName: string;
    FErrCode: TAgentErrorCode;
    FErrMsg: string;
    FFailStreamMid: Boolean;         { 流式首 delta 正常、次 delta 抛错 }
  public
    Calls: Integer;
    StreamCalls: Integer;
    constructor Create(const AName: string; AErrCode: TAgentErrorCode;
      const AErrMsg: string; AFailStreamMid: Boolean = False);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

  { 成功流：单 text delta 即 EOF }
  TOkCompletion = class(TInterfacedObject, IAgentCompletion)
  public
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 中途失败流：首 delta 正常投递，第二次 NextDelta 抛指定错误 }
  TMidFailCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FErrCode: TAgentErrorCode;
    FErrMsg: string;
    FFirst: Boolean;
  public
    constructor Create(AErrCode: TAgentErrorCode; const AErrMsg: string);
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

var
  { OnSwitch 观测（单线程套件专用，各用例开头 ResetObs）；
    平行数组记录序号/目标名/先前错误码，避免测试内引转换工具 }
  GSwIdx: array of Integer;
  GSwName: array of string;
  GSwPriorCode: array of TAgentErrorCode;

procedure ResetObs;
begin
  GSwIdx := nil;
  GSwName := nil;
  GSwPriorCode := nil;
end;

function SwitchCount: Integer;
begin
  Result := Length(GSwIdx);
end;

function StubText: TMessage;
begin
  Result := Default(TMessage);
  SetLength(Result.Parts, 1);
  Result.Parts[0] := Default(TPart);
  Result.Parts[0].Kind := pkText;
  Result.Parts[0].Text := 'stub';
end;

constructor TStubProvider.Create(const AName: string;
  AErrCode: TAgentErrorCode; const AErrMsg: string;
  AFailStreamMid: Boolean);
begin
  inherited Create;
  FName := AName;
  FErrCode := AErrCode;
  FErrMsg := AErrMsg;
  FFailStreamMid := AFailStreamMid;
end;

function TStubProvider.GetName: string;
begin
  Result := FName;
end;

function TStubProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function TStubProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  Inc(Calls);
  if FErrCode <> aecNone then
    raise EAgentError.CreateUpstream(FErrCode, FName, FErrMsg,
      'req-' + FName, '', CRetryAfterUnknown);
  Result := StubText;
end;

function TStubProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function TStubProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Inc(StreamCalls);
  if FFailStreamMid then
    Exit(TMidFailCompletion.Create(FErrCode, FErrMsg));
  if FErrCode <> aecNone then
    raise EAgentError.CreateUpstream(FErrCode, FName, FErrMsg,
      'req-' + FName, '', CRetryAfterUnknown);
  Result := TOkCompletion.Create;
end;

{ ---- TOkCompletion ---- }

function TOkCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  ADelta := Default(TStreamDelta);
  ADelta.Kind := sdkTextDelta;
  ADelta.TextDelta := 'stub';
  Result := False;                   { 单 delta 已随本次返回，下次即 EOF }
end;

procedure TOkCompletion.Cancel;
begin
  { no-op }
end;

function TOkCompletion.GetCancelled: Boolean;
begin
  Result := False;
end;

function TOkCompletion.GetMessage: TMessage;
begin
  Result := StubText;
end;

function TOkCompletion.GetUsage: TTokenUsage;
begin
  Result := Default(TTokenUsage);
end;

{ ---- TMidFailCompletion ---- }

constructor TMidFailCompletion.Create(AErrCode: TAgentErrorCode;
  const AErrMsg: string);
begin
  inherited Create;
  FErrCode := AErrCode;
  FErrMsg := AErrMsg;
  FFirst := True;
end;

function TMidFailCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  if FFirst then
  begin
    FFirst := False;
    ADelta := Default(TStreamDelta);
    ADelta.Kind := sdkEnvelope;
    ADelta.MessageId := 'mid-1';
    Exit(True);
  end;
  raise EAgentError.CreateUpstream(FErrCode, 'primary', FErrMsg,
    'req-mid', '', CRetryAfterUnknown);
end;

procedure TMidFailCompletion.Cancel;
begin
  { no-op }
end;

function TMidFailCompletion.GetCancelled: Boolean;
begin
  Result := False;
end;

function TMidFailCompletion.GetMessage: TMessage;
begin
  Result := Default(TMessage);
end;

function TMidFailCompletion.GetUsage: TTokenUsage;
begin
  Result := Default(TTokenUsage);
end;

function P(const AName: string; AErrCode: TAgentErrorCode;
  const AErrMsg: string; AFailStreamMid: Boolean = False): IAgentProvider;
begin
  Result := TStubProvider.Create(AName, AErrCode, AErrMsg, AFailStreamMid);
end;

function Req: TCompletionRequest;
begin
  Result := TCompletionRequest.New('m').WithUserText('hi');
end;

{ 主成功：备家零调用 }
procedure TestPrimaryOkNoBackup;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  M: TMessage;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecNone, '');
  B := TStubProvider.Create('b', aecNone, '');
  M := NewFallbackProvider([A, B], F).Complete(Req);
  Check(MessageText(M) = 'stub', 'primary answer');
  Check((A.Calls = 1) and (B.Calls = 0), 'backup untouched on success');
  Check(SwitchCount = 0, 'no switch events on success');
end;

{ 白名单内：主败切备成功 }
procedure TestFailoverWithinWhitelist;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  M: TMessage;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecTimeout, 'upstream hung');
  B := TStubProvider.Create('b', aecNone, '');
  M := NewFallbackProvider([A, B], F).Complete(Req);
  Check(MessageText(M) = 'stub', 'backup answers');
  Check((A.Calls = 1) and (B.Calls = 1), 'failover happened');
end;

{ 白名单外：首错立即直通，不切不通知 }
procedure TestNonWhitelistDirectRaise;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  Raised: Boolean;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecInvalidRequest, 'bad payload');
  B := TStubProvider.Create('b', aecNone, '');
  Raised := False;
  try
    NewFallbackProvider([A, B], F).Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecInvalidRequest, 'original code passes');
      Check(Pos('bad payload', E.Message) > 0, 'original message passes');
    end;
  end;
  Check(Raised, 'raised');
  Check((B.Calls = 0) and (SwitchCount = 0),
    'no failover outside whitelist');
end;

{ 全链耗尽：透传最后一家原始错误（码与消息都是最后家的）}
procedure TestChainExhaustedPassesLast;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  Raised: Boolean;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecTransport, 'conn reset');
  B := TStubProvider.Create('b', aecServer, 'second site 500');
  Raised := False;
  try
    NewFallbackProvider([A, B], F).Complete(Req);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecServer, 'last error code');
      Check(Pos('second site 500', E.Message) > 0,
        'last error message (not first)');
    end;
  end;
  Check(Raised and (A.Calls = 1) and (B.Calls = 1),
    'both attempted exactly once');
end;

{ 流式首 delta 门：主路中途失败发生在包装之后——不降级、备家零调用 }
procedure TestStreamMidFailNoFailover;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  W: IAgentCompletion;
  D: TStreamDelta;
  FirstOk, Raised: Boolean;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecServer, 'mid boom', True);
  B := TStubProvider.Create('b', aecNone, '');
  W := NewFallbackProvider([A, B], F).Stream(Req);
  FirstOk := W.NextDelta(D);
  Check(FirstOk, 'first delta delivered via gate');
  Check(D.Kind = sdkEnvelope, 'first delta is envelope');
  Raised := False;
  try
    while W.NextDelta(D) do ;
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecServer, 'mid-stream error surfaces raw');
    end;
  end;
  Check(Raised, 'mid-stream raised');
  Check((SwitchCount = 0) and (B.StreamCalls = 0),
    'no failover after first delta (delivery-not-duplicated)');
end;

{ 取消优先：令牌预取消——两家都不被调用，抛取消而非链上错误 }
procedure TestCancelledTriesNothing;
var
  A, B: TStubProvider;
  F: TFallbackPolicy;
  Tok: IAsyncCancellationToken;
  Raised: Boolean;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := TStubProvider.Create('a', aecNone, '');
  B := TStubProvider.Create('b', aecNone, '');
  Tok := CreateCancellationToken;
  Tok.Cancel;
  Raised := False;
  try
    NewFallbackProvider([A, B], F).Complete(Req, Tok);
  except
    on E: EAgentError do
    begin
      Raised := True;
      Check(E.ErrorCode = aecCancelled, 'cancelled wins');
    end;
  end;
  Check(Raised and (A.Calls = 0) and (B.Calls = 0),
    'nothing attempted when cancelled');
end;

{ OnSwitch 钩子序与参数：三链两降级，序号 1/2、目标名与先前错误码正确 }
procedure TestOnSwitchHookSequence;
var
  A, B, C: IAgentProvider;
  F: TFallbackPolicy;
  M: TMessage;
begin
  ResetObs;
  F := TFallbackPolicy.Default;
  A := P('alpha', aecRateLimited, 'rl-1');
  B := P('beta', aecServer, 'srv-2');
  C := P('gamma', aecNone, '');
  F := TFallbackPolicy.Default.WithOnSwitch(
    procedure(AIndex: Integer; const AProviderName: string;
      AErrCode: TAgentErrorCode; const AErrMsg: string)
    begin
      SetLength(GSwIdx, Length(GSwIdx) + 1);
      SetLength(GSwName, Length(GSwName) + 1);
      SetLength(GSwPriorCode, Length(GSwPriorCode) + 1);
      GSwIdx[High(GSwIdx)] := AIndex;
      GSwName[High(GSwName)] := AProviderName;
      GSwPriorCode[High(GSwPriorCode)] := AErrCode;
    end);
  M := NewFallbackProvider([A, B, C], F).Complete(Req);
  Check(MessageText(M) = 'stub', 'chain eventually answers');
  CheckEqual(2, SwitchCount, 'two switches for three providers');
  CheckEqual(1, GSwIdx[0], 'first switch targets index 1');
  CheckEqual('beta', GSwName[0], 'first switch targets beta');
  Check(GSwPriorCode[0] = aecRateLimited, 'prior failure code reported');
  CheckEqual(2, GSwIdx[1], 'second switch targets index 2');
  CheckEqual('gamma', GSwName[1], 'second switch targets gamma');
  Check(GSwPriorCode[1] = aecServer, 'second prior code reported');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.fallback');
  T.Test('primary ok no backup', @TestPrimaryOkNoBackup);
  T.Test('failover within whitelist', @TestFailoverWithinWhitelist);
  T.Test('non whitelist direct raise', @TestNonWhitelistDirectRaise);
  T.Test('chain exhausted passes last', @TestChainExhaustedPassesLast);
  T.Test('stream mid fail no failover', @TestStreamMidFailNoFailover);
  T.Test('cancelled tries nothing', @TestCancelledTriesNothing);
  T.Test('on switch hook sequence', @TestOnSwitchHookSequence);
  if not T.Run then Halt(1);
end.
