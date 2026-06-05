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
    HasConnection: Boolean;
    HasExpect: Boolean;
    HasTransferEncoding: Boolean;
  end;

{ Try to parse a complete HTTP request from buffer using SIMD fast path.
  Returns Success=True if parsed successfully, False if should fallback to llhttp.
  Only handles simple cases: complete headers in buffer, no chunked request body. }
function FastParseRequest(const ABuf: PAnsiChar; const ALen: SizeUInt): TFastParseResult;

implementation

uses
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.scan;

type
  TFastLazyHeaders = class(TInterfacedObject, IHttpHeaders)
  private
    FRaw: string;
    FHeaders: IHttpHeaders;
    procedure EnsureMaterialized;
  public
    constructor Create(const ABuf: PAnsiChar; const ALen: SizeUInt);
    procedure Set_(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Del(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

function IsValidHeaderNameFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
  LB: Byte;
begin
  if ALen = 0 then
    Exit(False);
  for LI := 0 to ALen - 1 do
  begin
    LB := Byte(ABuf[LI]);
    if (LB < 33) or (LB > 126) or (LB = Byte(':')) then
      Exit(False);
  end;
  Result := True;
end;

function IsValidHeaderValueFast(const ABuf: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
begin
  for LI := 0 to ALen - 1 do
    if ABuf[LI] = #0 then
      Exit(False);
  Result := True;
end;

constructor TFastLazyHeaders.Create(const ABuf: PAnsiChar;
  const ALen: SizeUInt);
begin
  inherited Create;
  if ALen > 0 then
    SetString(FRaw, ABuf, ALen);
end;

procedure TFastLazyHeaders.EnsureMaterialized;
var
  LLineStart, LLineEnd: SizeInt;
  LColon: SizeInt;
  LValStart: SizeInt;
  LRawLen: SizeInt;
  LName, LValue: string;
begin
  if FHeaders <> nil then
    Exit;

  FHeaders := NewHttpHeaders;
  LRawLen := Length(FRaw);
  LLineStart := 1;
  while LLineStart <= LRawLen do
  begin
    LLineEnd := LLineStart;
    while (LLineEnd <= LRawLen) and
          (not ((FRaw[LLineEnd] = #13) and
                (LLineEnd < LRawLen) and (FRaw[LLineEnd + 1] = #10))) do
      Inc(LLineEnd);

    LColon := LLineStart;
    while (LColon < LLineEnd) and (FRaw[LColon] <> ':') do
      Inc(LColon);
    if LColon >= LLineEnd then
      Break;

    LValStart := LColon + 1;
    while (LValStart < LLineEnd) and
          ((FRaw[LValStart] = ' ') or (FRaw[LValStart] = #9)) do
      Inc(LValStart);

    SetString(LName, PAnsiChar(FRaw) + LLineStart - 1, LColon - LLineStart);
    SetString(LValue, PAnsiChar(FRaw) + LValStart - 1, LLineEnd - LValStart);
    FHeaders.Add(LName, LValue);

    if (LLineEnd < LRawLen) and (FRaw[LLineEnd] = #13) then
      LLineStart := LLineEnd + 2
    else
      Break;
  end;
  FRaw := '';
end;

procedure TFastLazyHeaders.Set_(const AName, AValue: string);
begin
  EnsureMaterialized;
  FHeaders.Set_(AName, AValue);
end;

procedure TFastLazyHeaders.Add(const AName, AValue: string);
begin
  EnsureMaterialized;
  FHeaders.Add(AName, AValue);
end;

function TFastLazyHeaders.Get(const AName: string): string;
begin
  EnsureMaterialized;
  Result := FHeaders.Get(AName);
end;

function TFastLazyHeaders.GetAll(const AName: string): TStringArray;
begin
  EnsureMaterialized;
  Result := FHeaders.GetAll(AName);
end;

function TFastLazyHeaders.Has(const AName: string): Boolean;
begin
  EnsureMaterialized;
  Result := FHeaders.Has(AName);
end;

procedure TFastLazyHeaders.Del(const AName: string);
begin
  EnsureMaterialized;
  FHeaders.Del(AName);
end;

procedure TFastLazyHeaders.Clear;
begin
  EnsureMaterialized;
  FHeaders.Clear;
end;

function TFastLazyHeaders.Count: Int32;
begin
  EnsureMaterialized;
  Result := FHeaders.Count;
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
  out AMethod: THttpMethod): Boolean;
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

function ParseInt64Fast(const ABuf: PAnsiChar; const ALen: SizeUInt): Int64;
var
  LI: SizeUInt;
  LB: Byte;
begin
  Result := 0;
  if ALen = 0 then
    Exit(-1);
  for LI := 0 to ALen - 1 do
  begin
    LB := Byte(ABuf[LI]);
    if (LB < Byte('0')) or (LB > Byte('9')) then
      Exit(-1);
    Result := Result * 10 + Int64(LB - Byte('0'));
    if Result < 0 then // overflow
      Exit(-1);
  end;
end;

function AsciiEqualsCI(const ABuf: PAnsiChar; const ALen: SizeUInt;
  const AText: AnsiString): Boolean;
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
  LValStart, LValLen: SizeUInt;
  LHeadersStart, LHeadersLen: SizeUInt;
  LBodyStart: SizeUInt;
  LContentLength: Int64;
  LSeenContentLength: Boolean;
begin
  Result := Default(TFastParseResult);
  Result.ContentLength := -1;
  LContentLength := 0;
  LSeenContentLength := False;

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
    while (LValStart < LLineEnd) and ((ABuf[LValStart] = ' ') or (ABuf[LValStart] = #9)) do
      Inc(LValStart);
    LValLen := LLineEnd - LValStart;

    if (not IsValidHeaderNameFast(ABuf + LNameStart, LNameLen)) or
       (not IsValidHeaderValueFast(ABuf + LValStart, LValLen)) then
      Exit;

    if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'host') then
      Result.HasHost := LValLen > 0
    else if AsciiEqualsCI(ABuf + LNameStart, LNameLen, 'connection') then
      Result.HasConnection := True
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
