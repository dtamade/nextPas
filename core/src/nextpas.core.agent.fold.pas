{**
 * nextpas.core.agent.fold - 唯一权威的 delta→消息 折叠实现。
 *
 * 契约权威：core/docs/agent/API.md §4。loop、IAgentCompletion.GetMessage、
 * 测试三方共用本单元，禁止任何地方重写折叠逻辑（DESIGN D1）。
 *}

unit nextpas.core.agent.fold;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.builder,
  nextpas.core.agent.base.types,
  nextpas.core.agent.base,
  nextpas.core.agent.errors;

type
  { 增量累积器；Create 后连续 FoldDelta，Finish 收口 }
  TAssistantBuild = class
  private type
    TBuildTextKind = (btkNone, btkText, btkThinking);
    TToolSlot = record
      ToolIndex: Integer;
      PartPos: Integer;              { FParts 中占位部件下标 }
      Args: IStringBuilder;
      Open: Boolean;
    end;
    TToolSlotArray = array of TToolSlot;
  private
    FParts: TPartArray;              { 到达序；tool 占位在 Start 时插入 }
    FPartsCap: Integer;
    FPartsLen: Integer;
    FSlots: TToolSlotArray;
    FSlotsCap: Integer;
    FSlotsLen: Integer;
    FReg: TAgentSlotRegistry;     { 统一注册表：O(1) 直映 + 稀疏回退，256 阈值（base 单一真源）}
    FCurKind: TBuildTextKind;
    FCurBuilder: IStringBuilder;
    FCurSignature: string;
    FMessageId: string;
    FModel: string;
    FFinishReason: TFinishReason;
    FUsage: TTokenUsage;
    FUnmapped: array of TJsonText;   { delta 旁路捕获（未映射枚举等），收口并入 }
    procedure ProtocolError(const AMsg: string);
    function FindSlot(AToolIndex: Integer): Integer;
    procedure RegisterSlot(AToolIndex: Integer);
    procedure EnsureCurrentKind(AKind: TBuildTextKind);
    procedure FlushCurrentPart;
    procedure CloseAllSlots;
  public
    constructor Create; reintroduce;
    procedure FoldDelta(const ADelta: TStreamDelta);
    function Finish: TMessage;
    function PartialText: string;
  end;

{ 一次性折叠：deltas 数组 → 消息。usage 随 AMsg.Usage 携带。
  空输入 → 空 mrAssistant 消息（合法结果）；违例序列抛 EAgentError[aecProtocol] }
procedure FoldDeltas(const ADeltas: array of TStreamDelta; out AMsg: TMessage);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv;

constructor TAssistantBuild.Create;
begin
  inherited Create;
  FReg.Init;
  { usage 全未知起步：未收到 sdkUsage 的流不得被读成全零用量 }
  AgentInitUsageUnknown(FUsage);
end;

procedure TAssistantBuild.ProtocolError(const AMsg: string);
begin
  raise EAgentError.CreateLocal(aecProtocol, AMsg);
end;

function TAssistantBuild.FindSlot(AToolIndex: Integer): Integer;
var
  LPos: Integer;
begin
  if FReg.TryFind(AToolIndex, LPos) then
    Exit(LPos);
  Result := -1;
end;

procedure TAssistantBuild.RegisterSlot(AToolIndex: Integer);
var
  LDummy: Integer;
begin
  // 统一经 Registry：稀疏大索引自动走线性回退，≤256 走直映；失败静默由上层计数守卫处理
  FReg.Register(AToolIndex, LDummy);
end;

procedure TAssistantBuild.EnsureCurrentKind(AKind: TBuildTextKind);
begin
  if FCurKind = AKind then
    Exit;
  FlushCurrentPart;
  FCurKind := AKind;
  FCurBuilder := MakeStringBuilder;
  FCurSignature := '';
end;

procedure TAssistantBuild.FlushCurrentPart;
var
  LText: string;
  LPos: Integer;
begin
  if FCurKind = btkNone then
    Exit;
  LText := FCurBuilder.ToString;
  { 全空段不产出：无内容且无签名的思考/正文块没有消费语义 }
  if (LText <> '') or (FCurSignature <> '') then
  begin
    if FPartsLen >= FPartsCap then
    begin
      // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1)
      FPartsCap := BytesGrowCapacityInt(FPartsCap, FPartsLen + 1);
      SetLength(FParts, FPartsCap);
    end;
    LPos := FPartsLen;
    Inc(FPartsLen);
    if FCurKind = btkText then
      FParts[LPos].Kind := pkText
    else
      FParts[LPos].Kind := pkThinking;
    FParts[LPos].Text := LText;
    FParts[LPos].Signature := FCurSignature;
  end;
  FCurKind := btkNone;
  FCurBuilder := nil;
  FCurSignature := '';
end;

procedure TAssistantBuild.CloseAllSlots;
var
  I: Integer;
begin
  for I := 0 to FSlotsLen - 1 do
    FSlots[I].Open := False;
end;

procedure TAssistantBuild.FoldDelta(const ADelta: TStreamDelta);
var
  LSlot: Integer;
  LPos: Integer;
begin
  case ADelta.Kind of
    sdkEnvelope:
      begin
        { 信封事件可重入，最后一次生效；字段允许分次到达 }
        if ADelta.MessageId <> '' then
          FMessageId := ADelta.MessageId;
        if ADelta.Model <> '' then
          FModel := ADelta.Model;
      end;
    sdkTextDelta:
      begin
        EnsureCurrentKind(btkText);
        FCurBuilder.AppendStr(ADelta.TextDelta);
      end;
    sdkThinkingDelta:
      begin
        EnsureCurrentKind(btkThinking);
        FCurBuilder.AppendStr(ADelta.TextDelta);
        if ADelta.Signature <> '' then
          FCurSignature := FCurSignature + ADelta.Signature;
      end;
    sdkToolCallStart:
      begin
        if ADelta.ToolIndex < 0 then
          ProtocolError('tool call start missing index');
        if FindSlot(ADelta.ToolIndex) >= 0 then
          ProtocolError('duplicate tool call start index '
            + nextpas.core.text.conv.IntToStr(ADelta.ToolIndex));
        if FReg.Count > CAgentMaxSlotMap then
          ProtocolError('tool slot count exceeds '
            + nextpas.core.text.conv.IntToStr(CAgentMaxSlotMap));
        FlushCurrentPart;
        if FPartsLen >= FPartsCap then
        begin
          // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1)
          FPartsCap := BytesGrowCapacityInt(FPartsCap, FPartsLen + 1);
          SetLength(FParts, FPartsCap);
        end;
        LPos := FPartsLen;
        Inc(FPartsLen);
        FParts[LPos].Kind := pkToolCall;
        FParts[LPos].ToolCallId := ADelta.ToolCallId;
        FParts[LPos].ToolName := ADelta.ToolName;
        if FSlotsLen >= FSlotsCap then
        begin
          // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1)
          FSlotsCap := BytesGrowCapacityInt(FSlotsCap, FSlotsLen + 1);
          SetLength(FSlots, FSlotsCap);
        end;
        LSlot := FSlotsLen;
        Inc(FSlotsLen);
        FSlots[LSlot].ToolIndex := ADelta.ToolIndex;
        FSlots[LSlot].PartPos := LPos;
        FSlots[LSlot].Args := MakeStringBuilder(CAgentToolArgsInitialCap);
        FSlots[LSlot].Open := True;
        RegisterSlot(ADelta.ToolIndex);
      end;
    sdkToolCallDelta:
      begin
        if ADelta.ToolIndex < 0 then
          ProtocolError('tool call delta missing index');
        LSlot := FindSlot(ADelta.ToolIndex);
        if LSlot < 0 then
          ProtocolError('tool call delta before start (index '
            + nextpas.core.text.conv.IntToStr(ADelta.ToolIndex) + ')');
        if not FSlots[LSlot].Open then
          ProtocolError('tool call delta after end (index '
            + nextpas.core.text.conv.IntToStr(ADelta.ToolIndex) + ')');
        FSlots[LSlot].Args.AppendStr(ADelta.ArgumentsDelta);
      end;
    sdkToolCallEnd:
      begin
        if ADelta.ToolIndex < 0 then
          ProtocolError('tool call end missing index');
        LSlot := FindSlot(ADelta.ToolIndex);
        if LSlot < 0 then
          ProtocolError('tool call end for unknown slot (index '
            + nextpas.core.text.conv.IntToStr(ADelta.ToolIndex) + ')');
        { End 是建议性事件：重复 End 宽容忽略（幂等）}
        FSlots[LSlot].Open := False;
      end;
    sdkFinish:
      begin
        { 隐式封全部未闭槽——缺 End 不是违例（WIRE-MAPPINGS Q-O5）}
        CloseAllSlots;
        FFinishReason := ADelta.FinishReason;
      end;
    sdkUsage:
      FUsage := ADelta.Usage;
    sdkError:
      { 不进入消息：错误缓存是 IAgentCompletion 实现的职责（ERRORS §6）}
      ;
  end;
  if ADelta.UnmappedJson <> '' then
  begin
    SetLength(FUnmapped, Length(FUnmapped) + 1);
    FUnmapped[High(FUnmapped)] := ADelta.UnmappedJson;
  end;
end;

function TAssistantBuild.Finish: TMessage;
var
  I: Integer;
begin
  FlushCurrentPart;
  CloseAllSlots;
  for I := 0 to FSlotsLen - 1 do
    FParts[FSlots[I].PartPos].ArgumentsJson := FSlots[I].Args.ToString;
  SetLength(FParts, FPartsLen);
  FPartsCap := FPartsLen;
  SetLength(FSlots, FSlotsLen);
  FSlotsCap := FSlotsLen;
  Result := Default(TMessage);
  Result.Id := FMessageId;
  Result.Role := mrAssistant;
  Result.Parts := Copy(FParts, 0, Length(FParts));
  Result.Model := FModel;
  Result.FinishReason := FFinishReason;
  Result.Usage := FUsage;
  if Length(FUnmapped) > 0 then
    Result.ExtraJson := MergeExtraJson(FUnmapped);
end;

function TAssistantBuild.PartialText: string;
var
  I, LFirst, LCount, LTotal, LPos, LLen, LCursLen: Integer;
  LCurs: string;
  LHasCur: Boolean;
begin
  LCount := 0;
  LFirst := -1;
  LTotal := 0;
  for I := 0 to FPartsLen - 1 do
    if FParts[I].Kind = pkText then
    begin
      if LFirst = -1 then
        LFirst := I;
      Inc(LCount);
      Inc(LTotal, Length(FParts[I].Text));
    end;
  LHasCur := (FCurKind = btkText) and (FCurBuilder <> nil) and (FCurBuilder.Len > 0);
  if LHasCur then
  begin
    LCursLen := FCurBuilder.Len;
    Inc(LTotal, LCursLen);
    Inc(LCount);
  end
  else
    LCursLen := 0;
  if LCount = 0 then
    Exit('');
  if LCount = 1 then
  begin
    if LHasCur then
      Exit(FCurBuilder.ToString);
    Exit(FParts[LFirst].Text);
  end;
  SetLength(Result, LTotal);
  LPos := 1;
  for I := 0 to FPartsLen - 1 do
    if FParts[I].Kind = pkText then
    begin
      LLen := Length(FParts[I].Text);
      if LLen > 0 then
      begin
        // perf: single source via bytes.ops.BytesCopy inline zero-copy Move (INV-5)
        BytesCopy(@Result[LPos], @FParts[I].Text[1], SizeUInt(LLen));
        Inc(LPos, LLen);
      end;
    end;
  if LHasCur then
  begin
    LCurs := FCurBuilder.ToString;
    LLen := Length(LCurs);
    if LLen > 0 then
      // perf: single source via bytes.ops.BytesCopy inline zero-copy Move (INV-5)
      BytesCopy(@Result[LPos], @LCurs[1], SizeUInt(LLen));
  end;
end;

procedure FoldDeltas(const ADeltas: array of TStreamDelta; out AMsg: TMessage);
var
  B: TAssistantBuild;
  I: Integer;
begin
  B := TAssistantBuild.Create;
  try
    for I := 0 to High(ADeltas) do
      B.FoldDelta(ADeltas[I]);
    AMsg := B.Finish;
  finally
    B.Free;
  end;
end;

end.
