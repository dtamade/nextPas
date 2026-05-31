unit nextpas.core.sse.parser;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sse.base;

type
  TSseParser = record
  private
    FBuffer: string;
    FLastEventId: string;
    FEventType: string;
    FData: string;
    FRetryMs: Int32;
    FHasRetry: Boolean;
    FHasData: Boolean;
    FEvents: TSseEventArray;
    FEventCount: SizeUInt;
    FError: Boolean;
    procedure ProcessLine(const ALine: string);
    procedure DispatchEvent;
  public
    class function Create: TSseParser; static;
    procedure Feed(const AChunk: string);
    procedure Finish;
    function TryReadEvent(out AEvent: TSseEvent): Boolean;
    function GetLastEventId: string;
    function HasError: Boolean;
    procedure Reset;
  end;

implementation

const
  SSE_MAX_BUFFER_SIZE = 1024 * 1024; { 1MB }

class function TSseParser.Create: TSseParser;
begin
  Result := Default(TSseParser);
  Result.FEventCount := 0;
  Result.FHasData := False;
  Result.FError := False;
  SetLength(Result.FEvents, 0);
end;

procedure TSseParser.ProcessLine(const ALine: string);
var
  LLen, LColon, LValStart: Integer;
  LField, LValue: string;
  LRetry: Int32;
  LCode: Integer;
  LI: Integer;
begin
  LLen := Length(ALine);
  { Empty line dispatches event }
  if LLen = 0 then
  begin
    DispatchEvent;
    Exit;
  end;
  { Comment line }
  if ALine[1] = ':' then
    Exit;
  { Find first colon }
  LColon := 0;
  for LI := 1 to LLen do
    if ALine[LI] = ':' then
    begin
      LColon := LI;
      Break;
    end;
  if LColon = 0 then
  begin
    { Entire line is field name, value is empty }
    LField := ALine;
    LValue := '';
  end
  else
  begin
    LField := Copy(ALine, 1, LColon - 1);
    LValStart := LColon + 1;
    { Skip single space after colon }
    if (LValStart <= LLen) and (ALine[LValStart] = ' ') then
      Inc(LValStart);
    LValue := Copy(ALine, LValStart, LLen - LValStart + 1);
  end;

  if LField = 'data' then
  begin
    FHasData := True;
    if FData <> '' then
      FData := FData + #10 + LValue
    else
      FData := LValue;
  end
  else if LField = 'event' then
    FEventType := LValue
  else if LField = 'id' then
  begin
    { Ignore if value contains NUL }
    if Pos(#0, LValue) = 0 then
      FLastEventId := LValue;
  end
  else if LField = 'retry' then
  begin
    { Only accept if all digits }
    if LValue <> '' then
    begin
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
  { Only dispatch if data field was set (even if empty string via "data:") }
  if FHasData then
  begin
    if FEventCount >= SizeUInt(Length(FEvents)) then
      SetLength(FEvents, FEventCount + 8);
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
  { Reset per-event state }
  FData := '';
  FEventType := '';
  FHasRetry := False;
  FHasData := False;
end;

procedure TSseParser.Feed(const AChunk: string);
var
  LI, LLineStart, LLen: Integer;
  LLine: string;
  LCh: Char;
begin
  if FError then
    Exit;
  FBuffer := FBuffer + AChunk;
  if Length(FBuffer) > SSE_MAX_BUFFER_SIZE then
  begin
    FBuffer := '';
    FError := True;
    Exit;
  end;
  LLen := Length(FBuffer);
  LLineStart := 1;
  LI := 1;
  while LI <= LLen do
  begin
    LCh := FBuffer[LI];
    if LCh = #10 then
    begin
      LLine := Copy(FBuffer, LLineStart, LI - LLineStart);
      ProcessLine(LLine);
      LLineStart := LI + 1;
    end
    else if LCh = #13 then
    begin
      LLine := Copy(FBuffer, LLineStart, LI - LLineStart);
      ProcessLine(LLine);
      { Skip LF after CR }
      if (LI < LLen) and (FBuffer[LI + 1] = #10) then
        Inc(LI);
      LLineStart := LI + 1;
    end;
    Inc(LI);
  end;
  { Keep unprocessed remainder }
  if LLineStart <= LLen then
    FBuffer := Copy(FBuffer, LLineStart, LLen - LLineStart + 1)
  else
    FBuffer := '';
end;

procedure TSseParser.Finish;
begin
  { Per SSE spec: do NOT dispatch incomplete event at EOF.
    Only process the remaining buffer as a line (which may set fields),
    but do not force a dispatch. Events are only dispatched on blank line. }
  if FBuffer <> '' then
  begin
    ProcessLine(FBuffer);
    FBuffer := '';
  end;
end;

function TSseParser.TryReadEvent(out AEvent: TSseEvent): Boolean;
var
  LI: SizeUInt;
begin
  if FEventCount = 0 then
  begin
    AEvent := Default(TSseEvent);
    Exit(False);
  end;
  AEvent := FEvents[0];
  { Shift remaining events }
  for LI := 1 to FEventCount - 1 do
    FEvents[LI - 1] := FEvents[LI];
  Dec(FEventCount);
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
  FBuffer := '';
  FLastEventId := '';
  FEventType := '';
  FData := '';
  FRetryMs := 0;
  FHasRetry := False;
  FHasData := False;
  FError := False;
  FEventCount := 0;
  SetLength(FEvents, 0);
end;

end.
