program test_tools;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.tools,
  nextpas.core.test;

{ 工具设施（TESTING §3 test_tools 行）：名称/schema 注册校验 aecConfig；
  §1.5 参数校验失败→error result；行/字节截断信封 Truncated 标记；
  超时包装经 fake clock 生效（桩在执行体内 Advance 驱动虚拟截止，零真实等待）}

const
  CGoodSchema = '{"type":"object","required":["city"],"properties":' +
    '{"city":{"type":"string"},"days":{"type":"number"},' +
    '"urgent":{"type":"boolean"}}}';

type
  { 记录调用序的桩工具 }
  TStubTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
    FTag: string;
    FRaises: Boolean;
  public
    constructor Create(const AName, ATag: string;
      ACaps: TToolCapabilities; ATimeoutMs: Int64; ARaises: Boolean);
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
    property Tag: string read FTag;
  end;

constructor TStubTool.Create(const AName, ATag: string;
  ACaps: TToolCapabilities; ATimeoutMs: Int64; ARaises: Boolean);
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := AName;
  FSpec.Description := 'stub';
  FSpec.ParametersJson := CGoodSchema;
  FSpec.Capabilities := ACaps;
  FSpec.TimeoutMs := ATimeoutMs;
  FTag := ATag;
  FRaises := ARaises;
end;

function TStubTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TStubTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  if FRaises then
    raise EAgentError.CreateLocal(aecProtocol, 'boom inside tool');
  Result := Default(TToolResult);
  Result.ContentJson := '{"tag":"' + FTag + '"}';
end;

function WSpec(const N, P: string): TToolSpec;
begin
  Result := Default(TToolSpec);
  Result.Name := N;
  Result.Description := 't';
  Result.ParametersJson := P;
end;

procedure TestSpecValidation;
var
  Raised: Boolean;
  Code: TAgentErrorCode;

  procedure TrySpec(const ASpec: TToolSpec);
  begin
    Raised := False;
    try
      ValidateToolSpec(ASpec);
    except
      on Ex: EAgentError do
      begin
        Raised := True;
        Code := Ex.ErrorCode;
      end;
    end;
  end;

begin
  TrySpec(WSpec('weather_1-x', CGoodSchema));
  Check(not Raised, 'valid spec accepted');
  TrySpec(WSpec('', CGoodSchema));
  Check(Raised and (Code = aecConfig), 'empty name rejected');
  TrySpec(WSpec(StringOfChar('a', 65), CGoodSchema));
  Check(Raised and (Code = aecConfig), 'name over 64 chars rejected');
  TrySpec(WSpec('bad name!', CGoodSchema));
  Check(Raised and (Code = aecConfig), 'illegal char rejected');
  TrySpec(WSpec('ok', '[1,2]'));
  Check(Raised and (Code = aecConfig),
    'non-object parameters rejected at registration');
  TrySpec(WSpec('ok', '{broken'));
  Check(Raised and (Code = aecConfig), 'unparseable schema rejected');
  TrySpec(WSpec('ok', ''));
  Check(not Raised, 'schema-less tool allowed');
end;

function TryArgs(const ASpec: TToolSpec; const AArgs: string;
  out AErr: Boolean): Boolean;
var
  R: TToolResult;
begin
  R := ValidateToolArguments(ASpec, AArgs);
  AErr := R.IsError;
  Result := True;
end;

procedure TestArgumentValidation;
var
  S: TToolSpec;
  R: TToolResult;
  Err: Boolean;
  BigArgs: string;
  Deep: string;
  I: Integer;
begin
  S := WSpec('weather', CGoodSchema);

  Check(TryArgs(S, '{"city":"上海"}', Err) and (not Err),
    'required met passes');
  Check(TryArgs(S, '{"city":"x","days":3}', Err) and (not Err),
    'number accepts int');
  Check(TryArgs(S, '{"city":"x","days":1.5}', Err) and (not Err),
    'number accepts float');
  Check(TryArgs(S, '{"city":"x","urgent":true}', Err) and (not Err),
    'boolean accepts bool');

  Check(TryArgs(S, '{"days":3}', Err) and Err,
    'missing required -> error result');
  Check(TryArgs(S, '{"city":"x","days":"many"}', Err) and Err,
    'string for number -> error result');
  Check(TryArgs(S, '{"city":42}', Err) and Err,
    'number for string -> error result');
  Check(TryArgs(S, '{"city":"x","urgent":"yes"}', Err) and Err,
    'string for boolean -> error result');

  Check(TryArgs(S, 'not json', Err) and Err, 'non-json args rejected');
  Check(TryArgs(S, '[1,2]', Err) and Err, 'non-object root rejected');

  BigArgs := '{"city":"' + StringOfChar('a', 300000) + '"}';
  Check(TryArgs(S, BigArgs, Err) and Err, 'oversize precheck rejected');

  Deep := '{"city":';
  for I := 1 to 12 do
    Deep := Deep + '[';
  for I := 1 to 12 do
    Deep := Deep + ']';
  Deep := Deep + '}';
  Check(TryArgs(S, Deep, Err) and Err, 'deep nesting rejected');

  { array/object 类型不深查：声明为数组的属性给任意数组都过 }
  R := ValidateToolArguments(
    WSpec('t', '{"type":"object","properties":{"xs":{"type":"array"}}}'),
    '{"xs":[1,{"a":2}]}');
  Check(not R.IsError, 'array type not deep-checked');

  { 错误载荷是合法 JSON object 且带 error 键 }
  R := ValidateToolArguments(S, '{}');
  Check(R.IsError and (JsonParse(R.ContentJson).Root.Get('error').IsStr),
    'error result carries escaped json envelope');
end;

procedure TestTruncationEnvelope;
var
  R, Out: TToolResult;
  ManyLines: string;
  I: Integer;
  Doc: IJsonDocument;
  Multibyte: string;
begin
  R := Default(TToolResult);
  R.ContentJson := '{"ok":true}';
  Out := EnvelopeTruncation(R, 2000, 65536);
  Check((not Out.Truncated) and (Out.ContentJson = R.ContentJson),
    'small result untouched');

  ManyLines := '';
  for I := 1 to 50 do
    ManyLines := ManyLines + 'line ' + IntToStr(I) + #10;
  R.ContentJson := ManyLines;
  Out := EnvelopeTruncation(R, 10, 0);
  Check(Out.Truncated, 'line cut marks Truncated');
  Doc := JsonParse(Out.ContentJson);
  Check((not Doc.HasError) and Doc.Root.Get('truncated').AsBool,
    'envelope is legal json with truncated=true');
  { 信封是 JSON：换行在载荷里是字面 \n 转义序列 }
  Check(Pos('line 9\nline 10', Out.ContentJson) > 0,
    'kept first ten lines');
  Check(Pos('line 11', Out.ContentJson) = 0, 'dropped line 11 onward');

  R.ContentJson := 'x' + StringOfChar('y', 5000) + '终';
  Out := EnvelopeTruncation(R, 0, 100);
  Check(Out.Truncated, 'byte cut marks Truncated');
  Doc := JsonParse(Out.ContentJson);
  Check(not Doc.HasError, 'byte-cut envelope parses');
  Multibyte := Doc.Root.Get('content').AsStr.ToString;
  Check(Length(Multibyte) < 105, 'byte cap roughly respected');
  { UTF-8 安全切：内容以合法字符结尾（无半个 终 字）}
  Check(Copy(Multibyte, Length(Multibyte), 1) <> #$BF,
    'no stray continuation byte at cut point');

  { 双限同时生效：字节上限兜底行切后的结果 }
  R.ContentJson := ManyLines;
  Out := EnvelopeTruncation(R, 5, 40);
  Check(Out.Truncated and (Length(Out.ContentJson) <= 120),
    'combined limits apply');
end;

type
  TClockAdvancingTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
    FClock: TFakeClock;              { 具体类型：Advance 是桩驱动超时的关键 }
    FName: string;
  public
    constructor Create(const AName: string; const AClock: TFakeClock);
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

constructor TClockAdvancingTool.Create(const AName: string;
  const AClock: TFakeClock);
var
  LSpec: TToolSpec;
begin
  inherited Create;
  FClock := AClock;
  FName := AName;
  LSpec := Default(TToolSpec);
  LSpec.Name := AName;
  LSpec.TimeoutMs := 1000;
  FSpec := LSpec;
end;

function TClockAdvancingTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TClockAdvancingTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  { 桩在执行体内推进虚拟时钟：主线程 sweep 据此判定虚拟截止（零真实等待）；
    随后短暂真实驻留模拟未完成工作 }
  FClock.Advance(5000);
  NewSystemClock.SleepMs(25, nil);
  Result := Default(TToolResult);
  Result.ContentJson := '"late"';
end;

procedure TestTimeoutWrapperWithFakeClock;
var
  Clock: TFakeClock;
  ClockHold: IAgentClock;              { 接口持有：引用计数负责释放 }
  Pool: IThreadPool;
  Tool: IAgentTool;
  ChildTok, ParentTok: IAsyncCancellationToken;
  Job: TToolJob;
  One: array[0..0] of TToolJob;
begin
  Pool := CreateThreadPool(2);
  try
    { 超时路径：桩推进虚拟时钟越过 1000ms 截止 → 合成 timeout；
      返回后 worker 才完成——迟到结果不回读，错误载荷保持 }
    Clock := TFakeClock.Create;
    ClockHold := Clock;
    Tool := TClockAdvancingTool.Create('slow', Clock);
    ParentTok := CreateCancellationToken;
    ChildTok := ParentTok.CreateChildToken;
    Job := TToolJob.Create(Tool, '{}',
      NewToolContext(ChildTok, 0), ChildTok, Tool.Spec.TimeoutMs);
    One[0] := Job;
    RunToolBatch(One, Pool, Clock, nil);
    Check(Job.Res.IsError, 'expired job synthesized error result');
    Check(Pos('timed out after 1000ms', Job.Res.ContentJson) > 0,
      'timeout message names the budget');
    Check(ChildTok.IsCancelled,
      'child token cancelled as cooperative signal');
    Job.Free;

    { 正常路径对照：不推进时钟的快速工具完整成功 }
    Clock := TFakeClock.Create;
    ClockHold := Clock;
    Tool := TStubTool.Create('quick', 'q', [], 1000, False);
    ParentTok := CreateCancellationToken;
    ChildTok := ParentTok.CreateChildToken;
    Job := TToolJob.Create(Tool, '{}', NewToolContext(ChildTok, 3),
      ChildTok, Tool.Spec.TimeoutMs);
    One[0] := Job;
    RunToolBatch(One, Pool, Clock, nil);
    Check(Job.Res.IsError = False, 'quick job succeeds');
    Check(Job.DoneFlag = 1, 'done flag set by worker');
    Check(Job.Res.ContentJson = '{"tag":"q"}', 'payload intact');
    Job.Free;
  finally
    Pool.Shutdown;
  end;
end;

type
  { 阻塞至子令牌取消的工具：证明取消经 ctx 贯通到执行体 }
  TCancelWaitingTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
  public
    constructor Create;
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

constructor TCancelWaitingTool.Create;
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'waiter';
end;

function TCancelWaitingTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TCancelWaitingTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
var
  Guard: Integer;
begin
  Guard := 0;
  while ((ACtx = nil) or (ACtx.Token = nil) or
    (not ACtx.Token.IsCancelled)) and (Guard < 5000) do
  begin
    NewSystemClock.SleepMs(2, nil);
    Inc(Guard);
  end;
  Result := Default(TToolResult);
  Result.ContentJson := '"woke"';
end;

function CancelLaterThread(AArg: Pointer): Pointer; cdecl;
begin
  NewSystemClock.SleepMs(40, nil);
  IAsyncCancellationToken(AArg).Cancel;
  Result := nil;
end;

procedure TestCancellationMidBatch;
var
  Pool: IThreadPool;
  Tok, Child: IAsyncCancellationToken;
  Job: TToolJob;
  One: array[0..0] of TToolJob;
  H: TPlatformThreadHandle;
  LDummy: Pointer;
begin
  Pool := CreateThreadPool(1);
  try
    Tok := CreateCancellationToken;
    Child := Tok.CreateChildToken;
    Job := TToolJob.Create(TCancelWaitingTool.Create, '{}',
      NewToolContext(Child, 0), Child, 0);
    One[0] := Job;
    H := Default(TPlatformThreadHandle);
    platform_thread_create(H, @CancelLaterThread, Pointer(Tok));
    RunToolBatch(One, Pool, NewSystemClock, Tok);
    Check(Job.Res.IsError, 'mid-batch cancel synthesizes error');
    Check(Pos('cancelled', Job.Res.ContentJson) > 0,
      'cancellation named in payload');
    Check(Child.IsCancelled, 'child token tripped by batch teardown');
    platform_thread_join(H, LDummy);
    Job.Free;
  finally
    Pool.Shutdown;
  end;
end;

procedure TestToolExceptionBailout;
var
  Pool: IThreadPool;
  Job: TToolJob;
  One: array[0..0] of TToolJob;
begin
  Pool := CreateThreadPool(1);
  try
    Job := TToolJob.Create(TStubTool.Create('bad', 'b', [], 0, True),
      '{}', NewToolContext(nil, 0), nil, 0);
    One[0] := Job;
    RunToolBatch(One, Pool, NewSystemClock, nil);
    Check(Job.Res.IsError, 'raised tool -> error result (defense two)');
    Check(Pos('tool raised', Job.Res.ContentJson) > 0,
      'raise attribution present');
    Check(Pos('boom inside tool', Job.Res.ContentJson) > 0,
      'exception message preserved');
    Job.Free;
  finally
    Pool.Shutdown;
  end;
end;

procedure TestContextPassthrough;
var
  Tok: IAsyncCancellationToken;
  Ctx: IToolContext;
begin
  Tok := CreateCancellationToken;
  Ctx := NewToolContext(Tok, 7);
  Check(Ctx.Token = Tok, 'token passthrough');
  CheckEqual(Integer(7), Ctx.CallIndex, 'call index passthrough');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.tools');
  T.Test('spec validation', @TestSpecValidation);
  T.Test('argument validation', @TestArgumentValidation);
  T.Test('truncation envelope', @TestTruncationEnvelope);
  T.Test('timeout wrapper with fake clock', @TestTimeoutWrapperWithFakeClock);
  T.Test('cancellation mid batch', @TestCancellationMidBatch);
  T.Test('tool exception bailout', @TestToolExceptionBailout);
  T.Test('context passthrough', @TestContextPassthrough);
  if not T.Run then Halt(1);
end.
