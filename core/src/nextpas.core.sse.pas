unit nextpas.core.sse;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sse.base,
  nextpas.core.sse.parser;

type
  TSseEvent = nextpas.core.sse.base.TSseEvent;
  TSseEventArray = nextpas.core.sse.base.TSseEventArray;
  TSseParser = nextpas.core.sse.parser.TSseParser;

function SseParseAll(const AInput: string): TSseEventArray;
function TrySseParseAll(const AInput: string; out AEvents: TSseEventArray): Boolean;
function SseParseOne(const AInput: string; out AEvent: TSseEvent): Boolean;

implementation

function SseParseAll(const AInput: string): TSseEventArray;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
  LCount: SizeUInt;
begin
  Result := nil;
  LCount := 0;
  LParser := TSseParser.Create;
  try
    LParser.Feed(AInput);
    LParser.Finish;
    while LParser.TryReadEvent(LEvent) do
    begin
      Inc(LCount);
      SetLength(Result, LCount);
      Result[LCount - 1] := LEvent;
    end;
  finally
    LParser.Free;
  end;
end;

function TrySseParseAll(const AInput: string; out AEvents: TSseEventArray): Boolean;
begin
  AEvents := SseParseAll(AInput);
  Result := Length(AEvents) > 0;
end;

function SseParseOne(const AInput: string; out AEvent: TSseEvent): Boolean;
var
  LLen, LI, LBlank: SizeInt;
  LLineStart, LLineEnd: SizeInt;
  LColon, LJ: SizeInt;
  LValStart, LValLen: SizeInt;
  LHasData: Boolean;
  LData: string;
  LDataLen: SizeInt;
  LEventType: string;
  LId: string;
  LRetryMs: Int32;
  LHasRetry: Boolean;
  LRetry: Int32;
  LCode: Integer;
  LValStr: string;
begin
  Result := False;
  LLen := Length(AInput);
  if LLen = 0 then Exit;

  // Find first blank line (event boundary)
  LBlank := 0;
  LI := 1;
  while LI <= LLen do
  begin
    if (LI < LLen) and (AInput[LI] = #10) and (AInput[LI + 1] = #10) then
    begin
      LBlank := LI; // blank line at LI
      Break;
    end;
    if (LI < LLen) and (AInput[LI] = #13) and (AInput[LI + 1] = #10) then
    begin
      if (LI + 2 <= LLen) and (AInput[LI + 2] = #13) and (LI + 3 <= LLen) and (AInput[LI + 3] = #10) then
      begin
        LBlank := LI;
        Break;
      end;
    end;
    if (LI < LLen) and (AInput[LI] = #13) and (AInput[LI + 1] = #13) then
    begin
      LBlank := LI;
      Break;
    end;
    Inc(LI);
  end;
  if LBlank = 0 then Exit; // no complete event

  // Process lines from 1..LBlank-1 (before the blank line)
  LHasData := False;
  LData := '';
  LDataLen := 0;
  LEventType := '';
  LId := '';
  LRetryMs := 0;
  LHasRetry := False;

  LLineStart := 1;
  LI := 1;
  while LI <= LBlank do
  begin
    // Find end of line
    if (AInput[LI] = #10) or (AInput[LI] = #13) then
    begin
      LLineEnd := LI - 1;
      // Process line from LLineStart..LLineEnd
      if LLineEnd >= LLineStart then
      begin
        // Skip comments
        if AInput[LLineStart] <> ':' then
        begin
          // Find colon
          LColon := 0;
          for LJ := LLineStart to LLineEnd do
            if AInput[LJ] = ':' then
            begin
              LColon := LJ;
              Break;
            end;

          if LColon > 0 then
          begin
            LValStart := LColon + 1;
            if (LValStart <= LLineEnd) and (AInput[LValStart] = ' ') then
              Inc(LValStart);
            LValLen := LLineEnd - LValStart + 1;
            if LValLen < 0 then LValLen := 0;

            // Identify field
            if (LColon - LLineStart = 4) and (AInput[LLineStart] = 'd') and
               (AInput[LLineStart+1] = 'a') and (AInput[LLineStart+2] = 't') and
               (AInput[LLineStart+3] = 'a') then
            begin
              LHasData := True;
              if LDataLen > 0 then
              begin
                SetLength(LData, LDataLen + 1 + LValLen);
                LData[LDataLen + 1] := #10;
                if LValLen > 0 then
                  Move(AInput[LValStart], LData[LDataLen + 2], LValLen);
                Inc(LDataLen, 1 + LValLen);
              end
              else
              begin
                SetLength(LData, LValLen);
                if LValLen > 0 then
                  Move(AInput[LValStart], LData[1], LValLen);
                LDataLen := LValLen;
              end;
            end
            else if (LColon - LLineStart = 5) and (AInput[LLineStart] = 'e') and
                    (AInput[LLineStart+1] = 'v') and (AInput[LLineStart+2] = 'e') and
                    (AInput[LLineStart+3] = 'n') and (AInput[LLineStart+4] = 't') then
            begin
              SetLength(LEventType, LValLen);
              if LValLen > 0 then
                Move(AInput[LValStart], LEventType[1], LValLen);
            end
            else if (LColon - LLineStart = 2) and (AInput[LLineStart] = 'i') and
                    (AInput[LLineStart+1] = 'd') then
            begin
              SetLength(LValStr, LValLen);
              if LValLen > 0 then
                Move(AInput[LValStart], LValStr[1], LValLen);
              if Pos(#0, LValStr) = 0 then
                LId := LValStr;
            end
            else if (LColon - LLineStart = 5) and (AInput[LLineStart] = 'r') and
                    (AInput[LLineStart+1] = 'e') and (AInput[LLineStart+2] = 't') and
                    (AInput[LLineStart+3] = 'r') and (AInput[LLineStart+4] = 'y') then
            begin
              SetLength(LValStr, LValLen);
              if LValLen > 0 then
                Move(AInput[LValStart], LValStr[1], LValLen);
              Val(LValStr, LRetry, LCode);
              if LCode = 0 then
              begin
                LRetryMs := LRetry;
                LHasRetry := True;
              end;
            end;
          end
          else
          begin
            // No colon: entire line is field name with empty value
            if (LLineEnd - LLineStart + 1 = 4) and (AInput[LLineStart] = 'd') and
               (AInput[LLineStart+1] = 'a') and (AInput[LLineStart+2] = 't') and
               (AInput[LLineStart+3] = 'a') then
            begin
              LHasData := True;
              if LDataLen > 0 then
              begin
                SetLength(LData, LDataLen + 1);
                LData[LDataLen + 1] := #10;
                Inc(LDataLen);
              end;
            end;
          end;
        end;
      end
      else
      begin
        // Empty line = blank line (dispatch), but we stop at LBlank anyway
      end;
      // Skip line ending
      if (AInput[LI] = #13) and (LI + 1 <= LLen) and (AInput[LI + 1] = #10) then
        Inc(LI, 2)
      else
        Inc(LI);
      LLineStart := LI;
    end
    else
      Inc(LI);
  end;

  if not LHasData then Exit;

  AEvent.Data := LData;
  if LEventType = '' then
    AEvent.EventType := 'message'
  else
    AEvent.EventType := LEventType;
  AEvent.Id := LId;
  AEvent.RetryMs := LRetryMs;
  AEvent.HasRetry := LHasRetry;
  Result := True;
end;

end.
