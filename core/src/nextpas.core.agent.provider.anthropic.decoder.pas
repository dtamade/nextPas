{**
 * nextpas.core.agent.provider.anthropic.decoder - Anthropic 流式状态机子域。
 *
 * 职责：WireDecoder 状态机（§2.3 event 主键归约、Q-A1/A2/A6/A8、
 * ping 忽略、error 终止、Finalize fail-closed、FPool 工具槽分桶）。
 * 单角色独占，不跨消息复用，零 IO。
 *
 * 属 provider.anthropic 四象限拆分之三（decoder），与 encode/decode/factory
 * 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.anthropic.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function NewAnthropicWireDecoder(const ALog: ILogger = nil): IAgentWireDecoder;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CAGENT_UNMAPPED_STOP = 'agent.unmapped.stop_reason';
  CAGENT_UNMAPPED_BLOCK = 'agent.unmapped.content_block_type';
  CAGENT_UNMAPPED_DELTA = 'agent.unmapped.content_delta_type';
  CAGENT_UNMAPPED_ERRTYPE = 'agent.unmapped.error_type';

type
  TAnthropicWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private type
    TBlockKind = (btkNone, btkText, btkThinking, btkTool, btkUnknown);
    TOpenBlock = record
      Index: Integer;
      Kind: TBlockKind;
    end;
  private
    FLog: ILogger;
    FStarted: Boolean;
    FStopped: Boolean;
    FDead: Boolean;
    FFinalized: Boolean;
    FPool: TWireToolSlotPool;
    FBlocks: array of TOpenBlock;
    FInTokens: Int64;
    FCacheRead: Int64;
    FCacheWrite: Int64;
    FOutTokens: Int64;
    FStopReason: string;
    FPendingUnmapped: TJsonText;
    procedure HandleStart(const AData: string; var B: TAgentDeltaBuilder);
    procedure HandleBlockStart(const AData: string; var B: TAgentDeltaBuilder);
    procedure HandleBlockDelta(const AData: string; var B: TAgentDeltaBuilder);
    procedure HandleBlockStop(const AData: string; var B: TAgentDeltaBuilder);
    procedure HandleMessageDelta(const AData: string);
    procedure HandleMessageStop(var B: TAgentDeltaBuilder);
    function BlockKindAt(AIdx: Integer): TBlockKind;
    procedure SetBlockKind(AIdx: Integer; AKind: TBlockKind);
    procedure StashUnmapped(const AKey, ARaw: string);
    procedure EmitStreamError(const AData: string; var B: TAgentDeltaBuilder);
  public
    constructor Create(const ALog: ILogger);
    destructor Destroy; override;
    procedure DecodeEvent(const AEvent: TWireSSEEvent; out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure DebugLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentDebugLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string); inline;
begin
  AgentProtocolError('anthropic', ABodySrc, AMsg);
end;

function MapStopReason(const S: string; out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  Result := frNone;
  if S = 'end_turn' then Exit(frStop);
  if S = 'stop_sequence' then Exit(frStop);
  if S = 'max_tokens' then Exit(frLength);
  if S = 'tool_use' then Exit(frToolCalls);
  if S = 'refusal' then Exit(frContentFilter);
  if S <> '' then AUnmapped := S;
end;

function ErrorCodeForStreamErrType(const AType: string): TAgentErrorCode;
begin
  if AType = 'rate_limit_error' then Exit(aecRateLimited);
  if (AType = 'overloaded_error') or (AType = 'api_error') then Exit(aecServer);
  if (AType = 'invalid_request_error') or (AType = 'request_too_large') then Exit(aecInvalidRequest);
  if (AType = 'authentication_error') or (AType = 'permission_error') or (AType = 'billing_error') then Exit(aecAuthentication);
  if AType = 'not_found_error' then Exit(aecNotFound);
  Result := aecServer;
end;

function WireStrOrEmpty(const AV: TJsonValue): string;
begin
  if AV.IsStr then Result := AV.AsStr.ToString else Result := '';
end;

// ---- TAnthropicWireDecoder ----

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
var I: Integer;
begin
  Result := btkNone;
  for I := 0 to High(FBlocks) do if FBlocks[I].Index = AIdx then Exit(FBlocks[I].Kind);
end;

procedure TAnthropicWireDecoder.SetBlockKind(AIdx: Integer; AKind: TBlockKind);
var I, N: Integer;
begin
  for I := 0 to High(FBlocks) do if FBlocks[I].Index = AIdx then begin FBlocks[I].Kind := AKind; Exit; end;
  N := Length(FBlocks); SetLength(FBlocks, N+1); FBlocks[N].Index := AIdx; FBlocks[N].Kind := AKind;
end;

procedure TAnthropicWireDecoder.StashUnmapped(const AKey, ARaw: string);
begin
  if ARaw = '' then Exit;
  FPendingUnmapped := MergeExtraJson([FPendingUnmapped, AgentUnmappedJson(AKey, ARaw)]);
end;

procedure TAnthropicWireDecoder.HandleStart(const AData: string; var B: TAgentDeltaBuilder);
var Doc: IJsonDocument; LM, LU: TJsonValue; LD: TStreamDelta;
begin
  if FStarted then ProtocolError(AData, 'duplicate message_start');
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'message_start payload must be an object');
  LM := Doc.Root.Get('message');
  if not LM.IsObject then ProtocolError(AData, 'message_start requires message object');
  FStarted := True;
  LD := Default(TStreamDelta); LD.Kind := sdkEnvelope;
  if LM.Get('id').IsStr then LD.MessageId := LM.Get('id').AsStr.ToString;
  if LM.Get('model').IsStr then LD.Model := LM.Get('model').AsStr.ToString;
  B.Add(LD);
  LU := LM.Get('usage');
  if LU.IsObject then begin
    if LU.Get('input_tokens').IsInt then FInTokens := LU.Get('input_tokens').AsInt;
    if LU.Get('cache_read_input_tokens').IsInt then FCacheRead := LU.Get('cache_read_input_tokens').AsInt;
    if LU.Get('cache_creation_input_tokens').IsInt then FCacheWrite := LU.Get('cache_creation_input_tokens').AsInt;
  end;
end;

procedure TAnthropicWireDecoder.HandleBlockStart(const AData: string; var B: TAgentDeltaBuilder);
var Doc: IJsonDocument; LB: TJsonValue; LIdx: Integer; LType: string; LCreated: Boolean; LSlotPos: Integer;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'content_block_start payload must be an object');
  if not Doc.Root.Get('index').IsInt then ProtocolError(AData, 'content_block_start requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  if LIdx < 0 then ProtocolError(AData, 'content_block index must be >=0');
  LB := Doc.Root.Get('content_block');
  if not LB.IsObject then ProtocolError(AData, 'content_block_start requires content_block');
  if not LB.Get('type').IsStr then ProtocolError(AData, 'content_block missing type');
  LType := LB.Get('type').AsStr.ToString;
  if LType = 'text' then SetBlockKind(LIdx, btkText)
  else if LType = 'thinking' then SetBlockKind(LIdx, btkThinking)
  else if LType = 'tool_use' then begin
    SetBlockKind(LIdx, btkTool);
    LSlotPos := FPool.Find(LIdx, LCreated);
    if LCreated then begin FPool.UpdateIdentity(LSlotPos, WireStrOrEmpty(LB.Get('id')), WireStrOrEmpty(LB.Get('name'))); FPool.AnnounceBuilder(LSlotPos, B); end
    else ProtocolError(AData, 'duplicate tool_use block index');
  end else begin
    SetBlockKind(LIdx, btkUnknown);
    WarnLog(FLog, 'anthropic: unmapped content block type "' + LType + '" (stream)');
    StashUnmapped(CAGENT_UNMAPPED_BLOCK, LType);
  end;
end;

procedure TAnthropicWireDecoder.HandleBlockDelta(const AData: string; var B: TAgentDeltaBuilder);
var Doc: IJsonDocument; LDv: TJsonValue; LIdx: Integer; LKind: TBlockKind; LType, LTxt: string; LSlotPos: Integer; LCreated: Boolean; LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'content_block_delta payload must be an object');
  if not Doc.Root.Get('index').IsInt then ProtocolError(AData, 'content_block_delta requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  if LIdx < 0 then ProtocolError(AData, 'content_block index must be >=0');
  LKind := BlockKindAt(LIdx);
  if LKind = btkNone then ProtocolError(AData, 'delta for unknown content_block index');
  LDv := Doc.Root.Get('delta');
  if not LDv.IsObject then ProtocolError(AData, 'content_block_delta requires delta object');
  if not LDv.Get('type').IsStr then ProtocolError(AData, 'delta missing type');
  LType := LDv.Get('type').AsStr.ToString;
  if LType = 'text_delta' then begin
    if LKind <> btkText then ProtocolError(AData, 'text_delta on non-text block');
    LTxt := WireStrOrEmpty(LDv.Get('text'));
    if LTxt <> '' then begin LD := Default(TStreamDelta); LD.Kind := sdkTextDelta; LD.TextDelta := LTxt; B.Add(LD); end;
  end else if LType = 'thinking_delta' then begin
    if LKind <> btkThinking then ProtocolError(AData, 'thinking_delta on non-thinking block');
    LTxt := WireStrOrEmpty(LDv.Get('thinking'));
    if LTxt <> '' then begin LD := Default(TStreamDelta); LD.Kind := sdkThinkingDelta; LD.TextDelta := LTxt; B.Add(LD); end;
  end else if LType = 'signature_delta' then begin
    if LKind <> btkThinking then ProtocolError(AData, 'signature_delta on non-thinking block');
    LTxt := WireStrOrEmpty(LDv.Get('signature'));
    if LTxt <> '' then begin LD := Default(TStreamDelta); LD.Kind := sdkThinkingDelta; LD.Signature := LTxt; B.Add(LD); end;
  end else if LType = 'input_json_delta' then begin
    if LKind <> btkTool then ProtocolError(AData, 'input_json_delta on non-tool block');
    LTxt := WireStrOrEmpty(LDv.Get('partial_json'));
    if LTxt <> '' then begin LSlotPos := FPool.Find(LIdx, LCreated); if FPool.Announced[LSlotPos] then begin LD := Default(TStreamDelta); LD.Kind := sdkToolCallDelta; LD.ToolIndex := LIdx; LD.ArgumentsDelta := LTxt; B.Add(LD); end else FPool.AppendArgs(LSlotPos, LTxt); end;
  end else begin
    WarnLog(FLog, 'anthropic: unmapped content delta type "' + LType + '" skipped');
    StashUnmapped(CAGENT_UNMAPPED_DELTA, LType);
  end;
end;

procedure TAnthropicWireDecoder.HandleBlockStop(const AData: string; var B: TAgentDeltaBuilder);
var Doc: IJsonDocument; LIdx: Integer; LKind: TBlockKind; LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'content_block_stop payload must be an object');
  if not Doc.Root.Get('index').IsInt then ProtocolError(AData, 'content_block_stop requires index');
  LIdx := Integer(Doc.Root.Get('index').AsInt);
  if LIdx < 0 then ProtocolError(AData, 'content_block index must be >=0');
  LKind := BlockKindAt(LIdx);
  if LKind = btkNone then ProtocolError(AData, 'stop for unopened content_block index');
  if LKind = btkTool then begin LD := Default(TStreamDelta); LD.Kind := sdkToolCallEnd; LD.ToolIndex := LIdx; B.Add(LD); end;
  SetBlockKind(LIdx, btkNone);
end;

procedure TAnthropicWireDecoder.HandleMessageDelta(const AData: string);
var Doc: IJsonDocument; LDv, LU: TJsonValue;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'message_delta payload must be an object');
  LDv := Doc.Root.Get('delta');
  if LDv.IsObject and LDv.Get('stop_reason').IsStr then FStopReason := LDv.Get('stop_reason').AsStr.ToString;
  LU := Doc.Root.Get('usage');
  if LU.IsObject and LU.Get('output_tokens').IsInt then FOutTokens := LU.Get('output_tokens').AsInt;
end;

procedure TAnthropicWireDecoder.HandleMessageStop(var B: TAgentDeltaBuilder);
var LF, LU: TStreamDelta; LUnmapped: string;
begin
  FStopped := True;
  LF := Default(TStreamDelta); LF.Kind := sdkFinish; LF.FinishReason := MapStopReason(FStopReason, LUnmapped);
  if LUnmapped <> '' then begin WarnLog(FLog, 'anthropic: unmapped stop_reason "' + LUnmapped + '" -> frNone'); StashUnmapped(CAGENT_UNMAPPED_STOP, LUnmapped); end;
  B.Add(LF);
  LU := Default(TStreamDelta); LU.Kind := sdkUsage; LU.Usage := Default(TTokenUsage); LU.Usage.InputTokens := FInTokens; LU.Usage.OutputTokens := FOutTokens; LU.Usage.CacheReadInputTokens := FCacheRead; LU.Usage.CacheWriteInputTokens := FCacheWrite; LU.Usage.ReasoningTokens := CUsageUnknown; B.Add(LU);
end;

procedure TAnthropicWireDecoder.EmitStreamError(const AData: string; var B: TAgentDeltaBuilder);
var Doc: IJsonDocument; LE: TJsonValue; LType: string; LD: TStreamDelta;
begin
  Doc := JsonParse(AData);
  if Doc.HasError or (not Doc.Root.IsObject) then ProtocolError(AData, 'error payload must be an object');
  LE := Doc.Root.Get('error');
  if not LE.IsObject then ProtocolError(AData, 'error event requires error object');
  if LE.Get('type').IsStr then LType := LE.Get('type').AsStr.ToString else LType := '';
  LD := Default(TStreamDelta); LD.Kind := sdkError; LD.Error.Code := ErrorCodeForStreamErrType(LType);
  if LE.Get('message').IsStr then LD.Error.Message := LE.Get('message').AsStr.ToString;
  if LType <> '' then LD.Error.Message := '[' + LType + '] ' + LD.Error.Message;
  LD.Error.Retryable := IsRetryable(LD.Error.Code); LD.Error.RetryAfterMs := CRetryAfterUnknown; B.Add(LD);
  if (LD.Error.Code = aecServer) and (LType <> '') and (LType <> 'overloaded_error') and (LType <> 'api_error') then StashUnmapped(CAGENT_UNMAPPED_ERRTYPE, LType);
end;

procedure TAnthropicWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent; out ADeltas: TStreamDeltaArray);
var B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then raise EAgentMisuse.Create('anthropic decoder reused after Finalize');
  if FDead then Exit;
  if AEvent.Event = 'ping' then Exit;
  B.Init;
  if AEvent.Event = 'message_start' then HandleStart(AEvent.Data, B)
  else if AEvent.Event = 'content_block_start' then HandleBlockStart(AEvent.Data, B)
  else if AEvent.Event = 'content_block_delta' then HandleBlockDelta(AEvent.Data, B)
  else if AEvent.Event = 'content_block_stop' then HandleBlockStop(AEvent.Data, B)
  else if AEvent.Event = 'message_delta' then HandleMessageDelta(AEvent.Data)
  else if AEvent.Event = 'message_stop' then HandleMessageStop(B)
  else if AEvent.Event = 'error' then begin EmitStreamError(AEvent.Data, B); FDead := True; end
  else WarnLog(FLog, 'anthropic: unknown SSE event "' + AEvent.Event + '" skipped');
  if (FPendingUnmapped <> '') and (B.Count > 0) then begin B.MergeToFirst(FPendingUnmapped); FPendingUnmapped := ''; end;
  ADeltas := B.Take;
end;

procedure TAnthropicWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
var B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then Exit;
  FFinalized := True;
  if FDead then begin FPendingUnmapped := ''; Exit; end;
  if (not FStarted) or (not FStopped) then ProtocolError('<stream>', 'stream truncated before message_stop (Q-A8 fail-closed)');
  B.Init;
  FPool.FlushUnannouncedBuilder(FLog, 'anthropic', B);
  ADeltas := B.Take;
  if FPendingUnmapped <> '' then begin WarnLog(FLog, 'anthropic: dropping trailing unmapped keys without a carrier'); FPendingUnmapped := ''; end;
end;

function NewAnthropicWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TAnthropicWireDecoder.Create(ALog);
end;

end.
