unit nextpas.core.sse.parser;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sse.base;

type
  TSseParser = record
  private
    FBuf: PAnsiChar;
    FBufLen: SizeUInt;
    FBufCap: SizeUInt;
    FLastEventId: string;
    FEventType: string;
    FData: string;
    FDataLen: SizeUInt;
    FRetryMs: Int32;
    FHasRetry: Boolean;
    FHasData: Boolean;
    FEvents: TSseEventArray;
    FEventCount: SizeUInt;
    FEventHead: SizeUInt;
    FError: Boolean;
    procedure ProcessLine(AStart, ALen: SizeUInt);
    procedure DispatchEvent;
    procedure GrowBuf(ANeeded: SizeUInt);
  public
    class function Create: TSseParser; static;
    procedure Free;
    procedure Feed(const AChunk: string); overload;
    procedure Feed(AData: PAnsiChar; ALen: SizeUInt); overload;
    procedure Finish;
    function TryReadEvent(out AEvent: TSseEvent): Boolean;
    function GetLastEventId: string;
    function HasError: Boolean;
    procedure Reset;
  end;

implementation

const
  SSE_MAX_BUFFER_SIZE = 1024 * 1024;
  SSE_INITIAL_BUF = 4096;

class function TSseParser.Create: TSseParser;
begin
  Result := Default(TSseParser);
  Result.FBufCap := SSE_INITIAL_BUF;
  GetMem(Result.FBuf, SSE_INITIAL_BUF);
  Result.FBufLen := 0;
  Result.FEventCount := 0;
  Result.FEventHead := 0;
  Result.FHasData := False;
  Result.FError := False;
  Result.FDataLen := 0;
end;

procedure TSseParser.Free;
begin
  if FBuf <> nil then
  begin
    FreeMem(FBuf);
    FBuf := nil;
  end;
  FBufLen := 0;
  FBufCap := 0;
  SetLength(FEvents, 0);
end;

procedure TSseParser.GrowBuf(ANeeded: SizeUInt);
var LNewCap: SizeUInt;
begin
  if ANeeded <= FBufCap then Exit;
  LNewCap := FBufCap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  ReallocMem(FBuf, LNewCap);
  FBufCap := LNewCap;
end;

procedure TSseParser.ProcessLine(AStart, ALen: SizeUInt);
var
  LColon, LI, LValStart, LValLen: SizeUInt;
  LValue: string;
  LRetry: Int32;
  LCode: Integer;
begin
  if ALen = 0 then
  begin
    DispatchEvent;
    Exit;
  end;
  if FBuf[AStart] = ':' then
    Exit;

  LColon := 0;
  for LI := 0 to ALen - 1 do
    if FBuf[AStart + LI] = ':' then
    begin
      LColon := LI;
      Break;
    end;

  if (LColon = 0) and (FBuf[AStart] <> ':') then
  begin
    // Check if it's a known field with no colon
    LColon := ALen; // entire line is field name
  end;

  // Determine field
  if (LColon >= 4) and (FBuf[AStart] = 'd') and (FBuf[AStart+1] = 'a') and
     (FBuf[AStart+2] = 't') and (FBuf[AStart+3] = 'a') and
     ((LColon = 4) or (FBuf[AStart+4] = ':')) then
  begin
    // data field
    FHasData := True;
    if LColon < ALen then
    begin
      LValStart := AStart + LColon + 1;
      LValLen := ALen - LColon - 1;
      if (LValLen > 0) and (FBuf[LValStart] = ' ') then
      begin Inc(LValStart); Dec(LValLen); end;
    end
    else
    begin
      LValStart := 0;
      LValLen := 0;
    end;
    if FDataLen > 0 then
    begin
      FData := FData + #10;
      Inc(FDataLen);
    end;
    if LValLen > 0 then
    begin
      SetLength(FData, FDataLen + LValLen);
      Move(FBuf[LValStart], FData[FDataLen + 1], LValLen);
      Inc(FDataLen, LValLen);
    end;
  end
  else if (LColon >= 5) and (FBuf[AStart] = 'e') and (FBuf[AStart+1] = 'v') and
          (FBuf[AStart+2] = 'e') and (FBuf[AStart+3] = 'n') and
          (FBuf[AStart+4] = 't') and ((LColon = 5) or (FBuf[AStart+5] = ':')) then
  begin
    if LColon < ALen then
    begin
      LValStart := AStart + LColon + 1;
      LValLen := ALen - LColon - 1;
      if (LValLen > 0) and (FBuf[LValStart] = ' ') then
      begin Inc(LValStart); Dec(LValLen); end;
      SetLength(FEventType, LValLen);
      if LValLen > 0 then
        Move(FBuf[LValStart], FEventType[1], LValLen);
    end
    else
      FEventType := '';
  end
  else if (LColon >= 2) and (FBuf[AStart] = 'i') and (FBuf[AStart+1] = 'd') and
          ((LColon = 2) or (FBuf[AStart+2] = ':')) then
  begin
    if LColon < ALen then
    begin
      LValStart := AStart + LColon + 1;
      LValLen := ALen - LColon - 1;
      if (LValLen > 0) and (FBuf[LValStart] = ' ') then
      begin Inc(LValStart); Dec(LValLen); end;
      SetLength(LValue, LValLen);
      if LValLen > 0 then
        Move(FBuf[LValStart], LValue[1], LValLen);
      // Ignore if contains NUL
      if Pos(#0, LValue) = 0 then
        FLastEventId := LValue;
    end
    else
      FLastEventId := '';
  end
  else if (LColon >= 5) and (FBuf[AStart] = 'r') and (FBuf[AStart+1] = 'e') and
          (FBuf[AStart+2] = 't') and (FBuf[AStart+3] = 'r') and
          (FBuf[AStart+4] = 'y') and ((LColon = 5) or (FBuf[AStart+5] = ':')) then
  begin
    if LColon < ALen then
    begin
      LValStart := AStart + LColon + 1;
      LValLen := ALen - LColon - 1;
      if (LValLen > 0) and (FBuf[LValStart] = ' ') then
      begin Inc(LValStart); Dec(LValLen); end;
      SetLength(LValue, LValLen);
      if LValLen > 0 then
        Move(FBuf[LValStart], LValue[1], LValLen);
      Val(LValue, LRetry, LCode);
      if LCode = 0 then
      begin
        FRetryMs := LRetry;
        FHasRetry := True;
      end;
    end;
  end;
end;

procedure TSseParser.DispatchEvent;
begin
  if FHasData then
  begin
    if FEventCount >= SizeUInt(Length(FEvents)) then
      SetLength(FEvents, FEventCount + 16);
    if FEventType = '' then
      FEvents[FEventCount].EventType := 'message'
    else
      FEvents[FEventCount].EventType := FEventType;
    FEvents[FEventCount].Data := FData;
    FEvents[FEventCount].Id := FLastEventId;
    FEvents[FEventCount].RetryMs := FRetryMs;
    FEvents[FEventCount].HasRetry := FHasRetry;
    Inc(FEventCount);
  end;
  FData := '';
  FDataLen := 0;
  FEventType := '';
  FHasRetry := False;
  FHasData := False;
end;

procedure TSseParser.Feed(const AChunk: string);
begin
  if Length(AChunk) > 0 then
    Feed(PAnsiChar(AChunk), Length(AChunk));
end;

procedure TSseParser.Feed(AData: PAnsiChar; ALen: SizeUInt);
var
  LI, LLineStart: SizeUInt;
begin
  if FError then Exit;
  if FBufLen + ALen > SSE_MAX_BUFFER_SIZE then
  begin
    FError := True;
    Exit;
  end;

  GrowBuf(FBufLen + ALen);
  Move(AData^, FBuf[FBufLen], ALen);
  Inc(FBufLen, ALen);

  LLineStart := 0;
  LI := 0;
  while LI < FBufLen do
  begin
    if FBuf[LI] = #10 then
    begin
      ProcessLine(LLineStart, LI - LLineStart);
      LLineStart := LI + 1;
    end
    else if FBuf[LI] = #13 then
    begin
      ProcessLine(LLineStart, LI - LLineStart);
      if (LI + 1 < FBufLen) and (FBuf[LI + 1] = #10) then
        Inc(LI);
      LLineStart := LI + 1;
    end;
    Inc(LI);
  end;

  // Move remainder to front
  if LLineStart > 0 then
  begin
    if LLineStart < FBufLen then
      Move(FBuf[LLineStart], FBuf[0], FBufLen - LLineStart);
    FBufLen := FBufLen - LLineStart;
  end;
end;

procedure TSseParser.Finish;
begin
  if FBufLen > 0 then
  begin
    ProcessLine(0, FBufLen);
    FBufLen := 0;
  end;
end;

function TSseParser.TryReadEvent(out AEvent: TSseEvent): Boolean;
begin
  if FEventHead >= FEventCount then
  begin
    Result := False;
    Exit;
  end;
  AEvent := FEvents[FEventHead];
  Inc(FEventHead);
  // Compact when all consumed
  if FEventHead = FEventCount then
  begin
    FEventHead := 0;
    FEventCount := 0;
  end;
  Result := True;
end;

function TSseParser.GetLastEventId: string;
begin
  Result := FLastEventId;
end;

function TSseParser.HasError: Boolean;
begin
  Result := FError;
end;

procedure TSseParser.Reset;
begin
  FBufLen := 0;
  FLastEventId := '';
  FEventType := '';
  FData := '';
  FDataLen := 0;
  FHasRetry := False;
  FHasData := False;
  FEventCount := 0;
  FEventHead := 0;
  FError := False;
end;

end.
