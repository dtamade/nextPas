{**
 * nextpas.core.agent.provider.openai.decoder - OpenAI 流式状态机子域。
 *
 * 职责：WireDecoder 状态机（WIRE-MAPPINGS §1.3 帧序归约、Q-O2/Q-O3/Q-O4/
 * Q-O5/Q-O6/Q-O7、ping 心跳忽略、[DONE] 终止、Finalize 兜底、FPool 工具槽
 * 分桶）。单角色独占，不跨消息复用，零 IO。
 *
 * 属 provider.openai 四象限拆分之三（decoder），与 encode/decode/facade
 * 互不循环，仅向下依赖 base/errors/intf/common/json。
 *}

unit nextpas.core.agent.provider.openai.decoder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.agent.intf;

function NewOpenAIWireDecoder(const ALog: ILogger = nil): IAgentWireDecoder;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common;

const
  CKNOWN_ROOT: array[0..4] of string = ('id', 'object', 'choices', 'usage',
    'model');
  CAGENT_UNMAPPED_FINISH = 'agent.unmapped.finish_reason';

procedure WarnLog(const ALog: ILogger; const AMsg: string); inline;
begin
  AgentWarnLog(ALog, AMsg);
end;

procedure ProtocolError(const ABodySrc: string; const AMsg: string);
begin
  AgentProtocolError('openai', ABodySrc, AMsg);
end;

function MapFinishReason(const S: string;
  out AUnmapped: string): TFinishReason;
begin
  AUnmapped := '';
  if S = 'stop' then
    Exit(frStop);
  if S = 'length' then
    Exit(frLength);
  if S = 'tool_calls' then
    Exit(frToolCalls);
  if S = 'content_filter' then
    Exit(frContentFilter);
  Result := frNone;
  AUnmapped := S;
end;

procedure FillUsage(const AV: TJsonValue; out AU: TTokenUsage);
var
  LD: TJsonValue;
begin
  AgentInitUsageUnknown(AU);
  if not AV.IsObject then
    Exit;
  if AV.Get('prompt_tokens').IsInt then
    AU.InputTokens := AV.Get('prompt_tokens').AsInt;
  if AV.Get('completion_tokens').IsInt then
    AU.OutputTokens := AV.Get('completion_tokens').AsInt;
  LD := AV.Get('completion_tokens_details');
  if LD.IsObject and LD.Get('reasoning_tokens').IsInt then
    AU.ReasoningTokens := LD.Get('reasoning_tokens').AsInt;
  LD := AV.Get('prompt_tokens_details');
  if LD.IsObject and LD.Get('cached_tokens').IsInt then
    AU.CacheReadInputTokens := LD.Get('cached_tokens').AsInt;
end;

type
  TOpenAIWireDecoder = class(TInterfacedObject, IAgentWireDecoder)
  private
    FLog: ILogger;
    FSawEnvelope: Boolean;
    FDone: Boolean;
    FFinalized: Boolean;
    FPool: TWireToolSlotPool;
    FPendingUnmapped: TJsonText;
    procedure HandleToolCalls(const AEntries: TJsonValue;
      const ASrc: string; var B: TAgentDeltaBuilder);
  public
    constructor Create(const ALog: ILogger);
    destructor Destroy; override;
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

constructor TOpenAIWireDecoder.Create(const ALog: ILogger);
begin
  inherited Create;
  FLog := ALog;
  FPool := TWireToolSlotPool.Create;
end;

destructor TOpenAIWireDecoder.Destroy;
begin
  FPool.Free;
  inherited Destroy;
end;

procedure TOpenAIWireDecoder.HandleToolCalls(const AEntries: TJsonValue;
  const ASrc: string; var B: TAgentDeltaBuilder);
var
  I, LSlotPos: Integer;
  LItem, LFn, LIdxV: TJsonValue;
  LIdx: Integer;
  LId, LName, LArgs: string;
  LCreated: Boolean;
  LD: TStreamDelta;
begin
  for I := 0 to Integer(AEntries.ArrayLen) - 1 do
  begin
    LItem := AEntries.ArrayGet(UInt32(I));
    if not LItem.IsObject then
      ProtocolError(ASrc, 'tool call stream entry must be an object');
    LIdxV := LItem.Get('index');
    if LIdxV.IsInt then
    begin
      LIdx := Integer(LIdxV.AsInt);
      if LIdx < 0 then
        ProtocolError(ASrc, 'tool call stream entry negative index');
    end
    else
      LIdx := 0;
    LId := '';
    LName := '';
    LArgs := '';
    if LItem.Get('id').IsStr then
      LId := LItem.Get('id').AsStr.ToString;
    LFn := LItem.Get('function');
    if LFn.IsObject then
    begin
      if LFn.Get('name').IsStr then
        LName := LFn.Get('name').AsStr.ToString;
      if LFn.Get('arguments').IsStr then
        LArgs := LFn.Get('arguments').AsStr.ToString;
    end;

    LSlotPos := FPool.Find(LIdx, LCreated);
    FPool.UpdateIdentity(LSlotPos, LId, LName);
    if not FPool.Announced[LSlotPos] then
    begin
      if FPool.HasName[LSlotPos] then
      begin
        FPool.AnnounceBuilder(LSlotPos, B);
        if LArgs <> '' then
        begin
          LD := Default(TStreamDelta);
          LD.Kind := sdkToolCallDelta;
          LD.ToolIndex := LIdx;
          LD.ArgumentsDelta := LArgs;
          B.Add(LD);
        end;
      end
      else if LArgs <> '' then
        FPool.AppendArgs(LSlotPos, LArgs);
    end
    else if LArgs <> '' then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkToolCallDelta;
      LD.ToolIndex := LIdx;
      LD.ArgumentsDelta := LArgs;
      B.Add(LD);
    end;
  end;
end;

procedure TOpenAIWireDecoder.DecodeEvent(const AEvent: TWireSSEEvent;
  out ADeltas: TStreamDeltaArray);
var
  Doc: IJsonDocument;
  Root, LChoices, LC0, LDv, LU, LF: TJsonValue;
  LD: TStreamDelta;
  LId, LModel, LRv, LUnmapped, LCapture: string;
  B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then
    raise EAgentMisuse.Create('openai decoder reused after Finalize');
  if AEvent.Event = 'ping' then
    Exit;
  if AEvent.Data = '[DONE]' then
  begin
    FDone := True;
    Exit;
  end;
  if FDone then
    Exit;
  B.Init;

  Doc := JsonParse(AEvent.Data);
  if Doc.HasError or (not Doc.Root.IsObject) then
    ProtocolError(AEvent.Data, 'stream chunk must be a JSON object');
  Root := Doc.Root;

  if not FSawEnvelope then
  begin
    LId := '';
    LModel := '';
    if Root.Get('id').IsStr then
      LId := Root.Get('id').AsStr.ToString;
    if Root.Get('model').IsStr then
      LModel := Root.Get('model').AsStr.ToString;
    if (LId <> '') or (LModel <> '') then
    begin
      LD := Default(TStreamDelta);
      LD.Kind := sdkEnvelope;
      LD.MessageId := LId;
      LD.Model := LModel;
      B.Add(LD);
      FSawEnvelope := True;
    end;
  end;

  LChoices := Root.Get('choices');
  if LChoices.IsValid and (not LChoices.IsNull) and (not LChoices.IsArray) then
    ProtocolError(AEvent.Data, 'choices must be an array');
  if LChoices.IsArray then
  begin
    if LChoices.ArrayLen > 1 then
      WarnLog(FLog, 'openai: dropping ' +
        nextpas.core.text.conv.IntToStr(Int64(LChoices.ArrayLen) - 1) +
        ' extra choice(s) beyond index 0 (Q-O7)');
    if LChoices.ArrayLen > 0 then
    begin
      LC0 := LChoices.ArrayGet(0);

      LDv := LC0.Get('delta');
      if LDv.IsObject then
      begin
        if LDv.Get('content').IsStr then
        begin
          LId := LDv.Get('content').AsStr.ToString;
          if LId <> '' then
          begin
            LD := Default(TStreamDelta);
            LD.Kind := sdkTextDelta;
            LD.TextDelta := LId;
            B.Add(LD);
          end;
        end;
        if LDv.Get('reasoning_content').IsStr or
          LDv.Get('reasoning').IsStr then
        begin
          if LDv.Get('reasoning_content').IsStr then
            LId := LDv.Get('reasoning_content').AsStr.ToString
          else
            LId := LDv.Get('reasoning').AsStr.ToString;
          if LId <> '' then
          begin
            LD := Default(TStreamDelta);
            LD.Kind := sdkThinkingDelta;
            LD.TextDelta := LId;
            B.Add(LD);
          end;
        end;
        if LDv.Get('tool_calls').IsValid and
          (not LDv.Get('tool_calls').IsNull) and
          (not LDv.Get('tool_calls').IsArray) then
          ProtocolError(AEvent.Data, 'delta.tool_calls must be an array');
        if LDv.Get('tool_calls').IsArray then
          HandleToolCalls(LDv.Get('tool_calls'), AEvent.Data, B);
      end
      else if LDv.IsValid and (not LDv.IsNull) then
        ProtocolError(AEvent.Data, 'choices[0].delta must be an object');

      LF := LC0.Get('finish_reason');
      if LF.IsStr then
      begin
        LRv := LF.AsStr.ToString;
        if LRv <> '' then
        begin
          LD := Default(TStreamDelta);
          LD.Kind := sdkFinish;
          LD.FinishReason := MapFinishReason(LRv, LUnmapped);
          if (LD.FinishReason = frStop) and (FPool.Count > 0) then
            LD.FinishReason := frToolCalls;
          if LUnmapped <> '' then
          begin
            WarnLog(FLog, 'openai: unmapped finish_reason "' + LUnmapped +
              '" -> frNone');
            LD.UnmappedJson := AgentUnmappedJson(CAGENT_UNMAPPED_FINISH, LUnmapped);
          end;
          B.Add(LD);
        end;
      end
      else if LF.IsValid and (not LF.IsNull) then
        ProtocolError(AEvent.Data,
          'finish_reason must be a string or null');
    end;
  end;

  LU := Root.Get('usage');
  if LU.IsObject then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkUsage;
    FillUsage(LU, LD.Usage);
    B.Add(LD);
  end;

  LCapture := CaptureExtraJson(Root, CKNOWN_ROOT, CMaxExtraKeys, FLog);
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

procedure TOpenAIWireDecoder.Finalize(out ADeltas: TStreamDeltaArray);
var
  B: TAgentDeltaBuilder;
begin
  ADeltas := nil;
  if FFinalized then
    Exit;
  FFinalized := True;
  B.Init;
  FPool.FlushUnannouncedBuilder(FLog, 'openai', B);
  ADeltas := B.Take;
  if FPendingUnmapped <> '' then
  begin
    WarnLog(FLog,
      'openai: dropping trailing unmapped chunk keys without a carrier');
    FPendingUnmapped := '';
  end;
end;

function NewOpenAIWireDecoder(const ALog: ILogger): IAgentWireDecoder;
begin
  Result := TOpenAIWireDecoder.Create(ALog);
end;

end.
