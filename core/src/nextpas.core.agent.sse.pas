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
  nextpas.core.agent.base,
  nextpas.core.agent.errors;

const
  { SECURITY §3：防御恶意"兼容网关"的流式上限 }
  CSSEMaxLineBytes     = 1 * 1024 * 1024;   { 单行 1 MiB，超出抛 aecProtocol }
  CSSEMaxEventDataByte = 8 * 1024 * 1024;   { 单事件 data 总量 8 MiB，同上 }

type
  { Feed 式解析：Feed 原始字节 → PopEvent 取已完成帧 → Finish 收口 }
  TSSEParser = class
  private
    FBuf: AnsiString;                { 原始字节缓冲；未完成行恒起于队首 }
    FLineStart: SizeInt;             { 未完成行的起始偏移（0-based）}
    FBOMCheck: Boolean;              { 首部 UTF-8 BOM 待判定 }
    FFinished: Boolean;
    FEvents: array of TWireSSEEvent;
    FEventHead: SizeInt;             { 已消费事件数 }
    FEventName: string;
    FData: string;                   { 多行 data 以 #10 连接累积 }
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
      if Length(FData) + Length(LValue) + 1 > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
      FData := FData + #10 + LValue;
    end
    else
    begin
      if Length(LValue) > CSSEMaxEventDataByte then
        ProtocolError('sse event data exceeds '
          + IntToStr(CSSEMaxEventDataByte) + ' bytes limit');
      FData := LValue;
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
  LN: SizeInt;
begin
  if FHasData then
  begin
    LN := Length(FEvents);
    SetLength(FEvents, LN + 1);
    FEvents[LN].Event := FEventName;
    FEvents[LN].Data := FData;
  end;
  FEventName := '';
  FData := '';
  FHasData := False;
end;

procedure TSSEParser.Feed(const ASpan: TByteSpan);
var
  I: SizeInt;
  LLineEnd: SizeInt;
  LTmp: string;
begin
  if FFinished then
    raise EAgentMisuse.Create('Feed after Finish');
  if ASpan.Len = 0 then
    Exit;

  SetLength(FBuf, Length(FBuf) + SizeInt(ASpan.Len));
  Move(ASpan.Data^, FBuf[Length(FBuf) - SizeInt(ASpan.Len) + 1], ASpan.Len);

  { 首部 UTF-8 BOM 跳过；不足 3 字节且是 BOM 前缀时留待下一 Feed 判定 }
  if FBOMCheck then
  begin
    if Length(FBuf) >= 3 then
    begin
      if (FBuf[1] = #$EF) and (FBuf[2] = #$BB) and (FBuf[3] = #$BF) then
        Delete(FBuf, 1, 3);
      FBOMCheck := False;
    end
    else if IsBOMPrefix(FBuf) then
      Exit
    else
      FBOMCheck := False;
  end;

  I := FLineStart;
  while I < Length(FBuf) do
  begin
    if FBuf[I + 1] = #10 then
    begin
      { LF 终止；去尾部 CR（CRLF 形态）}
      LLineEnd := I;
      if (LLineEnd > FLineStart) and (FBuf[LLineEnd] = #13) then
        Dec(LLineEnd);
      LTmp := Copy(FBuf, FLineStart + 1, LLineEnd - FLineStart);
      FLineStart := I + 1;
      ProcessLine(LTmp);
      Inc(I);
    end
    else if (FBuf[I + 1] = #13) and (I + 1 < Length(FBuf))
      and (FBuf[I + 2] = #10) then
    begin
      { CRLF 终止 }
      LTmp := Copy(FBuf, FLineStart + 1, I - FLineStart);
      FLineStart := I + 2;
      ProcessLine(LTmp);
      Inc(I, 2);
    end
    else
      Inc(I);
  end;

  { 未完成行限长检查（SECURITY §3）：缓冲内已无终止符，剩余即单行 }
  if (Length(FBuf) - FLineStart) > CSSEMaxLineBytes then
  begin
    FLineStart := Length(FBuf);
    ProtocolError('sse line exceeds '
      + IntToStr(CSSEMaxLineBytes) + ' bytes limit');
  end;

  { 已消费前缀压实，防长流内存无界增长 }
  if FLineStart > 0 then
  begin
    if FLineStart < Length(FBuf) then
      Move(FBuf[FLineStart + 1], FBuf[1], Length(FBuf) - FLineStart);
    SetLength(FBuf, Length(FBuf) - FLineStart);
    FLineStart := 0;
  end;
end;

function TSSEParser.PopEvent(out AEvent: TWireSSEEvent): Boolean;
begin
  if FEventHead < Length(FEvents) then
  begin
    AEvent := FEvents[FEventHead];
    Inc(FEventHead);
    if FEventHead = Length(FEvents) then
    begin
      FEvents := nil;
      FEventHead := 0;
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
