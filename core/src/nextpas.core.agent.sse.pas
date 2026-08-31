{**
 * nextpas.core.agent.sse - feed 式增量 SSE 解析器。
 *
 * 契约权威：core/docs/agent/WIRE-MAPPINGS §0（SSE 帧文法/多字节边界）、
 * SECURITY §3（DoS 上限）。内部单元；行为稳定后作为反哺提案申请晋升
 * http.sse（需总控批准的跨模块 slice）。
 *
 * 按字节缓冲工作：UTF-8 序列可跨 Feed() 断裂，帧未完整前不做字符解码。
 * 行终止符只认 LF 与 CRLF；孤立 CR 视为普通数据字节。
 *}

unit nextpas.core.agent.sse;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes,
  nextpas.core.bytes.ops,
  nextpas.core.text,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.agent.base,
  nextpas.core.agent.errors;

const
  { SECURITY §3：防御恶意"兼容网关"的流式上限 }
  CSSEMaxLineBytes     = 1 * 1024 * 1024;   { 单行 1 MiB，超出抛 aecProtocol }
  CSSEMaxEventDataByte = nextpas.core.agent.base.CAgentMaxSuccessBodyBytes; { alias：单事件 data 8 MiB 单一真源 }
  CSSEDataBufInitialCap = 256;             { data 累积 builder 初始容量：典型单行 <256B，首帧零扩容 }

type
  { Feed 式解析：Feed 原始字节 → PopEvent 取已完成帧 → Finish 收口 }
  TSSEParser = class
  private
    FBuf: TBytes;                    { 原始字节缓冲；未完成行恒起于队首，复用 bytes.ops 单源 }
    FLineStart: SizeInt;             { 未完成行的起始偏移（0-based）}
    FBOMCheck: Boolean;              { 首部 UTF-8 BOM 待判定 }
    FFinished: Boolean;
    FDead: Boolean;
    FEvents: array of TWireSSEEvent;
    FEventHead: SizeInt;             { 已消费事件数 }
    FEventCount: SizeInt;            { 已入队事件总数（tail）；容量=Length(FEvents) 几何增长 Cap 8→*2 }
    FEventName: string;
    FDataBuf: IStringBuilder;        { 多行 data 以 #10 连接累积（摊还 O(1) 追加）}
    FHasData: Boolean;
    procedure ProcessLine(const ALine: string);
    procedure DispatchFrame;
    procedure ProtocolError(const AMsg: string);
  public
    constructor Create; reintroduce;
    procedure Feed(const ASpan: TByteSpan);
    function PopEvent(out AEvent: TWireSSEEvent): Boolean;
    { EOF 收口：挂起的未终止帧作为最后事件产出（WIRE-MAPPINGS Q-O4 宽容）；
      之后本实例不可再 Feed。幂等。}
    procedure Finish;
  end;

implementation

{ TBytes 版 BOM 前缀判定，inline 单源（复用 bytes.ops 视图语义）}
function IsBOMPrefixBytes(const ABuf: TBytes): Boolean; inline;
begin
  Result := (Length(ABuf) >= 1) and (ABuf[0] = $EF)
    and ((Length(ABuf) < 2) or (ABuf[1] = $BB))
    and ((Length(ABuf) < 3) or (ABuf[2] = $BF));
end;

constructor TSSEParser.Create;
begin
  inherited Create;
  FBOMCheck := True;
end;

procedure TSSEParser.ProtocolError(const AMsg: string);
begin
  FBuf := nil;
  FLineStart := 0;
  FDead := True;
  FFinished := True;
  if FDataBuf <> nil then
    FDataBuf.Clear;
  FHasData := False;
  FEventName := '';
  raise EAgentError.CreateLocal(aecProtocol, AMsg);
end;

procedure TSSEParser.ProcessLine(const ALine: string);
var
  LColon: SizeInt;
  LField, LValue: string;
begin
  if Length(ALine) > CSSEMaxLineBytes then
    ProtocolError('sse line exceeds '
      + nextpas.core.text.conv.IntToStr(CSSEMaxLineBytes) + ' bytes limit');
  if ALine = '' then
  begin
    DispatchFrame;
    Exit;
  end;
  if ALine[1] = ':' then
    Exit;                            { 注释/keep-alive 行 }
  LColon := nextpas.core.text.TextIndexOf(ALine, ':');
  if LColon < 0 then
    Exit;                            { 无冒号行按 SSE 规范忽略 }
  LField := nextpas.core.text.TextSlice(ALine, 0, SizeUInt(LColon));
  LValue := nextpas.core.text.TextSlice(ALine, SizeUInt(LColon) + 1, MaxInt);
  if (LValue <> '') and (LValue[1] = ' ') then
    LValue := nextpas.core.text.TextSlice(LValue, 1, MaxInt);   { 规范：冒号后单个空格剥离 }
  if LField = 'data' then
  begin
    if FHasData then
    begin
      if FDataBuf.Len + SizeUInt(Length(LValue)) + 1 > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + nextpas.core.text.conv.IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
      FDataBuf.AppendStr(#10);
      FDataBuf.AppendStr(LValue);
    end
    else
    begin
      if Length(LValue) > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + nextpas.core.text.conv.IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
      if FDataBuf = nil then
        FDataBuf := MakeStringBuilder(CSSEDataBufInitialCap)
      else
        FDataBuf.Clear;
      FDataBuf.AppendStr(LValue);
      FHasData := True;
    end;
  end
  else if LField = 'event' then
    FEventName := LValue
  else if (LField = 'id') or (LField = 'retry') then
    ;                                { v1 忽略（WIRE-MAPPINGS §0 帧文法）}
end;

procedure TSSEParser.DispatchFrame;
var
  LCap, LNeed: SizeInt;
begin
  if FHasData then
  begin
    LCap := Length(FEvents);
    LNeed := FEventCount + 1;
    if LNeed > LCap then
    begin
      if LCap = 0 then
        LCap := 8
      else
        while LCap < LNeed do
          LCap := LCap * 2;
      SetLength(FEvents, LCap);
    end;
    FEvents[FEventCount].Event := FEventName;
    FEvents[FEventCount].Data := FDataBuf.ToString;
    Inc(FEventCount);
    FDataBuf.Clear; // 复用 builder，避免每事件分配
  end;
  FEventName := '';
  FHasData := False;
end;

procedure TSSEParser.Feed(const ASpan: TByteSpan);
var
  I: SizeInt;
  LLineEnd: SizeInt;
  LTmp: string;
  LFull: TByteSpan;
begin
  if FFinished then
    raise EAgentMisuse.Create('Feed after Finish');
  if ASpan.Len = 0 then
    Exit;

  { 单源追加：复用 bytes.ops BytesAppend，不手工 SetLength+Move }
  BytesAppend(FBuf, ASpan.Data, ASpan.Len);

  { 首部 UTF-8 BOM 跳过；不足 3 字节且是 BOM 前缀时留待下一 Feed 判定（零拷贝探测） }
  if FBOMCheck then
  begin
    if Length(FBuf) >= 3 then
    begin
      if (FBuf[0] = $EF) and (FBuf[1] = $BB) and (FBuf[2] = $BF) then
        { 单源切片：复用 SpanCopySlice 去 BOM，零手工 Delete }
        FBuf := SpanCopySlice(TByteSpan.FromBytes(FBuf), 3, SizeUInt(Length(FBuf) - 3));
      FBOMCheck := False;
    end
    else if IsBOMPrefixBytes(FBuf) then
      Exit
    else
      FBOMCheck := False;
  end;

  { 主循环：SpanIndexOf SIMD 跳扫找 LF（0x0A），替代逐字节扫描；
    行终止只可能是 LF 或 CRLF（纯 CR 不终止），故 LF 即行边界 }
  LFull := TByteSpan.FromBytes(FBuf);
  while FLineStart < Length(FBuf) do
  begin
    I := nextpas.core.bytes.ops.SpanIndexOf(
      LFull.Slice(SizeUInt(FLineStart), SizeUInt(Length(FBuf) - FLineStart)), 10);
    if I < 0 then
      Break;
    Inc(I, FLineStart);
    LLineEnd := I;
    if (LLineEnd > FLineStart) and (FBuf[LLineEnd - 1] = 13) then
      Dec(LLineEnd);            { CRLF 形态：行尾回退 CR }
    LTmp := nextpas.core.bytes.BytesSliceToString(FBuf, SizeUInt(FLineStart), SizeUInt(LLineEnd - FLineStart));
    FLineStart := I + 1;
    ProcessLine(LTmp);
  end;

  { 未完成行限长检查（SECURITY §3）：缓冲内已无终止符，剩余即单行 }
  if (Length(FBuf) - FLineStart) > CSSEMaxLineBytes then
  begin
    FLineStart := Length(FBuf);
    ProtocolError('sse line exceeds '
      + nextpas.core.text.conv.IntToStr(CSSEMaxLineBytes) + ' bytes limit');
  end;

  { 已消费前缀压实，防长流内存无界增长：单源 SpanCopySlice 复用 bytes.ops }
  if FLineStart > 0 then
  begin
    if FLineStart < Length(FBuf) then
      FBuf := SpanCopySlice(TByteSpan.FromBytes(FBuf), SizeUInt(FLineStart), SizeUInt(Length(FBuf) - FLineStart))
    else
      FBuf := nil;
    FLineStart := 0;
  end;
end;

function TSSEParser.PopEvent(out AEvent: TWireSSEEvent): Boolean;
begin
  if FEventHead < FEventCount then
  begin
    AEvent := FEvents[FEventHead];
    FEvents[FEventHead] := Default(TWireSSEEvent); // 释放已消费槽位，避免滞留
    Inc(FEventHead);
    if FEventHead = FEventCount then
    begin
      // 全部消费完毕，复位 head/count 保留容量零分配复用（几何预留）
      FEventHead := 0;
      FEventCount := 0;
    end;
    Result := True;
  end
  else
    Result := False;
end;

procedure TSSEParser.Finish;
var
  LTmp: string;
begin
  if FFinished then
    Exit;
  FFinished := True;
  { 挂起的未终止行按最后一行处理（Q-O4 宽容收口）}
  if FLineStart < Length(FBuf) then
  begin
    LTmp := nextpas.core.bytes.BytesSliceToString(FBuf, SizeUInt(FLineStart), SizeUInt(Length(FBuf) - FLineStart));
    FLineStart := Length(FBuf);
    ProcessLine(LTmp);
  end;
  FBuf := nil;
  DispatchFrame;
end;

end.
