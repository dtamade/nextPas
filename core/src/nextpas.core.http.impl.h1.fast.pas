unit nextpas.core.http.impl.h1.fast;
{**
 * @desc SIMD-accelerated HTTP/1.1 fast path parser.
 *       Handles common requests without llhttp state machine overhead.
 *       Falls back (Success=False) on chunked encoding, obs-fold, or malformed input.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TFastParseResult = record
    Success: Boolean;
    Method: THttpMethod;
    Path: string;
    Version: THttpVersion;
    Headers: IHttpHeaders;
    BodyStart: SizeUInt;
    ContentLength: Int64;
    Consumed: SizeUInt;
    HasHost: Boolean;
    HostRepeated: Boolean;
    HasConnection: Boolean;
    ConnectionKeepAlive: Boolean;
    ConnectionClose: Boolean;
    ConnectionUnsupported: Boolean;
    HasExpect: Boolean;
    HasTransferEncoding: Boolean;
    HasContentLength: Boolean;
  end;

{ Try to parse a complete HTTP request from buffer using SIMD fast path.
  Returns Success=True if parsed successfully, False if should fallback to llhttp.
  Only handles simple cases: complete headers in buffer, no chunked request body. }
function FastParseRequest(const ABuf: PAnsiChar; const ALen: SizeUInt): TFastParseResult;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.scan;

type
  TFastRawHeaderSpan = record
    NameStart: SizeInt;
    NameLen: SizeInt;
    ValueStart: SizeInt;
    ValueLen: SizeInt;
  end;

  TFastLazyHeaders = class(TInterfacedObject, IHttpHeaders)
  private
    FRaw: string;
    FHeaders: IHttpHeaders;
    function NextRawHeader(var ALineStart: SizeInt;
      out ASpan: TFastRawHeaderSpan): Boolean;
    function HasRawHeader(const AName: string): Boolean;
    procedure EnsureMaterialized;
    function FindRawFirstValue(const AName: string; out AValue: string): Boolean;
    function GetAllRawValues(const AName: string): TStringArray;
    function CountRawHeaders: Int32;
  public
    constructor Create(const ABuf: PAnsiChar; const ALen: SizeUInt);
    procedure SetHeader(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Remove(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

function IsValidHeaderNameFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean; inline;
var
  LI: SizeUInt;
begin
  if ALen = 0 then
    Exit(False);
  for LI := 0 to ALen - 1 do
    if not IsHttpHeaderNameChar(ABuf[LI]) then
      Exit(False);
  Result := True;
end;

function ValidateLookupHeaderNameFast(const AName: string): string;
var
  LI: SizeInt;
  LNeedsNormalize: Boolean;
begin
  if AName = '' then
    raise EHttpError.Create('empty header name');
  Result := AName;
  LNeedsNormalize := False;
  for LI := 1 to Length(AName) do
  begin
    if not IsHttpHeaderNameChar(AnsiChar(AName[LI])) then
      raise EHttpError.Create('invalid header name character');
    if (AName[LI] >= 'A') and (AName[LI] <= 'Z') then
      LNeedsNormalize := True;
  end;
  if LNeedsNormalize then
    for LI := 1 to Length(Result) do
      if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
        Result[LI] := Chr(Ord(Result[LI]) + 32);
end;

function IsValidHeaderValueFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean; inline;
var
  LI: SizeUInt;
  LByte: Byte;
begin
  if ALen = 0 then
    Exit(True);
  for LI := 0 to ALen - 1 do
  begin
    LByte := Byte(ABuf[LI]);
    if ((LByte < 32) and (LByte <> Ord(#9))) or (LByte = 127) then
      Exit(False);
  end;
  Result := True;
end;

function IsValidRequestTargetFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean; inline;
var
  LI: SizeUInt;
  LByte: Byte;
begin
  if ALen = 0 then
    Exit(False);
  for LI := 0 to ALen - 1 do
  begin
    LByte := Byte(ABuf[LI]);
    if (LByte <= 31) or (LByte = 127) then
      Exit(False);
  end;
  Result := True;
end;

function FastLowerAscii(const AChar: AnsiChar): AnsiChar; inline;
begin
  if (AChar >= 'A') and (AChar <= 'Z') then
    Result := AnsiChar(Ord(AChar) + 32)
  else
    Result := AChar;
end;

function IsHeaderOwsFast(const AChar: AnsiChar): Boolean; inline;
begin
  Result := (AChar = ' ') or (AChar = #9);
end;

function FastHeaderNameMatches(const ARaw: string; const AStart: SizeInt;
  const ALen: SizeInt; const AName: string): Boolean; inline;
var
  LI: SizeInt;
begin
  Result := False;
  if ALen <> Length(AName) then
    Exit;
  for LI := 0 to ALen - 1 do
    if FastLowerAscii(ARaw[AStart + LI]) <>
       FastLowerAscii(AnsiChar(AName[LI + 1])) then
      Exit;
  Result := True;
end;

constructor TFastLazyHeaders.Create(const ABuf: PAnsiChar;
  const ALen: SizeUInt);
begin
  inherited Create;
  if ALen > 0 then
    SetString(FRaw, ABuf, ALen);
end;

function TFastLazyHeaders.NextRawHeader(var ALineStart: SizeInt;
  out ASpan: TFastRawHeaderSpan): Boolean;
var
  LLineEnd: SizeInt;
  LColon: SizeInt;
  LValStart: SizeInt;
  LValEnd: SizeInt;
  LRawLen: SizeInt;
begin
  Result := False;
  ASpan := Default(TFastRawHeaderSpan);
  LRawLen := Length(FRaw);
  if ALineStart > LRawLen then
    Exit;

  LLineEnd := ALineStart;
  while (LLineEnd <= LRawLen) and
        (not ((FRaw[LLineEnd] = #13) and
              (LLineEnd < LRawLen) and (FRaw[LLineEnd + 1] = #10))) do
    Inc(LLineEnd);

  LColon := ALineStart;
  while (LColon < LLineEnd) and (FRaw[LColon] <> ':') do
    Inc(LColon);
  if LColon >= LLineEnd then
  begin
    ALineStart := LRawLen + 1;
    Exit;
  end;

  LValStart := LColon + 1;
  while (LValStart < LLineEnd) and
        IsHeaderOwsFast(AnsiChar(FRaw[LValStart])) do
    Inc(LValStart);
  LValEnd := LLineEnd;
  while (LValEnd > LValStart) and
        IsHeaderOwsFast(AnsiChar(FRaw[LValEnd - 1])) do
    Dec(LValEnd);

  ASpan.NameStart := ALineStart;
  ASpan.NameLen := LColon - ALineStart;
  ASpan.ValueStart := LValStart;
  ASpan.ValueLen := LValEnd - LValStart;

  if (LLineEnd < LRawLen) and (FRaw[LLineEnd] = #13) then
    ALineStart := LLineEnd + 2
  else
    ALineStart := LRawLen + 1;
  Result := True;
end;

procedure TFastLazyHeaders.EnsureMaterialized;
var
  LLineStart: SizeInt;
  LSpan: TFastRawHeaderSpan;
  LHeaders: THttpHeaders;
begin
  if FHeaders <> nil then
    Exit;

  LHeaders := THttpHeaders.Create;
  FHeaders := LHeaders as IHttpHeaders;
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
    LHeaders.AddParsedSpans(PAnsiChar(FRaw) + LSpan.NameStart - 1,
      SizeUInt(LSpan.NameLen), PAnsiChar(FRaw) + LSpan.ValueStart - 1,
      SizeUInt(LSpan.ValueLen));
  FRaw := '';
end;

function TFastLazyHeaders.FindRawFirstValue(const AName: string;
  out AValue: string): Boolean;
var
  LLineStart: SizeInt;
  LSpan: TFastRawHeaderSpan;
begin
  Result := False;
  AValue := '';
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
  begin
    if FastHeaderNameMatches(FRaw, LSpan.NameStart, LSpan.NameLen,
      AName) then
    begin
      SetString(AValue, PAnsiChar(FRaw) + LSpan.ValueStart - 1,
        LSpan.ValueLen);
      Exit(True);
    end;
  end;
end;

function TFastLazyHeaders.HasRawHeader(const AName: string): Boolean;
var
  LLineStart: SizeInt;
  LSpan: TFastRawHeaderSpan;
begin
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
    if FastHeaderNameMatches(FRaw, LSpan.NameStart, LSpan.NameLen,
      AName) then
      Exit(True);
  Result := False;
end;

function TFastLazyHeaders.GetAllRawValues(const AName: string): TStringArray;
var
  LCount: Int32;
  LIndex: Int32;
  LLineStart: SizeInt;
  LSpan: TFastRawHeaderSpan;

begin
  Result := nil;
  LCount := 0;
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
    if FastHeaderNameMatches(FRaw, LSpan.NameStart, LSpan.NameLen,
      AName) then
      Inc(LCount);

  if LCount = 0 then
    Exit;

  SetLength(Result, LCount);
  LIndex := 0;
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
    if FastHeaderNameMatches(FRaw, LSpan.NameStart, LSpan.NameLen,
      AName) then
    begin
      SetString(Result[LIndex], PAnsiChar(FRaw) + LSpan.ValueStart - 1,
        LSpan.ValueLen);
      Inc(LIndex);
    end;
end;

function TFastLazyHeaders.CountRawHeaders: Int32;
var
  LLineStart: SizeInt;
  LSpan: TFastRawHeaderSpan;
begin
  Result := 0;
  LLineStart := 1;
  while NextRawHeader(LLineStart, LSpan) do
    Inc(Result);
end;

procedure TFastLazyHeaders.SetHeader(const AName, AValue: string);
begin
  EnsureMaterialized;
  FHeaders.SetHeader(AName, AValue);
end;

procedure TFastLazyHeaders.Add(const AName, AValue: string);
begin
  EnsureMaterialized;
  FHeaders.Add(AName, AValue);
end;

function TFastLazyHeaders.Get(const AName: string): string;
var
  LName: string;
begin
  if FHeaders <> nil then
    Exit(FHeaders.Get(AName));
  LName := ValidateLookupHeaderNameFast(AName);
  if not FindRawFirstValue(LName, Result) then
    Result := '';
end;

function TFastLazyHeaders.GetAll(const AName: string): TStringArray;
var
  LName: string;
begin
  if FHeaders <> nil then
    Exit(FHeaders.GetAll(AName));
  LName := ValidateLookupHeaderNameFast(AName);
  Result := GetAllRawValues(LName);
end;

function TFastLazyHeaders.Has(const AName: string): Boolean;
var
  LName: string;
begin
  if FHeaders <> nil then
    Exit(FHeaders.Has(AName));
  LName := ValidateLookupHeaderNameFast(AName);
  Result := HasRawHeader(LName);
end;

procedure TFastLazyHeaders.Remove(const AName: string);
begin
  EnsureMaterialized;
  FHeaders.Remove(AName);
end;

procedure TFastLazyHeaders.Clear;
begin
  EnsureMaterialized;
  FHeaders.Clear;
end;

function TFastLazyHeaders.Count: Int32;
begin
  if FHeaders <> nil then
    Exit(FHeaders.Count);
  Result := CountRawHeaders;
end;

procedure TFastLazyHeaders.ForEach(const ACallback: THeaderIterator);
begin
  EnsureMaterialized;
  FHeaders.ForEach(ACallback);
end;

function TFastLazyHeaders.Clone: IHttpHeaders;
begin
  EnsureMaterialized;
  Result := FHeaders.Clone;
end;

function TryParseMethodFast(const ABuf: PAnsiChar; const ALen: SizeUInt;
  out AMethod: THttpMethod): Boolean; inline;
begin
  Result := True;
  case ALen of
    3: begin
         if (ABuf[0] = 'G') and (ABuf[1] = 'E') and (ABuf[2] = 'T') then
          begin
            AMethod := hmGet;
            Exit;
          end;
         if (ABuf[0] = 'P') and (ABuf[1] = 'U') and (ABuf[2] = 'T') then
          begin
            AMethod := hmPut;
            Exit;
          end;
       end;
    4: begin
         if (ABuf[0] = 'P') and (ABuf[1] = 'O') and (ABuf[2] = 'S') and (ABuf[3] = 'T') then
          begin
            AMethod := hmPost;
            Exit;
          end;
         if (ABuf[0] = 'H') and (ABuf[1] = 'E') and (ABuf[2] = 'A') and (ABuf[3] = 'D') then
          begin
            AMethod := hmHead;
            Exit;
          end;
       end;
    5: begin
         if (ABuf[0] = 'P') and (ABuf[1] = 'A') and (ABuf[2] = 'T') and (ABuf[3] = 'C') and (ABuf[4] = 'H') then
          begin
            AMethod := hmPatch;
            Exit;
          end;
         if (ABuf[0] = 'T') and (ABuf[1] = 'R') and (ABuf[2] = 'A') and (ABuf[3] = 'C') and (ABuf[4] = 'E') then
          begin
            AMethod := hmTrace;
            Exit;
          end;
       end;
    6: begin
         if (ABuf[0] = 'D') and (ABuf[1] = 'E') and (ABuf[2] = 'L') and (ABuf[3] = 'E') and (ABuf[4] = 'T') and (ABuf[5] = 'E') then
          begin
            AMethod := hmDelete;
            Exit;
          end;
       end;
    7: begin
         if (ABuf[0] = 'O') and (ABuf[1] = 'P') and (ABuf[2] = 'T') and (ABuf[3] = 'I') and (ABuf[4] = 'O') and (ABuf[5] = 'N') and (ABuf[6] = 'S') then
          begin
            AMethod := hmOptions;
            Exit;
          end;
         if (ABuf[0] = 'C') and (ABuf[1] = 'O') and (ABuf[2] = 'N') and (ABuf[3] = 'N') and (ABuf[4] = 'E') and (ABuf[5] = 'C') and (ABuf[6] = 'T') then
          begin
            AMethod := hmConnect;
            Exit;
          end;
       end;
  end;
  Result := False;
end;

function ParseInt64Fast(const ABuf: PAnsiChar; const ALen: SizeUInt): Int64; inline;
var
  LI: SizeUInt;
  LDigit: Int64;
begin
  Result := 0;
  if ALen = 0 then
    Exit(-1);
  for LI := 0 to ALen - 1 do
  begin
    if (ABuf[LI] < '0') or (ABuf[LI] > '9') then
      Exit(-1);
    LDigit := Ord(ABuf[LI]) - Ord('0');
    if Result > (High(Int64) - LDigit) div 10 then
      Exit(-1);
    Result := Result * 10 + LDigit;
  end;
end;

function AsciiEqualsCI(const ABuf: PAnsiChar; const ALen: SizeUInt;
  const AText: AnsiString): Boolean; inline;
var
  LI: SizeUInt;
  LC, LW: AnsiChar;
begin
  if ALen <> SizeUInt(Length(AText)) then
    Exit(False);
  for LI := 0 to ALen - 1 do
  begin
    LC := ABuf[LI];
    LW := AText[SizeInt(LI) + 1];
    if (LC >= 'A') and (LC <= 'Z') then
      LC := Chr(Ord(LC) + 32);
    if LC <> LW then
      Exit(False);
  end;
  Result := True;
end;

procedure ApplyConnectionTokenFast(const ABuf: PAnsiChar;
  const AStart, AEnd: SizeUInt; var AResult: TFastParseResult); inline;
begin
  if AStart >= AEnd then
    Exit;
  if AsciiEqualsCI(ABuf + AStart, AEnd - AStart, 'keep-alive') then
    AResult.ConnectionKeepAlive := True
  else if AsciiEqualsCI(ABuf + AStart, AEnd - AStart, 'close') then
    AResult.ConnectionClose := True
  else
    AResult.ConnectionUnsupported := True;
end;

procedure UpdateConnectionFlagsFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt; var AResult: TFastParseResult);
var
  LStart: SizeUInt;
  LPos: SizeUInt;
  LTokenStart: SizeUInt;
  LTokenEnd: SizeUInt;
begin
  LStart := 0;
  while LStart < ALen do
  begin
    LPos := LStart;
    while (LPos < ALen) and (ABuf[LPos] <> ',') do
      Inc(LPos);

    LTokenStart := LStart;
    LTokenEnd := LPos;
    while (LTokenStart < LTokenEnd) and
          ((ABuf[LTokenStart] = ' ') or (ABuf[LTokenStart] = #9)) do
      Inc(LTokenStart);
    while (LTokenEnd > LTokenStart) and
          ((ABuf[LTokenEnd - 1] = ' ') or (ABuf[LTokenEnd - 1] = #9)) do
      Dec(LTokenEnd);

    ApplyConnectionTokenFast(ABuf, LTokenStart, LTokenEnd, AResult);
    LStart := LPos + 1;
  end;
end;

function FastParseRequest(const ABuf: PAnsiChar; const ALen: SizeUInt): TFastParseResult;
var
  LHeaderEnd: SizeInt;
  LReqLineEnd: SizeInt;
  LSpace1, LSpace2: SizeUInt;
  LMethodLen: SizeUInt;
  LVersionStart: SizeUInt;
  LVersionLen: SizeUInt;
  LLineStart, LLineEnd: SizeUInt;
  LColonOff: SizeInt;
  LNameStart, LNameLen: SizeUInt;
  LValStart, LValEnd, LValLen: SizeUInt;
  LHeadersStart, LHeadersLen: SizeUInt;
  LBodyStart: SizeUInt;
  LContentLength: Int64;
  LSeenContentLength: Boolean;
  LSeenHost: Boolean;
begin
  Result := Default(TFastParseResult);
  Result.ContentLength := -1;
  LContentLength := 0;
  LSeenContentLength := False;
  LSeenHost := False;

  // Step 1: Find header end (\r\n\r\n)
  LHeaderEnd := ScanFindDoubleCRLF(ABuf, ALen);
  if LHeaderEnd < 0 then
    Exit; // incomplete

  // Step 2: Parse request line — find first CRLF
  LReqLineEnd := ScanFindCRLF(ABuf, SizeUInt(LHeaderEnd));
  if LReqLineEnd < 0 then
    Exit; // malformed

  // Find first space (method delimiter)
  LSpace1 := 0;
  while (LSpace1 < SizeUInt(LReqLineEnd)) and (ABuf[LSpace1] <> ' ') do
    Inc(LSpace1);
  if LSpace1 = 0 then
    Exit; // empty method
  if LSpace1 >= SizeUInt(LReqLineEnd) then
    Exit; // no space found

  LMethodLen := LSpace1;

  // Find second space (path delimiter)
  LSpace2 := LSpace1 + 1;
  while (LSpace2 < SizeUInt(LReqLineEnd)) and (ABuf[LSpace2] <> ' ') do
    Inc(LSpace2);
  if LSpace2 >= SizeUInt(LReqLineEnd) then
    Exit; // no second space
  if LSpace2 = LSpace1 + 1 then
    Exit; // empty path

  if not TryParseMethodFast(ABuf, LMethodLen, Result.Method) then
    Exit;

  // Extract path
  if not IsValidRequestTargetFast(ABuf + LSpace1 + 1,
    LSpace2 - LSpace1 - 1) then
    Exit;
  SetString(Result.Path, ABuf + LSpace1 + 1, LSpace2 - LSpace1 - 1);

  // Parse version
  LVersionStart := LSpace2 + 1;
  LVersionLen := SizeUInt(LReqLineEnd) - LVersionStart;
  if LVersionLen = 8 then
  begin
    if (ABuf[LVersionStart] = 'H') and (ABuf[LVersionStart+1] = 'T') and
       (ABuf[LVersionStart+2] = 'T') and (ABuf[LVersionStart+3] = 'P') and
       (ABuf[LVersionStart+4] = '/') and (ABuf[LVersionStart+5] = '1') and
       (ABuf[LVersionStart+6] = '.') then
    begin
      case ABuf[LVersionStart+7] of
        '1': Result.Version := hvHttp11;
        '0': Result.Version := hvHttp10;
      else
        Exit; // unsupported minor version
      end;
    end
    else
      Exit; // not HTTP/1.x
  end
  else
    Exit; // wrong version length

  // Step 3: Parse headers
  LLineStart := SizeUInt(LReqLineEnd) + 2; // skip past \r\n of request line
  LHeadersStart := LLineStart;

  while LLineStart < SizeUInt(LHeaderEnd) do
  begin
    // Check for obs-fold (continuation line)
    if (ABuf[LLineStart] = ' ') or (ABuf[LLineStart] = #9) then
      Exit; // fallback — obs-fold not supported

    // Find end of this header line
    LLineEnd := LLineStart;
    while (LLineEnd + 1 <= SizeUInt(LHeaderEnd)) do
    begin
      if (ABuf[LLineEnd] = #13) and (ABuf[LLineEnd + 1] = #10) then
        Break;
      Inc(LLineEnd);
    end;
    if LLineEnd = LLineStart then
      Break; // empty line (shouldn't happen before LHeaderEnd)

    // Find colon in this line
    LColonOff := ScanFindColon(ABuf + LLineStart, LLineEnd - LLineStart);
    if LColonOff < 0 then
      Exit; // malformed header (no colon)
    if LColonOff = 0 then
      Exit; // empty header name

    LNameStart := LLineStart;
    LNameLen := SizeUInt(LColonOff);

    // Value starts after colon, trim leading OWS (spaces/tabs)
    LValStart := LLineStart + SizeUInt(LColonOff) + 1;
    while (LValStart < LLineEnd) and IsHeaderOwsFast(ABuf[LValStart]) do
      Inc(LValStart);
    LValEnd := LLineEnd;
    while (LValEnd > LValStart) and IsHeaderOwsFast(ABuf[LValEnd - 1]) do
      Dec(LValEnd);
    LValLen := LValEnd - LValStart;

    if (not IsValidHeaderNameFast(ABuf + LNameStart, LNameLen)) or
       (not IsValidHeaderValueFast(ABuf + LValStart, LValLen)) then
      Exit;

    if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'host') then
    begin
      if LSeenHost then
        Result.HostRepeated := True
      else
      begin
        LSeenHost := True;
        Result.HasHost := LValLen > 0;
      end;
    end
    else if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'connection') then
    begin
      Result.HasConnection := True;
      UpdateConnectionFlagsFast(ABuf + LValStart, LValLen, Result);
    end
    else if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'expect') then
      Result.HasExpect := True
    else if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'transfer-encoding') then
    begin
      Result.HasTransferEncoding := True;
      Exit; // transfer-coding validation belongs to the llhttp fallback
    end
    else if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'content-length') then
    begin
      if LSeenContentLength then
        Exit; // duplicate Content-Length is validated by llhttp/server fallback
      LContentLength := ParseInt64Fast(ABuf + LValStart, LValLen);
      if LContentLength < 0 then
        Exit; // invalid Content-Length
      LSeenContentLength := True;
      Result.HasContentLength := True;
    end;

    // Advance past \r\n
    LLineStart := LLineEnd + 2;
  end;

  // Step 4: Determine body
  LBodyStart := SizeUInt(LHeaderEnd) + 4; // past \r\n\r\n
  Result.BodyStart := LBodyStart;

  if LSeenContentLength then
  begin
    Result.ContentLength := LContentLength;
    Result.Consumed := LBodyStart + SizeUInt(LContentLength);
    if Result.Consumed > ALen then
      Exit; // body is incomplete
  end
  else
  begin
    Result.ContentLength := 0;
    Result.Consumed := LBodyStart;
  end;

  LHeadersLen := SizeUInt(LHeaderEnd) - LHeadersStart;
  Result.Headers := TFastLazyHeaders.Create(ABuf + LHeadersStart, LHeadersLen);
  Result.Success := True;
end;

end.
