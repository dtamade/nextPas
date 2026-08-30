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
  nextpas.core.text.builder,
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
    FBuf: AnsiString;                { 原始字节缓冲；未完成行恒起于队首 }
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

{ S 是否为 UTF-8 BOM 的前缀（长度可不足 3）}
function IsBOMPrefix(const S: AnsiString): Boolean;
begin
  Result := (Length(S) >= 1) and (S[1] = #$EF)
    and ((Length(S) < 2) or (S[2] = #$BB))
    and ((Length(S) < 3) or (S[3] = #$BF));
end;

constructor TSSEParser.Create;
begin
  inherited Create;
  FBOMCheck := True;
end;

procedure TSSEParser.ProtocolError(const AMsg: string);
begin
  FBuf := '';
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
      + IntToStr(CSSEMaxLineBytes) + ' bytes limit');
  if ALine = '' then
  begin
    DispatchFrame;
    Exit;
  end;
  if ALine[1] = ':' then
    Exit;                            { 注释/keep-alive 行 }
  LColon := Pos(':', ALine);
  if LColon = 0 then
    Exit;                            { 无冒号行按 SSE 规范忽略 }
  LField := Copy(ALine, 1, LColon - 1);
  LValue := Copy(ALine, LColon + 1, MaxInt);
  if (LValue <> '') and (LValue[1] = ' ') then
    Delete(LValue, 1, 1);            { 规范：冒号后单个空格剥离 }
  if LField = 'data' then
  begin
    if FHasData then
    begin
      if FDataBuf.Len + SizeUInt(Length(LValue)) + 1 > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
      FDataBuf.AppendStr(#10);
      FDataBuf.AppendStr(LValue);
    end
    else
    begin
      if Length(LValue) > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
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
  LSpanOff: SizeInt;
  LSpanRem: SizeInt;
  LFirst: SizeInt;
  LTmp: string;
  LLineStart, I: SizeInt;
  LNeed: Integer;
  LCombined: AnsiString;
  P: PByte;
  LData: PByte;
  LLen: SizeUInt;

  function SpanByte(AIdx: SizeInt): Byte; inline;
  begin
    Result := LData[AIdx];
  end;

  function MakeLineFromSpan(AStart, ABeforeLF: SizeInt): string;
  var
    LLen: Integer;
    LEnd: SizeInt;
  begin
    LLen := Integer(ABeforeLF - AStart);
    if (LLen > 0) and (SpanByte(ABeforeLF - 1) = 13) then
      Dec(LLen); // 去尾 CR
    if LLen <= 0 then
      Exit('');
    SetString(Result, PAnsiChar(LData + AStart), LLen);
  end;

begin
  if FFinished then
    raise EAgentMisuse.Create('Feed after Finish');
  if ASpan.Len = 0 then
    Exit;
  P := PByte(ASpan.Data);
  LData := P;
  LLen := ASpan.Len;

  { 首部 UTF-8 BOM 零拷贝判定：仅探测前 3 字节，避免整包搬运 }
  if FBOMCheck then
  begin
    LNeed := 0;
    LCombined := '';
    if Length(FBuf) > 0 then
      LCombined := FBuf;
    // 拼至多 3 字节用于判定
    LNeed := 3 - Length(LCombined);
    if LNeed > 0 then
    begin
      if SizeInt(ASpan.Len) < LNeed then
        LNeed := SizeInt(ASpan.Len);
      SetLength(LCombined, Length(LCombined) + LNeed);
      if LNeed > 0 then
        Move(P^, LCombined[Length(FBuf) + 1], LNeed);
    end;
    if Length(LCombined) < 3 then
    begin
      if IsBOMPrefix(LCombined) then
      begin
        // 仍为 BOM 前缀，缓存等待更多字节
        SetLength(FBuf, Length(FBuf) + SizeInt(ASpan.Len));
        if SizeInt(ASpan.Len) > 0 then
          Move(P^, FBuf[Length(FBuf) - SizeInt(ASpan.Len) + 1], ASpan.Len);
        Exit;
      end
      else
        FBOMCheck := False;
        // 非 BOM 前缀，继续处理（FBuf 仍为之前的尾，保留）
    end
    else
    begin
      if (LCombined[1] = #$EF) and (LCombined[2] = #$BB) and (LCombined[3] = #$BF) then
      begin
        // 去除 BOM：FBuf 中的前缀部分清掉，Span 偏移前移
        if Length(FBuf) >= 3 then
          Delete(FBuf, 1, 3)
        else
        begin
          LSpanOff := 3 - Length(FBuf);
          FBuf := '';
          // 调整 Span 视图，避免搬运整包，仅偏移指针与长度
          LData := LData + LSpanOff;
          LLen := LLen - SizeUInt(LSpanOff);
          P := LData;
        end;
        if Length(FBuf) = 3 then // 上面 Delete 后可能剩 0，但 LCombined 已处理
          ;
      end;
      FBOMCheck := False;
    end;
    if Length(FBuf) > 0 then
    begin
      // BOM 判定阶段可能已将 ASpan 小段拷入 FBuf 用于前缀探测（仅 <3 字节路径），需避免重复处理
      // 若 FBOMCheck 已完成且 FBuf 仍含 <3 字节的探测残留（非 BOM 前缀情况），保留为行尾继续处理
    end;
  end;

  // 若仍有未完成行尾（FBuf），先尝试与当前 Span 首段拼出首行
  if Length(FBuf) > 0 then
  begin
    // 寻找 Span 内首个 LF
    LFirst := -1;
    for I := 0 to SizeInt(LLen) - 1 do
      if LData[I] = 10 then
      begin
        LFirst := I;
        Break;
      end;
    if LFirst < 0 then
    begin
      // 无换行，整包并入尾
      if SizeInt(Length(FBuf) + LLen) > CSSEMaxLineBytes then
      begin
        FBuf := '';
        FLineStart := 0;
        FDead := True;
        FFinished := True;
        ProtocolError('sse line exceeds ' + IntToStr(CSSEMaxLineBytes) + ' bytes limit');
      end;
      SetLength(FBuf, Length(FBuf) + SizeInt(LLen));
      if LLen > 0 then
        Move(LData^, FBuf[Length(FBuf) - SizeInt(LLen) + 1], LLen);
      Exit;
    end;
    // 首行 = FBuf + Span[0 .. LFirst-1]（去尾 CR）
    LTmp := FBuf;
    if LFirst > 0 then
    begin
      SetLength(LTmp, Length(LTmp) + LFirst);
      Move(LData^, LTmp[Length(FBuf) + 1], LFirst);
    end;
    if (Length(LTmp) > 0) and (LTmp[Length(LTmp)] = #13) then
      SetLength(LTmp, Length(LTmp) - 1);
    FBuf := '';
    FLineStart := 0;
    ProcessLine(LTmp);
    LSpanOff := LFirst + 1;
  end
  else
    LSpanOff := 0;

  // 剩余 Span 段按 LF 切行，零拷贝：仅在 ProcessLine 时按需拷行
  LSpanRem := SizeInt(LLen) - LSpanOff;
  if LSpanRem <= 0 then
    Exit;
  LLineStart := LSpanOff;
  I := LSpanOff;
  while I < SizeInt(LLen) do
  begin
    if LData[I] = 10 then
    begin
      LTmp := MakeLineFromSpan(LLineStart, I);
      ProcessLine(LTmp);
      LLineStart := I + 1;
    end
    else if (LData[I] = 13) and (I + 1 < SizeInt(LLen)) and (LData[I + 1] = 10) then
    begin
      // CRLF 两字节终止（兼容分支）
      LTmp := MakeLineFromSpan(LLineStart, I);
      ProcessLine(LTmp);
      LLineStart := I + 2;
      Inc(I); // 额外跳过 LF，与 while 的 Inc 合并实现 I+2 步进
    end;
    Inc(I);
  end;

  // 尾部未完成行拷入 FBuf
  if LLineStart < SizeInt(LLen) then
  begin
    LSpanRem := SizeInt(LLen) - LLineStart;
    if LSpanRem > CSSEMaxLineBytes then
    begin
      FBuf := '';
      FLineStart := 0;
      FDead := True;
      FFinished := True;
      ProtocolError('sse line exceeds ' + IntToStr(CSSEMaxLineBytes) + ' bytes limit');
    end;
    SetLength(FBuf, LSpanRem);
    Move(LData[LLineStart], FBuf[1], LSpanRem);
    FLineStart := 0;
  end
  else
  begin
    FBuf := '';
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
    LTmp := Copy(FBuf, FLineStart + 1, MaxInt);
    FLineStart := Length(FBuf);
    ProcessLine(LTmp);
  end;
  FBuf := '';
  DispatchFrame;
end;

end.
