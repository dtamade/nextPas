{**
 * nextpas.core.agent.tools - 工具校验 / 截断信封 / 线程池执行设施。
 *
 * 契约权威：core/docs/agent/API.md §1.5/§6；ARCHITECTURE §3.3；
 * LIFECYCLE §5（超时合成非抢占，弃置策略）。实现与文档冲突时先改文档。
 *
 * 校验失败一律合成 error result 返回（参数错误是模型的错误，循环继续）；
 * spec/schema 非法属调用方错误，注册期抛 aecConfig。
 *}

unit nextpas.core.agent.tools;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.atomic.core,
  nextpas.core.thread.intf,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.conv,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock;

const
  CTOOLS_TRUNCATED_KEY = 'truncated';   { 截断信封键（API.md §6 normative）}
  CTOOLS_CONTENT_KEY = 'content';
  CTOOLS_MAX_ARGS_BYTES = 262144;       { 参数预检上限 256 KiB（SECURITY §3）}
  CTOOLS_MAX_DEPTH = 8;                 { 参数嵌套深度上限 }

{ 注册期快速失败：名称 1..64 字符限 [A-Za-z0-9_-]；ParametersJson 非空时
  必须解析为 JSON object。违者 aecConfig }
procedure ValidateToolSpec(const ASpec: TToolSpec);

{ §1.5 务实级全集：体积预检 / 根 object / 深度≤8 / required 存在 /
  顶层 string|number|boolean 类型核对（number 收 int+float）。
  失败一律 error result 返回，绝不抛 }
function ValidateToolArguments(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): TToolResult;

{ 结果截断信封：未超限原样返回；超限按 UTF-8 安全切文本投影产出合法 JSON
  包裹 {"truncated":true,"content":"<切后>"} 并置 Truncated=True。
  AMaxLines/AMaxBytes ≤0 视为关闭该项 }
function EnvelopeTruncation(const AResult: TToolResult;
  AMaxLines, AMaxBytes: Integer): TToolResult;

function NewToolContext(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer): IToolContext;

type
  { 单个待执行调用：loop 装配，池线程消费。DoneFlag 由池任务原子置位；
    ErrMsg 非空 = 工具实现违反"不抛"约定被兜底捕获。
    WriteGuard 迟到写仲裁：合成方（超时/取消）与 worker 谁先 XChange(0→1)
    谁拥有 Res 写权，败方静默丢弃——弃置 worker 的迟到结果不覆盖已合成载荷 }
  TToolJob = class
  public
    Tool: IAgentTool;
    ArgsJson: TJsonText;
    Ctx: IToolContext;
    ChildCancel: IAsyncCancellationToken;   { 超时合成后 Cancel（协作信号）}
    TimeoutMs: Int64;                       { 0=不限 }
    Res: TToolResult;
    ErrMsg: string;
    WriteGuard: Integer;
    DoneFlag: Integer;
    constructor Create(const ATool: IAgentTool; const AArgs: TJsonText;
      const ACtx: IToolContext;
      const AChildCancel: IAsyncCancellationToken; ATimeoutMs: Int64);
  end;

  { 批量执行：并行批一次直提 + SignalWorkers；串行批次由调用方按序单元素批
    （顺序保持语义在 loop 层）。汇合用 WaitAllTimeout 小切片轮询 + 时钟感知
    的逐项截止检查——时钟可注入，fake clock 由桩工具在执行体内 Advance 即可
    确定性驱动超时（零真实等待）。
    到期未完成项：合成 timeout error result、Cancel 其子令牌、worker 弃置
    继续跑到自然终点（LIFECYCLE §5 文档化代价）；弃置 worker 的迟到结果
    不回读。工具异常兜底转 aecToolFailed error result（两道防线之二）。
    AToken 取消：切片边界检查，未完成项合成 cancelled error result 并
    Cancel 子令牌后返回。
    内存序：worker 写结果 → seq_cst 栅栏 → XChange(Done,1)；主线程观察到
    Done 后先栅栏再读结果（x86 TSO 下栅栏冗余，为可移植正确性保留）}
procedure RunToolBatch(const AJobs: array of TToolJob;
  const APool: IThreadPool; const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken);

implementation

uses
  nextpas.core.exception;

const
  CSWEEP_SLICE_NS = 200000;              { 单次 WaitAllTimeout 切片 200µs }
  CSWEEP_SLEEP_MS = 2;                   { 全部到齐前的轮询间歇 }

procedure MakeErrInto(var ARes: TToolResult; const AMsg: string);
var
  LB: IJsonBuilder;
begin
  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key('error');
  LB.Str(AMsg);                          { builder 负责字符串转义 }
  LB.EndObject;
  ARes := Default(TToolResult);
  ARes.ContentJson := LB.ToString;
  ARes.IsError := True;
end;

procedure ValidateToolSpec(const ASpec: TToolSpec);
var
  I, LLen: Integer;
  Doc: IJsonDocument;
begin
  LLen := Length(ASpec.Name);
  if (LLen = 0) or (LLen > 64) then
    raise EAgentError.CreateLocal(aecConfig,
      'tool name must be 1..64 chars');
  for I := 1 to LLen do
    if not (ASpec.Name[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-']) then
      raise EAgentError.CreateLocal(aecConfig,
        'tool name char "' + ASpec.Name[I] + '" outside [A-Za-z0-9_-]');
  if ASpec.ParametersJson <> '' then
  begin
    Doc := JsonParse(ASpec.ParametersJson);
    if Doc.HasError or (not Doc.Root.IsObject) then
      raise EAgentError.CreateLocal(aecConfig,
        'tool "' + ASpec.Name + '" parameters must be a JSON object');
  end;
end;

{ 参数深度：object/array 每层计 1，标量为 0 }
function DepthWithin(const AV: TJsonValue; ARemaining: Integer): Boolean;
var
  I: Integer;
begin
  if AV.IsObject then
  begin
    if ARemaining <= 0 then
      Exit(False);
    for I := 0 to Integer(AV.ObjectLen) - 1 do
      if not DepthWithin(AV.ObjectValueAt(UInt32(I)), ARemaining - 1) then
        Exit(False);
    Result := True;
  end
  else if AV.IsArray then
  begin
    if ARemaining <= 0 then
      Exit(False);
    for I := 0 to Integer(AV.ArrayLen) - 1 do
      if not DepthWithin(AV.ArrayGet(UInt32(I)), ARemaining - 1) then
        Exit(False);
    Result := True;
  end
  else
    Result := True;
end;

function TypeMatches(const AArg: TJsonValue;
  const ASchemaType: string): Boolean;
begin
  if ASchemaType = 'string' then
    Exit(AArg.IsStr);
  if ASchemaType = 'number' then
    Exit(AArg.IsInt or AArg.IsFloat);
  if ASchemaType = 'boolean' then
    Exit(AArg.IsBool);
  { array/object/null 类型不深查（§1.5 第 5 条）}
  Result := True;
end;

function ValidateToolArguments(const ASpec: TToolSpec;
  const AArgsJson: TJsonText): TToolResult;
var
  Doc, SDoc: IJsonDocument;
  Req, Props, PVal, PVType, AArg: TJsonValue;
  I: Integer;
  LKey: string;
begin
  if Length(AArgsJson) > CTOOLS_MAX_ARGS_BYTES then
  begin
    MakeErrInto(Result, 'arguments exceed 256 KiB precheck limit');
    Exit;
  end;

  Doc := JsonParse(AArgsJson);
  if Doc.HasError or (not Doc.Root.IsObject) then
  begin
    MakeErrInto(Result, 'arguments must be a JSON object');
    Exit;
  end;

  if not DepthWithin(Doc.Root, CTOOLS_MAX_DEPTH) then
  begin
    MakeErrInto(Result, 'arguments nesting exceeds depth ' +
      IntToStr(CTOOLS_MAX_DEPTH));
    Exit;
  end;

  if ASpec.ParametersJson <> '' then
  begin
    SDoc := JsonParse(ASpec.ParametersJson);
    { spec 已在 AddTool 校验过；此处解析失败属防御路径，拦下并报错 }
    if SDoc.HasError or (not SDoc.Root.IsObject) then
    begin
      MakeErrInto(Result, 'tool spec failed re-validation');
      Exit;
    end;

    Req := SDoc.Root.Get('required');
    if Req.IsArray then
      for I := 0 to Integer(Req.ArrayLen) - 1 do
      begin
        if not Req.ArrayGet(UInt32(I)).IsStr then
          Continue;
        LKey := Req.ArrayGet(UInt32(I)).AsStr.ToString;
        if not Doc.Root.ObjectHas(LKey) then
        begin
          MakeErrInto(Result,
            'missing required argument "' + LKey + '"');
          Exit;
        end;
      end;

    Props := SDoc.Root.Get('properties');
    if Props.IsObject then
      for I := 0 to Integer(Props.ObjectLen) - 1 do
      begin
        LKey := Props.ObjectKeyAt(UInt32(I)).ToString;
        PVal := Props.ObjectValueAt(UInt32(I));
        if not PVal.IsObject then
          Continue;
        PVType := PVal.Get('type');
        if not PVType.IsStr then
          Continue;
        AArg := Doc.Root.Get(LKey);
        if AArg.IsValid and
          (not TypeMatches(AArg, PVType.AsStr.ToString)) then
        begin
          MakeErrInto(Result, 'argument "' + LKey + '" must be ' +
            PVType.AsStr.ToString);
          Exit;
        end;
      end;
  end;

  Result := Default(TToolResult);
end;

{ UTF-8 安全截断（provider.common 有同源孪生；合并候选进 inbox）：
  最多回退到序列引导字节边界，绝不切出半字符 }
function SafeTruncateUtf8(const S: string; AMaxBytes: Integer): string;
var
  LCut: Integer;
begin
  if Length(S) <= AMaxBytes then
    Exit(S);
  LCut := AMaxBytes;
  while (LCut > 0) and ((Byte(S[LCut]) and $C0) = $80) do
    Dec(LCut);
  if LCut > 0 then
    Dec(LCut);                           { 引导字节一并让位 }
  if LCut < 0 then
    LCut := 0;
  Result := Copy(S, 1, LCut);
end;

function EnvelopeTruncation(const AResult: TToolResult;
  AMaxLines, AMaxBytes: Integer): TToolResult;
var
  LText, LCut: string;
  LLines, LPos, LCount: Integer;
  LB: IJsonBuilder;
  LOver: Boolean;
begin
  Result := AResult;
  LText := AResult.ContentJson;
  LOver := False;
  LCut := LText;

  if AMaxLines > 0 then
  begin
    LLines := 1;
    for LPos := 1 to Length(LText) do
      if LText[LPos] = #10 then
        Inc(LLines);
    if LLines > AMaxLines then
    begin
      LCount := 1;
      LPos := 1;
      while (LPos <= Length(LText)) and (LCount <= AMaxLines) do
      begin
        if LText[LPos] = #10 then
          Inc(LCount);
        Inc(LPos);
      end;
      LCut := Copy(LText, 1, LPos - 2);   { 去掉越界的最后一段与其换行 }
      LOver := True;
    end;
  end;

  if (AMaxBytes > 0) and (Length(LCut) > AMaxBytes) then
  begin
    LCut := SafeTruncateUtf8(LCut, AMaxBytes);
    LOver := True;
  end;

  if not LOver then
    Exit;

  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key(CTOOLS_TRUNCATED_KEY);
  LB.Bool(True);
  LB.Key(CTOOLS_CONTENT_KEY);
  LB.Str(LCut);
  LB.EndObject;
  Result.ContentJson := LB.ToString;
  Result.Truncated := True;
end;

type
  TToolCtx = class(TInterfacedObject, IToolContext)
  private
    FToken: IAsyncCancellationToken;
    FCallIndex: Integer;
  public
    constructor Create(const AToken: IAsyncCancellationToken;
      ACallIndex: Integer);
    function Token: IAsyncCancellationToken;
    function CallIndex: Integer;
  end;

constructor TToolCtx.Create(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer);
begin
  inherited Create;
  FToken := AToken;
  FCallIndex := ACallIndex;
end;

function TToolCtx.Token: IAsyncCancellationToken;
begin
  Result := FToken;
end;

function TToolCtx.CallIndex: Integer;
begin
  Result := FCallIndex;
end;

function NewToolContext(const AToken: IAsyncCancellationToken;
  ACallIndex: Integer): IToolContext;
begin
  Result := TToolCtx.Create(AToken, ACallIndex);
end;

{ ---- 执行 ---- }

constructor TToolJob.Create(const ATool: IAgentTool; const AArgs: TJsonText;
  const ACtx: IToolContext; const AChildCancel: IAsyncCancellationToken;
  ATimeoutMs: Int64);
begin
  inherited Create;
  Tool := ATool;
  ArgsJson := AArgs;
  Ctx := ACtx;
  ChildCancel := AChildCancel;
  TimeoutMs := ATimeoutMs;
  WriteGuard := 0;
  DoneFlag := 0;
end;

procedure JobTaskProc(AData: Pointer);
var
  LJob: TToolJob absolute AData;
  LRes: TToolResult;
  LErr: string;
begin
  try
    try
      LRes := LJob.Tool.Execute(LJob.ArgsJson, LJob.Ctx);
    except
      on Ex: Exception do                          { 两道防线之二：兜底转写 }
        LErr := Ex.Message;
    end;
    { 迟到写仲裁：合成方（超时/取消）已认领写权则丢弃本结果（弃置语义）}
    if _backend_xchg_i32(LJob.WriteGuard, 1) = 0 then
    begin
      atomic_seq_cst_fence;
      LJob.Res := LRes;
      LJob.ErrMsg := LErr;
    end;
  finally
    atomic_seq_cst_fence;
    _backend_xchg_i32(LJob.DoneFlag, 1);
  end;
end;

{ 合成方认领写权后落载荷；worker 迟到结果将被其自身丢弃 }
procedure SynthIfOpen(AJob: TToolJob; const AMsg: string);
begin
  if _backend_xchg_i32(AJob.WriteGuard, 1) = 0 then
  begin
    atomic_seq_cst_fence;
    MakeErrInto(AJob.Res, AMsg);
  end;
end;

procedure RunToolBatch(const AJobs: array of TToolJob;
  const APool: IThreadPool; const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken);
var
  I: Integer;
  LStart, LNow: Int64;
  LAllDone, LCancelled: Boolean;
  LTimedOut: array of Boolean;
  LPending: Integer;
begin
  if Length(AJobs) = 0 then
    Exit;

  SetLength(LTimedOut, Length(AJobs));
  for I := 0 to High(AJobs) do
    LTimedOut[I] := False;

  { 截止基准先于提交采样：桩工具在执行体内推进注入时钟时，
    虚拟流逝必然覆盖截止窗口（fake clock 驱动确定性）}
  LStart := AClock.NowMs;

  for I := 0 to High(AJobs) do
    APool.SubmitDirect(Pointer(AJobs[I]), @JobTaskProc);
  APool.SignalWorkers(Length(AJobs));

  LCancelled := False;
  repeat
    if Assigned(AToken) and AToken.IsCancelled then
    begin
      LCancelled := True;
      Break;
    end;
    if APool.WaitAllTimeout(CSWEEP_SLICE_NS) then
      Break;                                       { 本批全部真实完成 }
    LNow := AClock.NowMs;
    { 逐项到期判定：当场合成 timeout、Cancel 子令牌（协作信号）、
      worker 弃置；其迟到结果经 LTimedOut 屏蔽不回读 }
    for I := 0 to High(AJobs) do
      if (not LTimedOut[I]) and (AJobs[I].TimeoutMs > 0) and
        (AJobs[I].DoneFlag = 0) and
        (LNow - LStart >= AJobs[I].TimeoutMs) then
      begin
        SynthIfOpen(AJobs[I],
          'tool timed out after ' + IntToStr(AJobs[I].TimeoutMs) + 'ms');
        AJobs[I].TimeoutMs := 0;
        LTimedOut[I] := True;
        if AJobs[I].ChildCancel <> nil then
          AJobs[I].ChildCancel.Cancel;
      end;
    LPending := 0;
    for I := 0 to High(AJobs) do
      if AJobs[I].DoneFlag = 0 then
        Inc(LPending);
    if LPending = 0 then
      Break;
    AClock.SleepMs(CSWEEP_SLEEP_MS, AToken);
  until False;

  { 收尾归因：工具异常 → aecToolFailed；取消 → 未完成项合成 cancelled。
    超时已合成项不被覆盖（弃置语义：迟到结果不回读）}
  for I := 0 to High(AJobs) do
  begin
    if LTimedOut[I] then
      Continue;
    if AJobs[I].ErrMsg <> '' then
    begin
      MakeErrInto(AJobs[I].Res,
        'tool raised: ' + AJobs[I].ErrMsg + ' (' +
        AgentErrorCodeName(aecToolFailed) + ')');
      AJobs[I].ErrMsg := '';
    end
    else if LCancelled and (AJobs[I].DoneFlag = 0) then
    begin
      SynthIfOpen(AJobs[I], 'cancelled before completion');
      if AJobs[I].ChildCancel <> nil then
        AJobs[I].ChildCancel.Cancel;
    end;
  end;
end;

end.
