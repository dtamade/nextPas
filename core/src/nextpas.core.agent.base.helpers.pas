{**
 * nextpas.core.agent.base.helpers - agent 纯助手函数（无状态）。
 *
 * 职责：MessageText/WireHeaderValue、UTF-8 安全截断、
 * 批次签名、行截断、用量哨兵、wire URL 拼接、system 去重拼接、槽位注册表、
 * wire 头部消毒、部件追加、增量构建器等。零 IO，逻辑重但无循环类型依赖。
 * 依赖：base.constants → base.types → 本单元。
 *}

unit nextpas.core.agent.base.helpers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.agent.base.constants,
  nextpas.core.agent.base.types;

  { ---- Global helpers (from original base, MessageText..BuildSystemText, MergeExtraJson in types) ---- }
  { 拼 pkText：顺序直连无分隔符。不变量：MessageText(fold 结果) ==
    正文 sdkTextDelta 的依序连接 }
  function MessageText(const AMsg: TMessage): string;

  { wire 头查找（大小写不敏感，首个命中返回；未命中空串）。
    RequestId 探测 / retry-after 解析 / 消费方自定义头检查共用 }
  function WireHeaderValue(const AHeaders: TWireHeaderArray;
    const AName: string): string;

  function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
  { UTF-8 安全长度（单一真源，供 Truncate 复用）：返回 ≤AMaxBytes 的合法边界 }
  function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;

  { 已知键判定：线性扫描 AKnown，命中返回 True（小表最优，零分配）}
  function AgentIsKnownKey(const AKey: string;
    const AKnown: array of string): Boolean; inline;

  { 批次签名：工具调用 name+args 有序串（防打转判定用），JsonBuilder 转义保证稳定 }
  function AgentBuildBatchSignature(const AMsg: TMessage): string;

  { 行截断：按换行计数截至 AMaxLines 行（>0 生效），超限返回截后文本 }
  function AgentTruncateLines(const S: string; AMaxLines: Integer): string;

  { 信封截断：行与字节双阈值（≤0 视为关闭），超限返回是否截断与截后文本 }
  function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer;
    out ATruncated: Boolean): string;

  { 用量哨兵初始化：五字段置 CUsageUnknown（单一事实源）}
  procedure AgentInitUsageUnknown(var AUsage: TTokenUsage); inline;

  { wire URL 拼接（WIRE-MAPPINGS §0 §1.1 §2.1 §3.1 共用）：去尾 '/'；
    已含 '/v1' 结尾只追加 ASuffix，否则追加 '/v1'+ASuffix。
    ADefault 非空时空 Base 回退；ASuffix 须以 '/' 起头 }
  function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string;

  { system 去重拼接（WIRE-MAPPINGS §0 §1.1 §2.1 共用）：顶层 System 先行 +
    历史 mrSystem 去重，以 #10#10 连接；无内容返回空串。去重保证前缀字节稳定 }
  function AgentBuildSystemText(const ASystem: string;
    const AMessages: TMessageArray): string;


type
  TAgentSlotMap = array of Integer;

  { 槽位索引注册表（fold/provider 共用单一真源，REUSE）：Map O(1) 直映 + Indexes 几何增长
    的稀疏大索引线性回退，256 阈值由 CAgentMaxSlotMap 统一把守 }
  TAgentSlotRegistry = record
  private
    FMap: TAgentSlotMap;           { ToolIndex → Pos；-1=缺席 }
    FIndexes: array of Integer;    { Pos → ToolIndex 镜像，用于线性回退校验 }
    FCount: Integer;               { 已注册槽位数（=Length(FIndexes) 逻辑长度）}
  public
    procedure Init;
    procedure Clear;               { 保留容量复用 }
    function Count: Integer; inline;
    function TryFind(AIdx: Integer; out APos: Integer): Boolean; // O(1) 命中或 >256 线性回退
    function Register(AIdx: Integer; out APos: Integer): Boolean; // 已存在返回 False+Pos，新增 True+Pos；越限不注册返回 False
    function At(APos: Integer): Integer; inline; // Pos→Idx
  end;

  { 槽位直映表扩容（fold/provider 共用，SECURITY 阈值内）：几何增长减少重分配 }
procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer);

  { wire 头部消毒（SECURITY §3，单一真源）：空名/CR-LF/单头 8KiB/总头 64KiB，provider/transport 复用 }
procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray);

  { 部件追加（openai/anthropic/responses 共享）：Kind 设位并置空其余，返回下标 }
  function AgentAddPart(var AParts: TPartArray; AKind: TPartKind): Integer;

  { 增量追加（小批量/测试路径）：精确 +1 语义；高频流式改用 TAgentDeltaBuilder 几何增长 }
  procedure AgentAppendDelta(var AArr: TStreamDeltaArray; const ADelta: TStreamDelta);

  { 未映射枚举单键 JSON 构造（wire 侧统一）：AKey/AValue 转单键 object，Str 转义由 builder 保证 }
  function AgentUnmappedJson(const AKey, AValue: string): TJsonText;

  { 增量构建器（高频解码路径）：Count/Cap 分离的几何增长，避免逐个 SetLength }
  type
    PStreamDelta = ^TStreamDelta;
    TAgentDeltaBuilder = record
    private
      FItems: TStreamDeltaArray;
      FCount: Integer;
    public
      procedure Init;
      procedure Add(const ADelta: TStreamDelta);
      procedure AddRange(const AArr: TStreamDeltaArray);
      function Take: TStreamDeltaArray; // 截断至 Count 并接管
      function Count: Integer; inline;
      procedure Clear;
      procedure MergeToFirst(const AJson: TJsonText);
      procedure MergeToLast(const AJson: TJsonText);
      function At(AIdx: Integer): PStreamDelta; inline;
      function Get(AIdx: Integer): TStreamDelta; inline;
    end;


implementation

uses
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.compare,
  nextpas.core.text.view,
  nextpas.core.agent.errors,
  nextpas.core.agent.textutil;


function MessageText(const AMsg: TMessage): string;
var
  I, LFirst, LCount, LTotal, LPos, LLen: Integer;
begin
  LCount := 0;
  LFirst := -1;
  LTotal := 0;
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
    begin
      if LFirst = -1 then
        LFirst := I;
      Inc(LCount);
      Inc(LTotal, Length(AMsg.Parts[I].Text));
    end;
  if LCount = 0 then
    Exit('');
  if LCount = 1 then
    Exit(AMsg.Parts[LFirst].Text);
  SetLength(Result, LTotal);
  LPos := 1;
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
    begin
      LLen := Length(AMsg.Parts[I].Text);
      if LLen > 0 then
      begin
        Move(AMsg.Parts[I].Text[1], Result[LPos], LLen);
        Inc(LPos, LLen);
      end;
    end;
end;


function WireHeaderValue(const AHeaders: TWireHeaderArray;
  const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
    if SameText(AHeaders[I].Name, AName) then
    begin
      Result := AHeaders[I].Value;
      Break;
    end;
end;


function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
begin
  Result := nextpas.core.agent.textutil.AgentUtf8SafeCutLen(S, AMaxBytes);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := nextpas.core.agent.textutil.AgentUtf8SafeTruncate(S, AMaxBytes);
end;


function AgentIsKnownKey(const AKey: string;
  const AKnown: array of string): Boolean; inline;
var
  I: Integer;
begin
  for I := Low(AKnown) to High(AKnown) do
    if AKnown[I] = AKey then
      Exit(True);
  Result := False;
end;


function AgentBuildBatchSignature(const AMsg: TMessage): string;
var
  K, LCount, LFirst: Integer;
  LB: IJsonBuilder;
begin
  LCount := 0;
  LFirst := -1;
  for K := 0 to High(AMsg.Parts) do
    if AMsg.Parts[K].Kind = pkToolCall then
    begin
      if LFirst = -1 then
        LFirst := K;
      Inc(LCount);
    end;
  if LCount = 0 then
    Exit('[]');
  LB := JsonBuilder;
  LB.BeginArray;
  if LCount = 1 then
  begin
    LB.Str(AMsg.Parts[LFirst].ToolName);
    LB.Str(AMsg.Parts[LFirst].ArgumentsJson);
  end
  else
    for K := 0 to High(AMsg.Parts) do
      if AMsg.Parts[K].Kind = pkToolCall then
      begin
        LB.Str(AMsg.Parts[K].ToolName);
        LB.Str(AMsg.Parts[K].ArgumentsJson);
      end;
  LB.EndArray;
  Result := LB.ToString;
end;


function AgentTruncateLines(const S: string; AMaxLines: Integer): string;
var
  LPos, LCount, LCutPos: Integer;
begin
  if S = '' then
    Exit(S);
  if AMaxLines <= 0 then
    Exit(S);
  LCount := 1;
  LCutPos := 0;
  for LPos := 1 to Length(S) do
    if S[LPos] = #10 then
    begin
      Inc(LCount);
      if LCount > AMaxLines then
      begin
        LCutPos := LPos - 1;
        Break;
      end;
    end;
  if LCutPos = 0 then
    Exit(S);
  Result := Copy(S, 1, LCutPos);
end;


function AgentTruncateEnvelope(const S: string; AMaxLines, AMaxBytes: Integer;
  out ATruncated: Boolean): string;
var
  LLineLen, LFinalLen, LPos, LCount, LCutPos: Integer;
begin
  ATruncated := False;
  if S = '' then
    Exit(S);
  if (AMaxLines <= 0) and (AMaxBytes <= 0) then
    Exit(S);
  if ((AMaxLines <= 0) or (nextpas.core.text.view.IndexOfStr(S, #10) < 0)) and
     ((AMaxBytes <= 0) or (Length(S) <= AMaxBytes)) then
    Exit(S);
  { 单遍行截断长度（零分配）：求 LLineLen }
  if AMaxLines > 0 then
  begin
    LCount := 1;
    LCutPos := 0;
    for LPos := 1 to Length(S) do
      if S[LPos] = #10 then
      begin
        Inc(LCount);
        if LCount > AMaxLines then
        begin
          LCutPos := LPos - 1;
          Break;
        end;
      end;
    if LCutPos = 0 then
      LLineLen := Length(S)
    else
    begin
      LLineLen := LCutPos;
      ATruncated := True;
    end;
  end
  else
    LLineLen := Length(S);

  { 字节截断（在行截断前缀内求安全长度，复用单一真源） }
  LFinalLen := LLineLen;
  if (AMaxBytes > 0) and (LFinalLen > AMaxBytes) then
  begin
    LFinalLen := AgentUtf8SafeCutLen(S, AMaxBytes);
    if LFinalLen > LLineLen then
      LFinalLen := LLineLen;
    ATruncated := True;
  end;

  if LFinalLen = Length(S) then
    Result := S
  else
    Result := Copy(S, 1, LFinalLen);
  ATruncated := ATruncated or (LFinalLen <> Length(S));
end;


procedure AgentInitUsageUnknown(var AUsage: TTokenUsage);
begin
  AUsage.InputTokens := CUsageUnknown;
  AUsage.OutputTokens := CUsageUnknown;
  AUsage.CacheReadInputTokens := CUsageUnknown;
  AUsage.CacheWriteInputTokens := CUsageUnknown;
  AUsage.ReasoningTokens := CUsageUnknown;
end;


function AgentJoinWireUrl(const ABaseUrl, ADefault, ASuffix: string): string;
var
  LBase: string;
begin
  LBase := ABaseUrl;
  if LBase = '' then
    LBase := ADefault;
  while (LBase <> '') and (LBase[Length(LBase)] = '/') do
    Delete(LBase, Length(LBase), 1);
  if (Length(LBase) >= 3) and (Copy(LBase, Length(LBase) - 2, 3) = '/v1') then
    Result := LBase + ASuffix
  else
    Result := LBase + '/v1' + ASuffix;
end;


procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer);
var
  LOld, LNew, I: Integer;
begin
  if (AIdx < 0) or (AIdx > CAgentMaxSlotMap) then
    Exit;
  if AIdx < Length(AMap) then
    Exit;
  LOld := Length(AMap);
  if LOld = 0 then
    LNew := 8
  else
    LNew := LOld;
  while LNew <= AIdx do
    LNew := LNew * 2;
  if LNew > CAgentMaxSlotMap + 1 then
    LNew := CAgentMaxSlotMap + 1;
  SetLength(AMap, LNew);
  for I := LOld to High(AMap) do
    AMap[I] := -1;
end;


procedure TAgentSlotRegistry.Init;
begin
  FCount := 0;
  SetLength(FMap, 0);
  SetLength(FIndexes, 0);
end;


procedure TAgentSlotRegistry.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if (FIndexes[I] >= 0) and (FIndexes[I] <= CAgentMaxSlotMap) and (FIndexes[I] < Length(FMap)) then
      FMap[FIndexes[I]] := -1;
  FCount := 0;
end;


function TAgentSlotRegistry.Count: Integer;
begin
  Result := FCount;
end;


function TAgentSlotRegistry.TryFind(AIdx: Integer; out APos: Integer): Boolean;
var
  I: Integer;
begin
  if (AIdx >= 0) and (AIdx <= CAgentMaxSlotMap) and (AIdx < Length(FMap)) then
  begin
    APos := FMap[AIdx];
    if (APos >= 0) and (APos < FCount) and (FIndexes[APos] = AIdx) then
      Exit(True);
  end;
  if AIdx > CAgentMaxSlotMap then
  begin
    for I := 0 to FCount - 1 do
      if FIndexes[I] = AIdx then
      begin
        APos := I;
        Exit(True);
      end;
  end;
  APos := -1;
  Result := False;
end;


function TAgentSlotRegistry.Register(AIdx: Integer; out APos: Integer): Boolean;
var
  LCap: Integer;
begin
  if TryFind(AIdx, APos) then
    Exit(False);
  if (AIdx < 0) then
    Exit(False);
  if FCount > CAgentMaxSlotMap then
    Exit(False); // 总数越限（provider/fold 共用阈值，SECURITY §3）
  // 索引镜像几何增长
  LCap := Length(FIndexes);
  if FCount >= LCap then
  begin
    if LCap = 0 then
      LCap := 8
    else
      LCap := LCap * 2;
    SetLength(FIndexes, LCap);
  end;
  APos := FCount;
  FIndexes[APos] := AIdx;
  Inc(FCount);
  if (AIdx >= 0) and (AIdx <= CAgentMaxSlotMap) then
  begin
    AgentSlotMapEnsureSize(FMap, AIdx);
    FMap[AIdx] := APos;
  end;
  Result := True;
end;


function TAgentSlotRegistry.At(APos: Integer): Integer;
begin
  Result := FIndexes[APos];
end;


function AgentWireHeadersContainCRLF(const S: string): Boolean; inline;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if (S[I] = #10) or (S[I] = #13) then
      Exit(True);
  Result := False;
end;


procedure AgentValidateWireHeaders(const AHeaders: TWireHeaderArray);
var
  I, LTotal: Integer;
begin
  LTotal := 0;
  for I := 0 to High(AHeaders) do
  begin
    if AHeaders[I].Name = '' then
      raise EAgentError.CreateLocal(aecProtocol, 'wire header: name is empty');
    if AgentWireHeadersContainCRLF(AHeaders[I].Name) or
       AgentWireHeadersContainCRLF(AHeaders[I].Value) then
      raise EAgentError.CreateLocal(aecProtocol, 'wire header contains CR/LF: ' + AHeaders[I].Name);
    if Length(AHeaders[I].Name) + Length(AHeaders[I].Value) > CAgentMaxWireHeaderValueBytes then
      raise EAgentError.CreateLocal(aecProtocol, 'wire header exceeds CAgentMaxWireHeaderValueBytes (8KiB) limit: ' + AHeaders[I].Name);
    Inc(LTotal, Length(AHeaders[I].Name) + Length(AHeaders[I].Value));
    if LTotal > CAgentMaxWireTotalHeaderBytes then
      raise EAgentError.CreateLocal(aecProtocol, 'wire total headers exceed CAgentMaxWireTotalHeaderBytes (64KiB) limit');
  end;
end;


function AgentAddPart(var AParts: TPartArray; AKind: TPartKind): Integer;
begin
  Result := Length(AParts);
  SetLength(AParts, Result + 1);
  AParts[Result] := Default(TPart);
  AParts[Result].Kind := AKind;
end;


procedure AgentAppendDelta(var AArr: TStreamDeltaArray; const ADelta: TStreamDelta);
var
  LOld: Integer;
begin
  LOld := Length(AArr);
  SetLength(AArr, LOld + 1);
  AArr[LOld] := ADelta;
end;


function AgentUnmappedJson(const AKey, AValue: string): TJsonText;
var
  B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
  B.Key(AKey);
  B.Str(AValue);
  B.EndObject;
  Result := B.ToString;
end;


procedure TAgentDeltaBuilder.Init;
begin
  FCount := 0;
  SetLength(FItems, 0);
end;


procedure TAgentDeltaBuilder.Add(const ADelta: TStreamDelta);
var
  LCap: Integer;
begin
  LCap := Length(FItems);
  if FCount >= LCap then
  begin
    if LCap = 0 then
      LCap := 8
    else
      LCap := LCap * 2;
    SetLength(FItems, LCap);
  end;
  FItems[FCount] := ADelta;
  Inc(FCount);
end;


procedure TAgentDeltaBuilder.AddRange(const AArr: TStreamDeltaArray);
var
  LNeed, LCap, I: Integer;
begin
  if Length(AArr) = 0 then
    Exit;
  LNeed := FCount + Length(AArr);
  LCap := Length(FItems);
  if LNeed > LCap then
  begin
    if LCap = 0 then
      LCap := 8;
    while LCap < LNeed do
      LCap := LCap * 2;
    SetLength(FItems, LCap);
  end;
  for I := 0 to High(AArr) do
  begin
    FItems[FCount] := AArr[I];
    Inc(FCount);
  end;
end;


function TAgentDeltaBuilder.Take: TStreamDeltaArray;
begin
  SetLength(FItems, FCount);
  Result := FItems;
  FItems := nil;
  FCount := 0;
end;


function TAgentDeltaBuilder.Count: Integer;
begin
  Result := FCount;
end;


procedure TAgentDeltaBuilder.Clear;
begin
  FCount := 0;
  // 保留容量以复用
end;


procedure TAgentDeltaBuilder.MergeToFirst(const AJson: TJsonText);
begin
  if (FCount > 0) and (AJson <> '') then
    FItems[0].UnmappedJson := nextpas.core.agent.base.types.MergeExtraJson([FItems[0].UnmappedJson, AJson]);
end;


procedure TAgentDeltaBuilder.MergeToLast(const AJson: TJsonText);
begin
  if (FCount > 0) and (AJson <> '') then
    FItems[FCount - 1].UnmappedJson := nextpas.core.agent.base.types.MergeExtraJson([FItems[FCount - 1].UnmappedJson, AJson]);
end;


function TAgentDeltaBuilder.At(AIdx: Integer): PStreamDelta;
begin
  Result := @FItems[AIdx];
end;


function TAgentDeltaBuilder.Get(AIdx: Integer): TStreamDelta;
begin
  Result := FItems[AIdx];
end;


function AgentBuildSystemText(const ASystem: string;
  const AMessages: TMessageArray): string;
var
  LParts: array of string;
  I, K: Integer;
  LSeen: Boolean;
  LText: string;
  SB: IStringBuilder;
begin
  SetLength(LParts, 0);
  if ASystem <> '' then
  begin
    SetLength(LParts, 1);
    LParts[0] := ASystem;
  end;
  for I := 0 to High(AMessages) do
    if AMessages[I].Role = mrSystem then
    begin
      LText := MessageText(AMessages[I]);
      if LText = '' then
        Continue;
      LSeen := False;
      for K := 0 to High(LParts) do
        if LParts[K] = LText then
        begin
          LSeen := True;
          Break;
        end;
      if not LSeen then
      begin
        SetLength(LParts, Length(LParts) + 1);
        LParts[High(LParts)] := LText;
      end;
    end;
  if Length(LParts) = 0 then
    Exit('');
  SB := MakeStringBuilder(CAgentSystemTextInitialCap);
  for I := 0 to High(LParts) do
  begin
    if I > 0 then
      SB.AppendStr(#10#10);
    SB.AppendStr(LParts[I]);
  end;
  Result := SB.ToString;
end;

end.

end.
