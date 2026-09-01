{**
 * nextpas.core.agent.provider.fake — scripted / fake provider（离线回放）。
 *
 * 契约权威：core/docs/agent/API.md §7。脚本格式（JSON 数组，每项一个虚拟响应）：
 *   [ { "deltas": [
 *         {"kind":"text_delta","text":"你好"},
 *         {"kind":"tool_call_start","index":0,"id":"call_1","name":"weather"},
 *         {"kind":"tool_call_delta","index":0,"args":"{\"city\":\"上海\"}"},
 *         {"kind":"tool_call_end","index":0},
 *         {"kind":"finish","reason":"tool_calls"},
 *         {"kind":"usage","in":12,"out":34} ] } ]
 * 多项脚本按序回放；耗尽后再调用抛 aecProtocol — 测试立即显形。
 * 折叠一律走 nextpas.core.agent.fold 唯一实现（DESIGN D1），不重写折叠逻辑。
 * 非线程安全 — 测试替身，单线程场景专用。
 *}

unit nextpas.core.agent.provider.fake;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.fold;

function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider;
function NewEchoProvider: IAgentProvider;

implementation

procedure ScriptError(const AMsg: string);
begin
  raise EAgentError.CreateLocal(aecProtocol, 'fake script: ' + AMsg);
end;

function MapKind(const S: string): TStreamDeltaKind;
begin
  if S = 'text_delta' then Exit(sdkTextDelta);
  if S = 'thinking_delta' then Exit(sdkThinkingDelta);
  if S = 'tool_call_start' then Exit(sdkToolCallStart);
  if S = 'tool_call_delta' then Exit(sdkToolCallDelta);
  if S = 'tool_call_end' then Exit(sdkToolCallEnd);
  if S = 'finish' then Exit(sdkFinish);
  if S = 'usage' then Exit(sdkUsage);
  if S = 'error' then Exit(sdkError);
  if S = 'envelope' then Exit(sdkEnvelope);
  ScriptError('unknown delta kind "' + S + '"');
  Result := sdkTextDelta;             { 不可达：ScriptError 必抛 }
end;

function MapFinishReason(const S: string): TFinishReason;
begin
  if S = 'stop' then Exit(frStop);
  if S = 'length' then Exit(frLength);
  if S = 'tool_calls' then Exit(frToolCalls);
  if S = 'content_filter' then Exit(frContentFilter);
  ScriptError('unknown finish reason "' + S + '"');
  Result := frNone;                   { 不可达 }
end;

function StrFieldOf(const AItem: TJsonValue; const AKey: string): string;
var
  LV: TJsonValue;
begin
  LV := AItem.Get(AKey);
  if LV.IsStr then
    Result := LV.AsStr.ToString
  else
    Result := '';
end;

procedure ParseDeltaItem(const AItem: TJsonValue; out ADelta: TStreamDelta);
var
  LKind, LReason: string;
  LV: TJsonValue;
begin
  ADelta := Default(TStreamDelta);
  LKind := StrFieldOf(AItem, 'kind');
  if LKind = '' then
    ScriptError('delta entry missing "kind"');
  ADelta.Kind := MapKind(LKind);
  case ADelta.Kind of
    sdkTextDelta, sdkThinkingDelta:
      ADelta.TextDelta := StrFieldOf(AItem, 'text');
    sdkToolCallStart:
      begin
        ADelta.ToolIndex := AItem.Get('index').AsInt;
        ADelta.ToolCallId := StrFieldOf(AItem, 'id');
        ADelta.ToolName := StrFieldOf(AItem, 'name');
      end;
    sdkToolCallDelta:
      begin
        ADelta.ToolIndex := AItem.Get('index').AsInt;
        ADelta.ArgumentsDelta := StrFieldOf(AItem, 'args');
      end;
    sdkToolCallEnd:
      ADelta.ToolIndex := AItem.Get('index').AsInt;
    sdkFinish:
      begin
        LReason := StrFieldOf(AItem, 'reason');
        if LReason = '' then
          ScriptError('finish entry missing "reason"');
        ADelta.FinishReason := MapFinishReason(LReason);
      end;
    sdkUsage:
      begin
        ADelta.Usage.InputTokens := AItem.Get('in').AsInt;
        ADelta.Usage.OutputTokens := AItem.Get('out').AsInt;
      end;
    sdkError:
      begin
        ADelta.Error.Message := StrFieldOf(AItem, 'message');
        LV := AItem.Get('retryable');
        ADelta.Error.Retryable := LV.IsBool and LV.AsBool;
        ADelta.Error.RetryAfterMs := CRetryAfterUnknown;
      end;
    sdkEnvelope:
      begin
        ADelta.MessageId := StrFieldOf(AItem, 'id');
        ADelta.Model := StrFieldOf(AItem, 'model');
      end;
  end;
end;

type
  { 流式回放会话：逐 delta 交付；EOF 时经唯一 fold 收口消息 }
  TFakeCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FDeltas: TStreamDeltaArray;
    FIdx: Integer;
    FMsg: TMessage;
    FDone: Boolean;
    FCancelled: Boolean;
  public
    constructor Create(const ADeltas: TStreamDeltaArray);
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 脚本回放 provider }
  TFakeProvider = class(TInterfacedObject, IAgentProvider)
  protected
    FScripts: array of TStreamDeltaArray;
    FNext: Integer;
    procedure PopScript(out ADeltas: TStreamDeltaArray);
  public
    constructor Create; overload;
      { 空白构造：仅供 echo 等免脚本派生类使用 }
    constructor Create(const AScriptJson: TJsonText); overload;
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

  { echo 桩：把最后一条 user 文本原样作为单 delta 回显。
    四个入口全部覆写且必须重列 IAgentProvider——FPC 接口槽在基类
    声明处绑定，子类静态重声明不重列接口不生效（已实测复现）}
  TEchoProvider = class(TFakeProvider, IAgentProvider)
  public
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

function LastUserText(const AReq: TCompletionRequest): string;
var
  I: Integer;
begin
  Result := '';
  for I := High(AReq.Messages) downto 0 do
    if AReq.Messages[I].Role = mrUser then
      Exit(MessageText(AReq.Messages[I]));
end;

procedure EchoDeltas(const AReq: TCompletionRequest;
  out ADeltas: TStreamDeltaArray);
begin
  SetLength(ADeltas, 1);
  ADeltas[0] := Default(TStreamDelta);
  ADeltas[0].Kind := sdkTextDelta;
  ADeltas[0].TextDelta := LastUserText(AReq);
end;

function NewFakeProvider(const AScriptJson: TJsonText): IAgentProvider;
begin
  Result := TFakeProvider.Create(AScriptJson);
end;

function NewEchoProvider: IAgentProvider;
begin
  Result := TEchoProvider.Create;
end;

{ ---- 解析 ---- }

constructor TFakeProvider.Create;
begin
  inherited Create;
  FNext := 0;
end;

constructor TFakeProvider.Create(const AScriptJson: TJsonText);
var
  Doc: IJsonDocument;
  Root, LResp, LDeltas, LItem: TJsonValue;
  I, J: Integer;
  LN: Integer;
begin
  Create;
  Doc := JsonParse(AScriptJson);
  if Doc.HasError or (not Doc.Root.IsArray) then
    ScriptError('root must be a JSON array of responses');
  Root := Doc.Root;
  for I := 0 to Integer(Root.ArrayLen) - 1 do
  begin
    LResp := Root.ArrayGet(UInt32(I));
    if not LResp.IsObject then
      ScriptError('response entry must be an object');
    LDeltas := LResp.Get('deltas');
    if not LDeltas.IsArray then
      ScriptError('response entry missing "deltas" array');
    LN := Length(FScripts);
    SetLength(FScripts, LN + 1);
    SetLength(FScripts[LN], Integer(LDeltas.ArrayLen));
    for J := 0 to Integer(LDeltas.ArrayLen) - 1 do
    begin
      LItem := LDeltas.ArrayGet(UInt32(J));
      if not LItem.IsObject then
        ScriptError('delta entry must be an object');
      ParseDeltaItem(LItem, FScripts[LN][J]);
    end;
  end;
  FNext := 0;
end;

procedure TFakeProvider.PopScript(out ADeltas: TStreamDeltaArray);
begin
  if FNext >= Length(FScripts) then
    raise EAgentError.CreateLocal(aecProtocol,
      'fake provider: script exhausted');
  ADeltas := System.Copy(FScripts[FNext], 0, Length(FScripts[FNext]));
  Inc(FNext);
end;

function TFakeProvider.GetName: string;
begin
  Result := 'fake';
end;

function TFakeProvider.Complete(const AReq: TCompletionRequest): TMessage;
var
  LDeltas: TStreamDeltaArray;
begin
  PopScript(LDeltas);
  FoldDeltas(LDeltas, Result);
end;

function TFakeProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  Result := Complete(AReq);
end;

function TFakeProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
var
  LDeltas: TStreamDeltaArray;
begin
  PopScript(LDeltas);
  Result := TFakeCompletion.Create(LDeltas);
end;

function TFakeProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := Stream(AReq);
end;

{ ---- TFakeCompletion ---- }

constructor TFakeCompletion.Create(const ADeltas: TStreamDeltaArray);
begin
  inherited Create;
  FDeltas := System.Copy(ADeltas, 0, Length(ADeltas));
end;

function TFakeCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  if FCancelled then
    Exit(False);
  if FIdx < Length(FDeltas) then
  begin
    ADelta := FDeltas[FIdx];
    Inc(FIdx);
    Exit(True);
  end;
  if not FDone then
  begin
    FDone := True;
    FoldDeltas(FDeltas, FMsg);       { 唯一 fold，EOF 时收口一次 }
  end;
  Result := False;
end;

procedure TFakeCompletion.Cancel;
begin
  FCancelled := True;
end;

function TFakeCompletion.GetCancelled: Boolean;
begin
  Result := FCancelled;
end;

function TFakeCompletion.GetMessage: TMessage;
begin
  if not FDone then
    raise EAgentError.CreateLocal(aecProtocol,
      'completion not drained — drain NextDelta until False before GetMessage');
  Result := FMsg;
end;

function TFakeCompletion.GetUsage: TTokenUsage;
begin
  if not FDone then
    raise EAgentError.CreateLocal(aecProtocol,
      'completion not drained — drain NextDelta until False before GetUsage');
  Result := FMsg.Usage;
end;

{ ---- TEchoProvider ---- }

function TEchoProvider.GetName: string;
begin
  Result := 'fake';
end;

function TEchoProvider.Complete(const AReq: TCompletionRequest): TMessage;
var
  LDeltas: TStreamDeltaArray;
begin
  EchoDeltas(AReq, LDeltas);
  FoldDeltas(LDeltas, Result);
end;

function TEchoProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  Result := Complete(AReq);
end;

function TEchoProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
var
  LDeltas: TStreamDeltaArray;
begin
  EchoDeltas(AReq, LDeltas);
  Result := TFakeCompletion.Create(LDeltas);
end;

function TEchoProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := Stream(AReq);
end;

end.
