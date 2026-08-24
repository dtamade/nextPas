{**
 * nextpas.core.agent.provider.anthropic - Anthropic Messages 适配器。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §2、API.md §3/§7/§8。
 * 实现与文档冲突时先改文档。公开编解码器与工厂共用同一实现（DESIGN D13）；
 * 流式事件以 event 名为主键归约为统一词表（§2.3）；截断流 fail-closed
 * （Q-A8），与 OpenAI Q-O4 的宽容是各自协议现实。
 *}

unit nextpas.core.agent.provider.anthropic;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

const
  CANTHROPIC_DEFAULT_BASE_URL = 'https://api.anthropic.com';
  CANTHROPIC_VERSION_DEFAULT = '2023-06-01';
  CANTHROPIC_CONNECT_TIMEOUT_MS = 10000;
  CANTHROPIC_TOTAL_TIMEOUT_MS = 300000;
  CANTHROPIC_ENV_API_KEY = 'NEXTPAS_AGENT_ANTHROPIC_API_KEY';
  CANTHROPIC_ENV_MODEL = 'NEXTPAS_AGENT_ANTHROPIC_MODEL';
  CANTHROPIC_ENV_BASE_URL = 'NEXTPAS_AGENT_ANTHROPIC_BASE_URL';

type
  { provider 选项（API.md §3.1）：公共段 + anthropic-version }
  TAnthropicOptions = record
    Common: TProviderOptions;
    AnthropicVersion: string;        { 默认 CANTHROPIC_VERSION_DEFAULT }
    class function New(const AModel: string): TAnthropicOptions; static;
  end;

{ 编码：词表 → Messages wire（§2.1）。MaxTokens 强制必填（unset → aecConfig，
  绝不静默填默认）；Thinking=tsTrue 而 Budget unset → aecConfig；
  image mime 白名单违者 aecConfig；ResponseSchemaJson 非空 → aecConfig }
function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;

{ 非流式响应解码（§2.2）：违反协议抛 aecProtocol（带 RawBodySnippet）}
procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage;
  const ALog: ILogger = nil);

{ 流帧解码器（§2.3）：event 名为主键；message_start→message_stop 完整轨迹
  之外 Finalize 抛 aecProtocol（Q-A8 fail-closed）；ping 忽略 }
function NewAnthropicWireDecoder(
  const ALog: ILogger = nil): IAgentWireDecoder;

function BuildAnthropicUrl(const ABaseUrl: string): string;

function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider;

{ 环境装配（CONSUMERS §3）：必填 env 缺失返回 nil，绝不静默回退 }
function NewAnthropicProviderFromEnv: IAgentProvider;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.agent.fold,
  nextpas.core.agent.transport.http;

const
  CAGENT_UNMAPPED_STOP = 'agent.unmapped.stop_reason';
  CAGENT_UNMAPPED_BLOCK = 'agent.unmapped.content_block_type';
  CAGENT_UNMAPPED_DELTA = 'agent.unmapped.content_delta_type';
  CAGENT_UNMAPPED_ERRTYPE = 'agent.unmapped.error_type';

  { image source mime 白名单（WIRE-MAPPINGS §2.1）}
  CIMAGE_MIMES: array[0..3] of string = (
    'image/png', 'image/jpeg', 'image/gif', 'image/webp');

type
  { 帧序状态机：message_start→content_block_*→message_delta→message_stop；
    单角色独占，不跨消息复用 }
  TAnthropicWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private type
    TBlockKind = (btkNone, btkText, btkThinking, btkTool, btkUnknown);
    TOpenBlock = record
      Index: Integer;
      Kind: TBlockKind;
    end;
  private
    FLog: ILogger;
    FStarted: Boolean;               { message_start 已见（Q-A1 强制首信封）}
    FStopped: Boolean;               { message_stop 已见 }
    FDead: Boolean;                  { error 事件后终止：后续帧弃置 }
    FFinalized: Boolean;
    FPool: TWireToolSlotPool;        { tool_use 槽位（共享分桶实现，Q-A6）}
    FBlocks: array of TOpenBlock;    { 当前开启的 content block }
    FInTokens: Int64;                { message_start 暂存（Q-A2 双源合成）}
    FCacheRead: Int64;
    FCacheWrite: Int64;
    FOutTokens: Int64;               { message_delta 累计值取最后一次 }
    FStopReason: string;             { message_delta 暂存 }
    FPendingUnmapped: TJsonText;
    procedure HandleStart(const AData: string; var ADeltas: TStreamDeltaArray);
    procedure HandleBlockStart(const AData: string;
      var ADeltas: TStreamDeltaArray);
    procedure HandleBlockDelta(const AData: string;
      var ADeltas: TStreamDeltaArray);
    procedure HandleBlockStop(const AData: string;
      var ADeltas: TStreamDeltaArray);
    procedure HandleMessageDelta(const AData: string);
    procedure HandleMessageStop(var ADeltas: TStreamDeltaArray);
    function BlockKindAt(AIdx: Integer): TBlockKind;
    procedure SetBlockKind(AIdx: Integer; AKind: TBlockKind);
    procedure StashUnmapped(const AKey, ARaw: string);
    procedure EmitStreamError(const AData: string;
      var ADeltas: TStreamDeltaArray);
  public
    constructor Create(const ALog: ILogger);
    destructor Destroy; override;
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

procedure WarnLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Warn(AMsg);
end;

procedure DebugLog(const ALog: ILogger; const AMsg: string);
begin
  if ALog <> nil then
    ALog.Debug(AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
var
  E: EAgentError;
begin
  E := EAgentError.CreateLocal(aecProtocol, 'anthropic: ' + AMsg);
  E.RawBodySnippet := Utf8SafeTruncate(ABodySrc, CMaxRawBodySnippetBytes);
  raise E;
end;

function JoinMessagesUrl(const ABaseUrl, ADefault: string): string;
var
  LBase: string;
begin
  LBase := ABaseUrl;
  if LBase = '' then
    LBase := ADefault;
  while (LBase <> '') and (LBase[Length(LBase)] = '/') do
    Delete(LBase, Length(LBase), 1);
  if (Length(LBase) >= 3) and
    (Copy(LBase, Length(LBase) - 2, 3) = '/v1') then
    Result := LBase + '/messages'
  else
    Result := LBase + '/v1/messages';
end;

function BuildAnthropicUrl(const ABaseUrl: string): string;
begin
  Result := JoinMessagesUrl(ABaseUrl, CANTHROPIC_DEFAULT_BASE_URL);
end;

{ stop_reason 四值映射；未知取 frNone + unmapped 文本回传（§0 未映射规则）}
function MapStopReason(const S: string; out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  Result := frNone;
  if S = 'end_turn' then
    Exit(frStop);
  if S = 'stop_sequence' then
    Exit(frStop);
  if S = 'max_tokens' then
    Exit(frLength);
  if S = 'tool_use' then
    Exit(frToolCalls);
  if S = 'refusal' then
    Exit(frContentFilter);
  if S <> '' then
    AUnmapped := S;
end;

{ 流内错误类型 → 错误码（§2.4）：无状态码可依，按类型名映射；
  未映射类型归 aecServer（重试白名单类，原始文本经 sdkError 消息保真）}
function ErrorCodeForStreamErrType(const AType: string): TAgentErrorCode;
begin
  if AType = 'rate_limit_error' then
    Exit(aecRateLimited);
  if (AType = 'overloaded_error') or (AType = 'api_error') then
    Exit(aecServer);
  if (AType = 'invalid_request_error') or (AType = 'request_too_large') then
    Exit(aecInvalidRequest);
  if (AType = 'authentication_error') or (AType = 'permission_error') or
    (AType = 'billing_error') then
    Exit(aecAuthentication);
  if AType = 'not_found_error' then
    Exit(aecNotFound);
  Result := aecServer;
end;

function MimeAllowed(const AMime: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(CIMAGE_MIMES) to High(CIMAGE_MIMES) do
    if CIMAGE_MIMES[I] = AMime then
      Exit(True);
end;

{ data URI → (mime, base64 载荷)；非 data URI 或形态非法返回 False }
function ParseDataUri(const AUri: string;
  out AMime, APayload: string): Boolean;
const
  CPREFIX = 'data:';
var
  LRest, LMeta: string;
  LSemi: SizeInt;
begin
  Result := False;
  AMime := '';
  APayload := '';
  if (Copy(AUri, 1, Length(CPREFIX)) <> CPREFIX) or (Length(AUri) < 6) then
    Exit;
  LRest := Copy(AUri, Length(CPREFIX) + 1, MaxInt);
  LSemi := Pos(';', LRest);
  if LSemi < 2 then
    Exit;
  LMeta := Copy(LRest, 1, LSemi - 1);
  APayload := Copy(LRest, LSemi + 1, MaxInt);
  if Copy(APayload, 1, 7) <> 'base64,' then
    Exit;
  APayload := Copy(APayload, 8, MaxInt);
  if Copy(LMeta, 1, 6) <> 'image/' then
    Exit;
  AMime := LMeta;
  Result := (APayload <> '') and MimeAllowed(AMime);
end;

procedure WriteImageSource(ABld: IJsonBuilder; const AImageUrl: string);
var
  LMime, LPayload: string;
begin
  ABld.Key('source');
  ABld.BeginObject;
  if Copy(AImageUrl, 1, 5) = 'data:' then
  begin
    { data URI → base64 source（mime 白名单内）}
    if not ParseDataUri(AImageUrl, LMime, LPayload) then
      raise EAgentError.CreateLocal(aecConfig,
        'anthropic: image data URI requires base64 payload and one of ' +
        'image/png|jpeg|gif|webp');
    ABld.Key('type');
    ABld.Str('base64');
    ABld.Key('media_type');
    ABld.Str(LMime);
    ABld.Key('data');
    ABld.Str(LPayload);
  end
  else if (Copy(AImageUrl, 1, 7) = 'http://') or
    (Copy(AImageUrl, 1, 8) = 'https://') then
  begin
    ABld.Key('type');
    ABld.Str('url');
    ABld.Key('url');
    ABld.Str(AImageUrl);
  end
  else
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: image url must be http(s) URL or data URI');
  ABld.EndObject;
end;

procedure WriteToolUseInput(ABld: IJsonBuilder; const AArgs: TJsonText);
var
  Doc: IJsonDocument;
begin
  ABld.Key('input');
  if Trim(AArgs) = '' then
  begin
    ABld.RawJson('{}');              { 无参调用折叠为空对象 }
    Exit;
  end;
  Doc := JsonParse(AArgs);
  if Doc.HasError or (not Doc.Root.IsObject) then
    raise EAgentError.CreateLocal(aecProtocol,
      'anthropic: tool call arguments must be a JSON object');
  ABld.RawJson(JsonStringify(Doc.Root));
end;

{ ---- 编码（§2.1）---- }

procedure WriteUserBlocks(ABld: IJsonBuilder; const AM: TMessage);
var
  J: Integer;
  P: TPart;
begin
  ABld.Key('content');
  ABld.BeginArray;
  for J := 0 to High(AM.Parts) do
  begin
    P := AM.Parts[J];
    case P.Kind of
      pkText:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('text');
          ABld.Key('text');
          ABld.Str(P.Text);
          ABld.EndObject;
        end;
      pkImage:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('image');
          WriteImageSource(ABld, P.ImageUrl);
          ABld.EndObject;
        end;
      pkToolResult:
        begin
          { user 消息内的 tool_result 块（Q-A4 分组规则的落点之一）}
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('tool_result');
          ABld.Key('tool_use_id');
          ABld.Str(P.ToolCallId);
          ABld.Key('content');
          ABld.Str(P.ResultJson);
          if P.IsError then
          begin
            ABld.Key('is_error');    { 哨兵纪律：仅失败时上送 }
            ABld.RawJson('true');
          end;
          ABld.EndObject;
        end;
      pkThinking,
      pkToolCall:
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: thinking/tool_call parts belong to assistant messages');
    end;
  end;
  ABld.EndArray;
end;

procedure WriteAssistantBlocks(ABld: IJsonBuilder; const AM: TMessage);
var
  J: Integer;
  P: TPart;
begin
  ABld.Key('content');
  ABld.BeginArray;
  for J := 0 to High(AM.Parts) do
  begin
    P := AM.Parts[J];
    case P.Kind of
      pkText:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('text');
          ABld.Key('text');
          ABld.Str(P.Text);
          ABld.EndObject;
        end;
      pkThinking:
        begin
          { Q-A3：signature 服务端签发不可伪造，原样透传 }
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('thinking');
          ABld.Key('thinking');
          ABld.Str(P.Text);
          if P.Signature <> '' then
          begin
            ABld.Key('signature');
            ABld.Str(P.Signature);
          end;
          ABld.EndObject;
        end;
      pkToolCall:
        begin
          ABld.BeginObject;
          ABld.Key('type');
          ABld.Str('tool_use');
          ABld.Key('id');
          ABld.Str(P.ToolCallId);
          ABld.Key('name');
          ABld.Str(P.ToolName);
          WriteToolUseInput(ABld, P.ArgumentsJson);
          ABld.EndObject;
        end;
      pkImage,
      pkToolResult:
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: image/tool_result parts belong to user messages');
    end;
  end;
  ABld.EndArray;
end;

procedure WriteTools(ABld: IJsonBuilder; const ASpecs: TToolSpecArray);
var
  I: Integer;
  Doc: IJsonDocument;
begin
  ABld.Key('tools');
  ABld.BeginArray;
  for I := 0 to High(ASpecs) do
  begin
    ABld.BeginObject;
    ABld.Key('name');
    ABld.Str(ASpecs[I].Name);
    if ASpecs[I].Description <> '' then
    begin
      ABld.Key('description');
      ABld.Str(ASpecs[I].Description);
    end;
    ABld.Key('input_schema');
    if Trim(ASpecs[I].ParametersJson) = '' then
      ABld.RawJson('{"type":"object"}')
    else
    begin
      Doc := JsonParse(ASpecs[I].ParametersJson);
      if Doc.HasError or (not Doc.Root.IsObject) then
        raise EAgentError.CreateLocal(aecProtocol,
          'anthropic: tool input_schema must be a JSON object');
      ABld.RawJson(JsonStringify(Doc.Root));
    end;
    ABld.EndObject;
  end;
  ABld.EndArray;
end;

function EncodeAnthropicRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TJsonText;
var
  B: IJsonBuilder;
  I: Integer;
  M: TMessage;
  LSysParts: array of string;
  LSysBuf: IStringBuilder;
  LDup: Boolean;

  procedure NoteSys(const ATxt: string);
  var
    K: Integer;
  begin
    if ATxt = '' then
      Exit;
    LDup := False;
    for K := 0 to High(LSysParts) do
      if LSysParts[K] = ATxt then
      begin
        LDup := True;
        Break;
      end;
    if not LDup then
    begin
      SetLength(LSysParts, Length(LSysParts) + 1);
      LSysParts[High(LSysParts)] := ATxt;
    end;
  end;

begin
  if AReq.ResponseSchemaJson <> '' then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: structured output is a v1.1 commitment, not available in v1');
  if AReq.MaxTokens <= CMaxTokensUnset then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: max_tokens is required by the vendor (set MaxTokens)');
  if (AReq.Thinking = tsTrue) and
    (AReq.ThinkingBudgetTokens <= CMaxTokensUnset) then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: thinking=true requires ThinkingBudgetTokens');

  B := JsonBuilder;
  B.BeginObject;
  B.Key('model');
  if AReq.Model <> '' then
    B.Str(AReq.Model)
  else
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: model is required');

  B.Key('max_tokens');
  B.Int(AReq.MaxTokens);             { 厂商强制必填，绝不静默填默认 }

  { 顶层 system（§2.1）：System 字段先行 + 历史 mrSystem 文本，
    重复去重、\n\n 连接——算法固定保障前缀字节稳定（§0）}
  SetLength(LSysParts, 0);
  NoteSys(AReq.System);
  for I := 0 to High(AReq.Messages) do
    if AReq.Messages[I].Role = mrSystem then
      NoteSys(MessageText(AReq.Messages[I]));
  if Length(LSysParts) > 0 then
  begin
    LSysBuf := MakeStringBuilder;
    for I := 0 to High(LSysParts) do
    begin
      if I > 0 then
        LSysBuf.AppendStr(#10#10);
      LSysBuf.AppendStr(LSysParts[I]);
    end;
    B.Key('system');
    B.Str(LSysBuf.ToString);
  end;

  B.Key('messages');
  B.BeginArray;
  for I := 0 to High(AReq.Messages) do
  begin
    M := AReq.Messages[I];
    case M.Role of
      mrSystem:
        Continue;                    { 已并入顶层 system }
      mrUser:
        begin
          B.BeginObject;
          B.Key('role');
          B.Str('user');
          WriteUserBlocks(B, M);
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
      mrAssistant:
        begin
          B.BeginObject;
          B.Key('role');
          B.Str('assistant');
          WriteAssistantBlocks(B, M);
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
      mrTool:
        begin
          { Q-A4：工具结果必须放 user 角色消息；一条 mrTool 消息展开为
            一条含多 tool_result 块的 user 消息 }
          B.BeginObject;
          B.Key('role');
          B.Str('user');
          WriteUserBlocks(B, M);
          WriteExtraFields(B, M.ExtraJson, ['role', 'content']);
          B.EndObject;
        end;
    end;
  end;
  B.EndArray;

  if Length(AReq.Tools) > 0 then
    WriteTools(B, AReq.Tools);       { 空数组不上送字段 }

  if AReq.Temperature >= 0 then
  begin
    B.Key('temperature');
    B.Float(AReq.Temperature);
  end;
  if AReq.TopP >= 0 then
  begin
    B.Key('top_p');
    B.Float(AReq.TopP);
  end;

  if Length(AReq.StopSequences) > 0 then
  begin
    B.Key('stop_sequences');
    B.BeginArray;
    for I := 0 to High(AReq.StopSequences) do
      B.Str(AReq.StopSequences[I]);
    B.EndArray;
  end;

  case AReq.Thinking of
    tsTrue:
      begin
        B.Key('thinking');
        B.BeginObject;
        B.Key('type');
        B.Str('enabled');
        B.Key('budget_tokens');
        B.Int(AReq.ThinkingBudgetTokens);
        B.EndObject;
      end;
    tsFalse:
      begin
        B.Key('thinking');
        B.BeginObject;
        B.Key('type');
        B.Str('disabled');
        B.EndObject;
      end;
    tsUnset:
      ;                          { 不上送（D5 哨兵纪律）}
  end;

  if AStream then
  begin
    B.Key('stream');
    B.RawJson('true');
  end;

  { Extra 回注根对象（冲突键让位已知字段）}
  WriteExtraFields(B, AReq.ExtraJson,
    ['model', 'max_tokens', 'system', 'messages', 'tools', 'temperature',
     'top_p', 'stop_sequences', 'thinking', 'stream']);

  B.EndObject;
  Result := B.ToString;
end;

{ ---- 非流式解码（§2.2）---- }

procedure DecodeAnthropicResponse(const ABody: TJsonText;
  out AMsg: TMessage; const ALog: ILogger);
var
  Doc: IJsonDocument;
  Root, LContent, LBlock, LU, LD: TJsonValue;
  I: Integer;
  LType, LTxt, LUnmapped: string;
  LCaps: array of TJsonText;

  procedure AddPart(APKind: TPartKind);
  var
    N: Integer;
  begin
    N := Length(AMsg.Parts);
    SetLength(AMsg.Parts, N + 1);
    AMsg.Parts[N] := Default(TPart);
    AMsg.Parts[N].Kind := APKind;
  end;

  procedure AddCap(const AKey, ARaw: string);
  var
    LBld: IJsonBuilder;
  begin
    if ARaw = '' then
      Exit;
    LBld := JsonBuilder;
    LBld.BeginObject;
    LBld.Key(AKey);
    LBld.Str(ARaw);
    LBld.EndObject;
    SetLength(LCaps, Length(LCaps) + 1);
    LCaps[High(LCaps)] := LBld.ToString;
  end;

begin
  Doc := JsonParse(ABody);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(ABody, 'response body must be a JSON object');
  Root := Doc.Root;

  { 正常错误走 HTTP 状态码（transport 已归约）；200 携 error 信封即违例 }
  if Root.Get('type').IsStr and
    (Root.Get('type').AsStr.ToString = 'error') then
    ProtocolError(ABody,
      'error envelope on a success response is a protocol violation');

  AMsg := Default(TMessage);
  AMsg.Role := mrAssistant;
  if Root.Get('id').IsStr then
    AMsg.Id := Root.Get('id').AsStr.ToString;
  if Root.Get('model').IsStr then
    AMsg.Model := Root.Get('model').AsStr.ToString;

  LContent := Root.Get('content');
  if not LContent.IsArray then
    ProtocolError(ABody, 'missing content array');

  for I := 0 to Integer(LContent.ArrayLen) - 1 do
  begin
    LBlock := LContent.ArrayGet(UInt32(I));
    if not LBlock.IsObject then
      ProtocolError(ABody, 'content block must be an object');
    if not LBlock.Get('type').IsStr then
      ProtocolError(ABody, 'content block missing type');
    LType := LBlock.Get('type').AsStr.ToString;
    if LType = 'text' then
    begin
      if LBlock.Get('text').IsStr then
      begin
        LTxt := LBlock.Get('text').AsStr.ToString;
        if LTxt <> '' then
        begin
          AddPart(pkText);
          AMsg.Parts[High(AMsg.Parts)].Text := LTxt;
        end;
      end
      else
        ProtocolError(ABody, 'text block requires text string');
    end
    else if LType = 'thinking' then
    begin
      AddPart(pkThinking);
      if LBlock.Get('thinking').IsStr then
        AMsg.Parts[High(AMsg.Parts)].Text :=
          LBlock.Get('thinking').AsStr.ToString;
      { Q-A3：signature 原样透传 }
      if LBlock.Get('signature').IsStr then
        AMsg.Parts[High(AMsg.Parts)].Signature :=
          LBlock.Get('signature').AsStr.ToString;
    end
    else if LType = 'tool_use' then
    begin
      AddPart(pkToolCall);
      if LBlock.Get('id').IsStr then
        AMsg.Parts[High(AMsg.Parts)].ToolCallId :=
          LBlock.Get('id').AsStr.ToString;
      if LBlock.Get('name').IsStr then
        AMsg.Parts[High(AMsg.Parts)].ToolName :=
          LBlock.Get('name').AsStr.ToString;
      LD := LBlock.Get('input');
      if not LD.IsObject then
        ProtocolError(ABody, 'tool_use block requires input object');
      AMsg.Parts[High(AMsg.Parts)].ArgumentsJson := JsonStringify(LD);
    end
    else
    begin
      { 未映射块类型：零值+捕获+warn，绝不臆造近似映射（§0）}
      WarnLog(ALog, 'anthropic: unmapped content block type "' +
        LType + '" skipped');
      AddCap(CAGENT_UNMAPPED_BLOCK, LType);
    end;
  end;

  { stop_reason：四值映射；未知取 frNone + 捕获 + warn }
  if Root.Get('stop_reason').IsStr then
  begin
    LTxt := Root.Get('stop_reason').AsStr.ToString;
    if LTxt <> '' then
    begin
      AMsg.FinishReason := MapStopReason(LTxt, LUnmapped);
      if LUnmapped <> '' then
      begin
        WarnLog(ALog, 'anthropic: unmapped stop_reason "' + LUnmapped +
          '" -> frNone');
        AddCap(CAGENT_UNMAPPED_STOP, LUnmapped);
      end;
    end;
  end
  else if Root.Get('stop_reason').IsValid and
    (not Root.Get('stop_reason').IsNull) then
    ProtocolError(ABody, 'stop_reason must be a string or null');

  { usage 全字段映射（D9）：未知字段保持 CUsageUnknown }
  LU := Root.Get('usage');
  if LU.IsObject then
  begin
    AMsg.Usage := Default(TTokenUsage);
    AMsg.Usage.InputTokens := CUsageUnknown;
    AMsg.Usage.OutputTokens := CUsageUnknown;
    AMsg.Usage.CacheReadInputTokens := CUsageUnknown;
    AMsg.Usage.CacheWriteInputTokens := CUsageUnknown;
    AMsg.Usage.ReasoningTokens := CUsageUnknown;
    if LU.Get('input_tokens').IsInt then
      AMsg.Usage.InputTokens := LU.Get('input_tokens').AsInt;
    if LU.Get('output_tokens').IsInt then
      AMsg.Usage.OutputTokens := LU.Get('output_tokens').AsInt;
    if LU.Get('cache_read_input_tokens').IsInt then
      AMsg.Usage.CacheReadInputTokens :=
        LU.Get('cache_read_input_tokens').AsInt;
    if LU.Get('cache_creation_input_tokens').IsInt then
      AMsg.Usage.CacheWriteInputTokens :=
        LU.Get('cache_creation_input_tokens').AsInt;
  end;

  { 根级未知键无损捕获，与块级未映射证据合并进消息 ExtraJson }
  SetLength(LCaps, Length(LCaps) + 1);
  LCaps[High(LCaps)] := CaptureExtraJson(Root,
    ['id', 'type', 'role', 'content', 'model', 'stop_reason',
     'stop_sequence', 'usage'], CMaxExtraKeys, ALog);
  AMsg.ExtraJson := MergeExtraJson(LCaps);
end;

{ ---- 流帧解码器（§2.3）---- }

constructor TAnthropicWireDecoder.Create(const ALog: ILogger);
begin
  inherited Create;
  FLog := ALog;
  FPool := TWireToolSlotPool.Create;
  FInTokens := CUsageUnknown;
  FOutTokens := CUsageUnknown;
  FCacheRead := CUsageUnknown;
  FCacheWrite := CUsageUnknown;
end;

destructor TAnthropicWireDecoder.Destroy;
begin
  FPool.Free;
  inherited Destroy;
end;

function TAnthropicWireDecoder.BlockKindAt(AIdx: Integer): TBlockKind;
var
  I: Integer;
begin
  Result := btkNone;
  for I := 0 to High(FBlocks) do
    if FBlocks[I].Index = AIdx then
      Exit(FBlocks[I].Kind);
end;

procedure TAnthropicWireDecoder.SetBlockKind(AIdx: Integer;
  AKind: TBlockKind);
var
  I, N: Integer;
begin
  for I := 0 to High(FBlocks) do
    if FBlocks[I].Index = AIdx then
    begin
      FBlocks[I].Kind := AKind;
      Exit;
    end;
  N := Length(FBlocks);
  SetLength(FBlocks, N + 1);
  FBlocks[N].Index := AIdx;
  FBlocks[N].Kind := AKind;
end;

{ 无同帧增量可挂的未映射键顺延；有载体则并入首增量（同 openai 策略）}
procedure TAnthropicWireDecoder.StashUnmapped(const AKey, ARaw: string);
var
  LB: IJsonBuilder;
begin
  if ARaw = '' then
    Exit;
  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key(AKey);
  LB.Str(ARaw);
  LB.EndObject;
  FPendingUnmapped := MergeExtraJson([FPendingUnmapped, LB.ToString]);
end;

procedure TAnthropicWireDecoder.HandleStart(const AData: string;
  var ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  LM, LU: TJsonValue;
  LD: TStreamDelta;
begin
  if FStarted then
    ProtocolError(AData, 'duplicate message_start');
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'message_start payload must be an object');
  LM := Doc.Root.Get('message');
  if not LM.IsObject then
    ProtocolError(AData, 'message_start requires message object');
  FStarted := True;                  { Q-A1：强制首信封 }
  LD := Default(TStreamDelta);
  LD.Kind := sdkEnvelope;
  if LM.Get('id').IsStr then
    LD.MessageId := LM.Get('id').AsStr.ToString;
  if LM.Get('model').IsStr then
    LD.Model := LM.Get('model').AsStr.ToString;
  AddStreamDelta(ADeltas, LD);

  { Q-A2：usage 双源——start 给 input 侧 }
  LU := LM.Get('usage');
  if LU.IsObject then
  begin
    if LU.Get('input_tokens').IsInt then
      FInTokens := LU.Get('input_tokens').AsInt;
    if LU.Get('cache_read_input_tokens').IsInt then
      FCacheRead := LU.Get('cache_read_input_tokens').AsInt;
    if LU.Get('cache_creation_input_tokens').IsInt then
      FCacheWrite := LU.Get('cache_creation_input_tokens').AsInt;
  end;
end;

function WireStrOrEmpty(const AV: TJsonValue): string;
begin
  if AV.IsStr then
    Result := AV.AsStr.ToString
  else
    Result := '';
end;

procedure TAnthropicWireDecoder.HandleBlockStart(const AData: string;
  var ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  LB: TJsonValue;
  LIdx: Integer;
  LType: string;
  LCreated: Boolean;
  LSlotPos: Integer;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'content_block_start payload must be an object');
  if not Doc.Root.Get('index').IsInt then
    ProtocolError(AData, 'content_block_start requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  LB := Doc.Root.Get('content_block');
  if not LB.IsObject then
    ProtocolError(AData, 'content_block_start requires content_block');
  if not LB.Get('type').IsStr then
    ProtocolError(AData, 'content_block missing type');
  LType := LB.Get('type').AsStr.ToString;

  if LType = 'text' then
    SetBlockKind(LIdx, btkText)
  else if LType = 'thinking' then
    SetBlockKind(LIdx, btkThinking)
  else if LType = 'tool_use' then
  begin
    SetBlockKind(LIdx, btkTool);
    LSlotPos := FPool.Find(LIdx, LCreated);
    if LCreated then
    begin
      { anthropic 的 name 在 start 即就绪：立即宣告 }
      FPool.UpdateIdentity(LSlotPos,
        WireStrOrEmpty(LB.Get('id')), WireStrOrEmpty(LB.Get('name')));
      FPool.Announce(LSlotPos, ADeltas);
    end
    else
      ProtocolError(AData, 'duplicate tool_use block index');
  end
  else
  begin
    SetBlockKind(LIdx, btkUnknown);
    WarnLog(FLog, 'anthropic: unmapped content block type "' +
      LType + '" (stream)');
    StashUnmapped(CAGENT_UNMAPPED_BLOCK, LType);
  end;
end;

procedure TAnthropicWireDecoder.EmitStreamError(const AData: string;
  var ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  LE: TJsonValue;
  LType: string;
  LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'error payload must be an object');
  LE := Doc.Root.Get('error');
  if not LE.IsObject then
    ProtocolError(AData, 'error event requires error object');
  if LE.Get('type').IsStr then
    LType := LE.Get('type').AsStr.ToString
  else
    LType := '';
  LD := Default(TStreamDelta);
  LD.Kind := sdkError;
  LD.Error.Code := ErrorCodeForStreamErrType(LType);
  if LE.Get('message').IsStr then
    LD.Error.Message := LE.Get('message').AsStr.ToString;
  if LType <> '' then
    LD.Error.Message := '[' + LType + '] ' + LD.Error.Message;
  LD.Error.Retryable := IsRetryable(LD.Error.Code);
  LD.Error.RetryAfterMs := CRetryAfterUnknown;
  AddStreamDelta(ADeltas, LD);
  { 未映射 type 以 aecServer 兜底：原始 type 经保留键保真（已知类型不记）}
  if (LD.Error.Code = aecServer) and (LType <> '') and
    (LType <> 'overloaded_error') and (LType <> 'api_error') then
    StashUnmapped(CAGENT_UNMAPPED_ERRTYPE, LType);
end;

procedure TAnthropicWireDecoder.HandleBlockDelta(const AData: string;
  var ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  LDv: TJsonValue;
  LIdx: Integer;
  LKind: TBlockKind;
  LType, LTxt: string;
  LSlotPos: Integer;
  LCreated: Boolean;
  LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'content_block_delta payload must be an object');
  if not Doc.Root.Get('index').IsInt then
    ProtocolError(AData, 'content_block_delta requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  LKind := BlockKindAt(LIdx);
  if LKind = btkNone then
    ProtocolError(AData, 'delta for unknown content_block index');
  LDv := Doc.Root.Get('delta');
  if not LDv.IsObject then
    ProtocolError(AData, 'content_block_delta requires delta object');
  if not LDv.Get('type').IsStr then
    ProtocolError(AData, 'delta missing type');
  LType := LDv.Get('type').AsStr.ToString;

  if LType = 'text_delta' then
  begin
    if LKind <> btkText then
      ProtocolError(AData, 'text_delta on non-text block');
    LTxt := WireStrOrEmpty(LDv.Get('text'));
    if LTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkTextDelta;
      LD.TextDelta := LTxt;
      AddStreamDelta(ADeltas, LD);
    end;
  end
  else if LType = 'thinking_delta' then
  begin
    if LKind <> btkThinking then
      ProtocolError(AData, 'thinking_delta on non-thinking block');
    LTxt := WireStrOrEmpty(LDv.Get('thinking'));
    if LTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkThinkingDelta;
      LD.TextDelta := LTxt;
      AddStreamDelta(ADeltas, LD);
    end;
  end
  else if LType = 'signature_delta' then
  begin
    if LKind <> btkThinking then
      ProtocolError(AData, 'signature_delta on non-thinking block');
    LTxt := WireStrOrEmpty(LDv.Get('signature'));
    if LTxt <> '' then
    begin
      { 签名透传：空文本增量只携 Signature（fold 记入部件）}
      LD := Default(TStreamDelta);
      LD.Kind := sdkThinkingDelta;
      LD.Signature := LTxt;
      AddStreamDelta(ADeltas, LD);
    end;
  end
  else if LType = 'input_json_delta' then
  begin
    if LKind <> btkTool then
      ProtocolError(AData, 'input_json_delta on non-tool block');
    LTxt := WireStrOrEmpty(LDv.Get('partial_json'));
    if LTxt <> '' then
    begin
      LSlotPos := FPool.Find(LIdx, LCreated);
      if FPool.Announced[LSlotPos] then
      begin
        LD := Default(TStreamDelta);
        LD.Kind := sdkToolCallDelta;
        LD.ToolIndex := LIdx;
        LD.ArgumentsDelta := LTxt;
        AddStreamDelta(ADeltas, LD);
      end
      else
        FPool.AppendArgs(LSlotPos, LTxt);   { 防御：宣告前先缓冲 }
    end;
  end
  else
  begin
    WarnLog(FLog, 'anthropic: unmapped content delta type "' +
      LType + '" (stream)');
    StashUnmapped(CAGENT_UNMAPPED_DELTA, LType);
  end;
end;

procedure TAnthropicWireDecoder.HandleBlockStop(const AData: string;
  var ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  LIdx: Integer;
  LKind: TBlockKind;
  LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'content_block_stop payload must be an object');
  if not Doc.Root.Get('index').IsInt then
    ProtocolError(AData, 'content_block_stop requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  LKind := BlockKindAt(LIdx);
  if LKind = btkNone then
    ProtocolError(AData, 'stop for unopened content_block index');
  if LKind = btkTool then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallEnd;
    LD.ToolIndex := LIdx;
    AddStreamDelta(ADeltas, LD);
  end;
  SetBlockKind(LIdx, btkNone);       { 收块（其余类型无需显式事件）}
end;

procedure TAnthropicWireDecoder.HandleMessageDelta(const AData: string);
var
  Doc: IJsonDocument;
  LDv, LU: TJsonValue;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AData, 'message_delta payload must be an object');
  LDv := Doc.Root.Get('delta');
  if LDv.IsObject and LDv.Get('stop_reason').IsStr then
    FStopReason := LDv.Get('stop_reason').AsStr.ToString;
  { Q-A2：累计 output 取最后一次 }
  LU := Doc.Root.Get('usage');
  if LU.IsObject and LU.Get('output_tokens').IsInt then
    FOutTokens := LU.Get('output_tokens').AsInt;
end;

procedure TAnthropicWireDecoder.HandleMessageStop(
  var ADeltas: TStreamDeltaArray);
var
  LF: TStreamDelta;
  LU: TStreamDelta;
  LUnmapped: string;
begin
  FStopped := True;
  LF := Default(TStreamDelta);
  LF.Kind := sdkFinish;
  LF.FinishReason := MapStopReason(FStopReason, LUnmapped);
  if LUnmapped <> '' then
  begin
    WarnLog(FLog, 'anthropic: unmapped stop_reason "' + LUnmapped +
      '" -> frNone');
    StashUnmapped(CAGENT_UNMAPPED_STOP, LUnmapped);
  end;
  AddStreamDelta(ADeltas, LF);

  { Q-A2：流末统一合成 usage }
  LU := Default(TStreamDelta);
  LU.Kind := sdkUsage;
  LU.Usage := Default(TTokenUsage);
  LU.Usage.InputTokens := FInTokens;
  LU.Usage.OutputTokens := FOutTokens;
  LU.Usage.CacheReadInputTokens := FCacheRead;
  LU.Usage.CacheWriteInputTokens := FCacheWrite;
  LU.Usage.ReasoningTokens := CUsageUnknown;
  AddStreamDelta(ADeltas, LU);
end;

procedure TAnthropicWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent;
  out ADeltas: TStreamDeltaArray);
begin
  ADeltas := nil;
  if FFinalized then
    raise EAgentMisuse.Create('anthropic decoder reused after Finalize');
  if FDead then
    Exit;                            { 错误后到尾帧弃置 }
  if AEvent.Event = 'ping' then
    Exit;                            { §2.3：ping 忽略 }

  if AEvent.Event = 'message_start' then
    HandleStart(AEvent.Data, ADeltas)
  else if AEvent.Event = 'content_block_start' then
    HandleBlockStart(AEvent.Data, ADeltas)
  else if AEvent.Event = 'content_block_delta' then
    HandleBlockDelta(AEvent.Data, ADeltas)
  else if AEvent.Event = 'content_block_stop' then
    HandleBlockStop(AEvent.Data, ADeltas)
  else if AEvent.Event = 'message_delta' then
    HandleMessageDelta(AEvent.Data)
  else if AEvent.Event = 'message_stop' then
    HandleMessageStop(ADeltas)
  else if AEvent.Event = 'error' then
  begin
    { 流中途错误：产出 sdkError 后终止（§0 流中途错误规则）}
    EmitStreamError(AEvent.Data, ADeltas);
    FDead := True;
  end
  else
    WarnLog(FLog, 'anthropic: unknown SSE event "' + AEvent.Event +
      '" skipped');

  { 无载体挂起的未映射键落到本帧首增量 }
  if (FPendingUnmapped <> '') and (Length(ADeltas) > 0) then
  begin
    ADeltas[0].UnmappedJson :=
      MergeExtraJson([ADeltas[0].UnmappedJson, FPendingUnmapped]);
    FPendingUnmapped := '';
  end;
end;

procedure TAnthropicWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
begin
  ADeltas := nil;
  if FFinalized then
    Exit;                            { 幂等：重复调用返回空数组 }
  FFinalized := True;
  if FDead then
  begin
    FPendingUnmapped := '';
    Exit;                            { 错误终止的流不再叠加归因 }
  end;
  { Q-A8 fail-closed：无 message_start→message_stop 完整轨迹即抛，
    绝不把截断答案合成完整消息（与 OpenAI Q-O4 宽容是各自协议现实）}
  if (not FStarted) or (not FStopped) then
    ProtocolError('<stream>',
      'stream truncated before message_stop (Q-A8 fail-closed)');
  if FPendingUnmapped <> '' then
  begin
    WarnLog(FLog,
      'anthropic: dropping trailing unmapped keys without a carrier');
    FPendingUnmapped := '';
  end;
end;

function NewAnthropicWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TAnthropicWireDecoder.Create(ALog);
end;

{ ---- provider ---- }

type
  TAnthropicProvider = class(TInterfacedObject, IAgentProvider)
  private
    FOpts: TAnthropicOptions;
    FTransport: IAgentTransport;
    FLog: ILogger;
    function ResolveModel(const AReq: TCompletionRequest): string;
    function BuildWireRequest(const AReq: TCompletionRequest;
      AStream: Boolean): TWireRequest;
  public
    constructor Create(const AOpts: TAnthropicOptions);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TAnthropicProvider.Create(const AOpts: TAnthropicOptions);
begin
  inherited Create;
  FOpts := AOpts;
  FLog := AOpts.Common.Logger;
  if FOpts.Common.Transport <> nil then
    FTransport := FOpts.Common.Transport
  else
    FTransport := NewHttpTransport('anthropic');
end;

function TAnthropicProvider.GetName: string;
begin
  Result := 'anthropic';
end;

function TAnthropicProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'anthropic: model is required (request.Model or options.Common.Model)');
end;

function TAnthropicProvider.BuildWireRequest(
  const AReq: TCompletionRequest; AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
  I, N: Integer;
begin
  if FOpts.Common.ApiKey = '' then
    raise EAgentError.CreateLocal(aecConfig,
      'anthropic: api key is required (' + CANTHROPIC_ENV_API_KEY + ')');
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  { Q-A5 / Seed：无对应参数，忽略并记日志，不算错误 }
  if LReq.ParallelToolCalls <> tsUnset then
    WarnLog(FLog,
      'anthropic: parallel_tool_calls has no wire parameter (Q-A5), ignored');
  if LReq.Seed <> CSeedUnset then
    DebugLog(FLog, 'anthropic: seed has no wire parameter, ignored');

  Result := Default(TWireRequest);
  Result.Url := BuildAnthropicUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeAnthropicRequest(LReq, AStream);
  SetLength(Result.Headers, 0);
  N := Length(Result.Headers);
  SetLength(Result.Headers, N + 1);
  Result.Headers[N].Name := 'x-api-key';
  Result.Headers[N].Value := FOpts.Common.ApiKey;
  N := Length(Result.Headers);
  SetLength(Result.Headers, N + 1);
  Result.Headers[N].Name := 'anthropic-version';
  if FOpts.AnthropicVersion <> '' then
    Result.Headers[N].Value := FOpts.AnthropicVersion
  else
    Result.Headers[N].Value := CANTHROPIC_VERSION_DEFAULT;
  for I := 0 to High(FOpts.Common.ExtraHeaders) do
  begin
    N := Length(Result.Headers);
    SetLength(Result.Headers, N + 1);
    Result.Headers[N] := FOpts.Common.ExtraHeaders[I];
  end;
  Result.ConnectTimeoutMs := FOpts.Common.ConnectTimeoutMs;
  Result.TotalTimeoutMs := FOpts.Common.TotalTimeoutMs;
end;

function TAnthropicProvider.Complete(
  const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeAnthropicResponse(LResp.BodyText, Result, FLog);
end;

function TAnthropicProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  { 同步 transport 无法中断在途请求：令牌在起止点检查（诚实边界）}
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TAnthropicProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewAnthropicWireDecoder(FLog), nil, 'anthropic');
end;

function TAnthropicProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewAnthropicWireDecoder(FLog), AToken, 'anthropic');
end;

class function TAnthropicOptions.New(
  const AModel: string): TAnthropicOptions;
begin
  Result := Default(TAnthropicOptions);
  Result.Common.BaseUrl := CANTHROPIC_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := CANTHROPIC_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := CANTHROPIC_TOTAL_TIMEOUT_MS;
  Result.AnthropicVersion := CANTHROPIC_VERSION_DEFAULT;
end;

function NewAnthropicProvider(
  const AOpts: TAnthropicOptions): IAgentProvider;
begin
  Result := TAnthropicProvider.Create(AOpts);
end;

function NewAnthropicProviderFromEnv: IAgentProvider;
var
  O: TAnthropicOptions;
  LUrl: string;
begin
  O := TAnthropicOptions.New('');
  O.Common.ApiKey := GetEnvironmentVariable(CANTHROPIC_ENV_API_KEY);
  O.Common.Model := GetEnvironmentVariable(CANTHROPIC_ENV_MODEL);
  LUrl := GetEnvironmentVariable(CANTHROPIC_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  { 必填缺失返回 nil，绝不静默回退（CONSUMERS §3）}
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewAnthropicProvider(O);
end;

end.
