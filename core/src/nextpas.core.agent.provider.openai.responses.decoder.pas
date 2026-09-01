{**
 * nextpas.core.agent.provider.openai.responses.decoder - Responses 流式状态机子域。
 *
 * 职责：WireDecoder 状态机（WIRE-MAPPINGS §3.3 事件主键归约、Q-R2/Q-R5、
 * item_id→槽位映射、created 强制首信封、created→终态轨迹校验 fail-closed、
 * ping 忽略、error 终止、Finalize 兜底、FPool 工具槽分桶）。
 * 单角色独占，不跨消息复用，零 IO。
 *
 * 属 provider.openai.responses 四象限拆分之三（decoder），与
 * encode/decode/facade 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.openai.responses.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.intf;

function NewResponsesWireDecoder(const ALog: ILogger = nil): IAgentWireDecoder;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CKNOWN_EVENT: array[0..4] of string = ('type', 'item', 'item_id',
    'delta', 'response');

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
begin
  AgentProtocolError('openai.responses', ABodySrc, AMsg);
end;

procedure FillUsageResponses(const AV: TJsonValue; out AU: TTokenUsage);
var
  LD: TJsonValue;
begin
  AgentInitUsageUnknown(AU);
  if not AV.IsObject then
    Exit;
  if AV.Get('input_tokens').IsInt then
    AU.InputTokens := AV.Get('input_tokens').AsInt;
  if AV.Get('output_tokens').IsInt then
    AU.OutputTokens := AV.Get('output_tokens').AsInt;
  LD := AV.Get('output_tokens_details');
  if LD.IsObject and LD.Get('reasoning_tokens').IsInt then
    AU.ReasoningTokens := LD.Get('reasoning_tokens').AsInt;
  LD := AV.Get('input_tokens_details');
  if LD.IsObject and LD.Get('cached_tokens').IsInt then
    AU.CacheReadInputTokens := LD.Get('cached_tokens').AsInt;
end;

type
  TResponsesWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private
    FLog: ILogger;
    FSawEnvelope: Boolean;
    FTerminal: Boolean;
    FFinalized: Boolean;
    FPool: TWireToolSlotPool;
    FIds: array of record
      ItemId: string;
      Slot: Integer;
    end;
    FPendingUnmapped: TJsonText;
    function SlotFor(const AItemId: string): Integer;
    procedure HandleItemAdded(const ARoot: TJsonValue;
      const ASrc: string; var B: TAgentDeltaBuilder);
    procedure HandleArgsDelta(const ARoot: TJsonValue;
      const ASrc: string; var B: TAgentDeltaBuilder);
    procedure HandleItemDone(const ARoot: TJsonValue;
      const ASrc: string; var B: TAgentDeltaBuilder);
    procedure EmitError(const AErrObj: TJsonValue; const ASrc: string;
      var B: TAgentDeltaBuilder);
  public
    constructor Create(const ALog: ILogger);
    destructor Destroy; override;
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

constructor TResponsesWireDecoder.Create(const ALog: ILogger);
begin
  inherited Create;
  FLog := ALog;
  FPool := TWireToolSlotPool.Create;
end;

destructor TResponsesWireDecoder.Destroy;
begin
  FPool.Free;
  inherited Destroy;
end;

function TResponsesWireDecoder.SlotFor(const AItemId: string): Integer;
var
  I: Integer;
  LCreated: Boolean;
begin
  for I := 0 to High(FIds) do
    if FIds[I].ItemId = AItemId then
      Exit(FIds[I].Slot);
  Result := FPool.Count;
  FPool.Find(Result, LCreated);
  SetLength(FIds, Length(FIds) + 1);
  FIds[High(FIds)].ItemId := AItemId;
  FIds[High(FIds)].Slot := Result;
end;

procedure TResponsesWireDecoder.HandleItemAdded(const ARoot: TJsonValue;
  const ASrc: string; var B: TAgentDeltaBuilder);
var
  LItem: TJsonValue;
  LTyp, LItemId, LCallId, LName: string;
  LSlot: Integer;
begin
  LItem := ARoot.Get('item');
  if not LItem.IsObject then
    ProtocolError(ASrc, 'output_item.added requires item object');
  LTyp := '';
  if LItem.Get('type').IsStr then
    LTyp := LItem.Get('type').AsStr.ToString;
  if LTyp <> 'function_call' then
    Exit;
  LItemId := '';
  LCallId := '';
  LName := '';
  if LItem.Get('id').IsStr then
    LItemId := LItem.Get('id').AsStr.ToString;
  if LItem.Get('call_id').IsStr then
    LCallId := LItem.Get('call_id').AsStr.ToString;
  if LItem.Get('name').IsStr then
    LName := LItem.Get('name').AsStr.ToString;
  if (LItemId = '') and (LCallId = '') then
    ProtocolError(ASrc, 'function_call item requires id or call_id');
  if LItemId = '' then
    LItemId := LCallId;
  LSlot := SlotFor(LItemId);
  FPool.UpdateIdentity(LSlot, LCallId, LName);
  if FPool.HasName[LSlot] and (not FPool.Announced[LSlot]) then
    FPool.AnnounceBuilder(LSlot, B);
end;

procedure TResponsesWireDecoder.HandleArgsDelta(const ARoot: TJsonValue;
  const ASrc: string; var B: TAgentDeltaBuilder);
var
  LDeltaV: TJsonValue;
  LItemId, LArgs: string;
  LSlot: Integer;
  LD: TStreamDelta;
begin
  LItemId := '';
  if ARoot.Get('item_id').IsStr then
    LItemId := ARoot.Get('item_id').AsStr.ToString;
  if LItemId = '' then
    ProtocolError(ASrc, 'arguments.delta requires item_id');
  LDeltaV := ARoot.Get('delta');
  if not LDeltaV.IsStr then
    ProtocolError(ASrc, 'arguments.delta requires string delta');
  LArgs := LDeltaV.AsStr.ToString;
  LSlot := SlotFor(LItemId);
  if FPool.Announced[LSlot] then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := LSlot;
    LD.ArgumentsDelta := LArgs;
    B.Add(LD);
  end
  else
    FPool.AppendArgs(LSlot, LArgs);
end;

procedure TResponsesWireDecoder.HandleItemDone(const ARoot: TJsonValue;
  const ASrc: string; var B: TAgentDeltaBuilder);
var
  LItem: TJsonValue;
  LTyp, LItemId, LCallId, LName, LArgs: string;
  LSlot: Integer;
begin
  LItem := ARoot.Get('item');
  if not LItem.IsObject then
    Exit;
  LTyp := '';
  if LItem.Get('type').IsStr then
    LTyp := LItem.Get('type').AsStr.ToString;
  if LTyp <> 'function_call' then
    Exit;
  LItemId := '';
  LCallId := '';
  LName := '';
  LArgs := '';
  if LItem.Get('id').IsStr then
    LItemId := LItem.Get('id').AsStr.ToString;
  if LItem.Get('call_id').IsStr then
    LCallId := LItem.Get('call_id').AsStr.ToString;
  if LItem.Get('name').IsStr then
    LName := LItem.Get('name').AsStr.ToString;
  if LItem.Get('arguments').IsStr then
    LArgs := LItem.Get('arguments').AsStr.ToString;
  if LItemId = '' then
    LItemId := LCallId;
  if LItemId = '' then
    Exit;
  LSlot := SlotFor(LItemId);
  FPool.UpdateIdentity(LSlot, LCallId, LName);
  if not FPool.Announced[LSlot] then
  begin
    if LArgs <> '' then
      FPool.AppendArgs(LSlot, LArgs);
    if FPool.HasName[LSlot] then
      FPool.AnnounceBuilder(LSlot, B);
  end;
end;

procedure TResponsesWireDecoder.EmitError(const AErrObj: TJsonValue;
  const ASrc: string; var B: TAgentDeltaBuilder);
var
  LD: TStreamDelta;
  LCode, LMsg: string;
begin
  if not AErrObj.IsObject then
    ProtocolError(ASrc, 'error event requires error object');
  LCode := '';
  LMsg := '';
  if AErrObj.Get('code').IsStr then
    LCode := AErrObj.Get('code').AsStr.ToString;
  if AErrObj.Get('message').IsStr then
    LMsg := AErrObj.Get('message').AsStr.ToString;
  LD := Default(TStreamDelta);
  LD.Kind := sdkError;
  if LCode = 'rate_limit_exceeded' then
    LD.Error.Code := aecRateLimited
  else if LCode = 'context_length_exceeded' then
    LD.Error.Code := aecContextOverflow
  else if LCode = 'invalid_request_error' then
    LD.Error.Code := aecInvalidRequest
  else
    LD.Error.Code := aecServer;
  LD.Error.Message := LMsg;
  if LCode <> '' then
    LD.Error.Message := '[' + LCode + '] ' + LD.Error.Message;
  LD.Error.Retryable := IsRetryable(LD.Error.Code);
  LD.Error.RetryAfterMs := CRetryAfterUnknown;
  B.Add(LD);
end;

procedure TResponsesWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent;
  out ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  Root, LRsp, LU: TJsonValue;
  LD: TStreamDelta;
  LId, LModel, LEv, LDeltaTxt, LCapture: string;
  B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then
    raise EAgentMisuse.Create('responses decoder reused after Finalize');
  LEv := AEvent.Event;
  if (LEv = '') or (LEv = 'ping') then
  begin
    if AEvent.Data = '[DONE]' then
    begin
      FTerminal := True;
      Exit;
    end;
  end;
  B.Init;

  Doc := JsonParse(AEvent.Data);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AEvent.Data, 'stream payload must be a JSON object');
  Root := Doc.Root;

  if LEv = '' then
  begin
    if Root.Get('type').IsStr then
      LEv := Root.Get('type').AsStr.ToString;
  end;

  if LEv = 'response.created' then
  begin
    if FSawEnvelope then
    begin
      ADeltas := B.Take;
      Exit;
    end;
    LRsp := Root.Get('response');
    LId := '';
    LModel := '';
    if LRsp.IsObject then
    begin
      if LRsp.Get('id').IsStr then
        LId := LRsp.Get('id').AsStr.ToString;
      if LRsp.Get('model').IsStr then
        LModel := LRsp.Get('model').AsStr.ToString;
    end;
    LD := Default(TStreamDelta);
    LD.Kind := sdkEnvelope;
    LD.MessageId := LId;
    LD.Model := LModel;
    B.Add(LD);
    FSawEnvelope := True;
    ADeltas := B.Take;
    Exit;
  end;

  if LEv = 'response.output_text.delta' then
  begin
    LDeltaTxt := '';
    if Root.Get('delta').IsStr then
      LDeltaTxt := Root.Get('delta').AsStr.ToString;
    if LDeltaTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkTextDelta;
      LD.TextDelta := LDeltaTxt;
      B.Add(LD);
    end;
  end
  else if LEv = 'response.reasoning_summary_text.delta' then
  begin
    LDeltaTxt := '';
    if Root.Get('delta').IsStr then
      LDeltaTxt := Root.Get('delta').AsStr.ToString;
    if LDeltaTxt <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkThinkingDelta;
      LD.TextDelta := LDeltaTxt;
      B.Add(LD);
    end;
  end
  else if LEv = 'response.output_item.added' then
    HandleItemAdded(Root, AEvent.Data, B)
  else if LEv = 'response.function_call_arguments.delta' then
    HandleArgsDelta(Root, AEvent.Data, B)
  else if LEv = 'response.output_item.done' then
    HandleItemDone(Root, AEvent.Data, B)
  else if (LEv = 'response.completed') or (LEv = 'response.incomplete') then
  begin
    LRsp := Root.Get('response');
    if LRsp.IsObject then
    begin
      LU := LRsp.Get('usage');
      if LU.IsObject then
      begin
        LD := Default(TStreamDelta);
        LD.Kind := sdkUsage;
        FillUsageResponses(LU, LD.Usage);
        B.Add(LD);
      end;
    end;
    LD := Default(TStreamDelta);
    LD.Kind := sdkFinish;
    if LEv = 'response.incomplete' then
      LD.FinishReason := frLength
    else
      LD.FinishReason := frStop;
    if (LD.FinishReason = frStop) and (FPool.Count > 0) then
      LD.FinishReason := frToolCalls;
    B.Add(LD);
    FTerminal := True;
  end
  else if (LEv = 'response.failed') or (LEv = 'response.error') then
  begin
    if LEv = 'response.failed' then
    begin
      LRsp := Root.Get('response');
      if LRsp.IsObject then
        EmitError(LRsp.Get('error'), AEvent.Data, B)
      else
        EmitError(Root, AEvent.Data, B);
    end
    else
      EmitError(Root.Get('error'), AEvent.Data, B);
    FTerminal := True;
  end;

  LCapture := CaptureExtraJson(Root, CKNOWN_EVENT, CMaxExtraKeys, FLog);
  if LCapture <> '' then
  begin
    if B.Count > 0 then
      B.MergeToLast(LCapture)
    else
      FPendingUnmapped := MergeExtraJson([FPendingUnmapped, LCapture]);
  end;
  if (FPendingUnmapped <> '') and (B.Count > 0) then
  begin
    B.MergeToFirst(FPendingUnmapped);
    FPendingUnmapped := '';
  end;
  ADeltas := B.Take;
end;

procedure TResponsesWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
var
  B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then
    Exit;
  FFinalized := True;
  B.Init;
  if (not FSawEnvelope) or (not FTerminal) then
    ProtocolError('', 'stream ended without terminal response event ' +
      '(truncated stream)');
  FPool.FlushUnannouncedBuilder(FLog, 'openai.responses', B);
  ADeltas := B.Take;
  if FPendingUnmapped <> '' then
  begin
    WarnLog(FLog,
      'openai.responses: dropping trailing unmapped keys without carrier');
    FPendingUnmapped := '';
  end;
end;

function NewResponsesWireDecoder(
  const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TResponsesWireDecoder.Create(ALog);
end;

end.
