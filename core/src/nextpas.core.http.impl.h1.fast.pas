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
  end;

{ Try to parse a complete HTTP request from buffer using SIMD fast path.
  Returns Success=True if parsed successfully, False if should fallback to llhttp.
  Only handles simple cases: complete headers in buffer, no chunked request body. }
function FastParseRequest(const ABuf: PAnsiChar; const ALen: SizeUInt): TFastParseResult;

implementation

uses
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.scan;

function ParseMethodFast(const ABuf: PAnsiChar; const ALen: SizeUInt): THttpMethod;
begin
  Result := hmGet; // sentinel — caller checks Success on failure
  case ALen of
    3: begin
         if (ABuf[0] = 'G') and (ABuf[1] = 'E') and (ABuf[2] = 'T') then
           Exit(hmGet);
         if (ABuf[0] = 'P') and (ABuf[1] = 'U') and (ABuf[2] = 'T') then
           Exit(hmPut);
       end;
    4: begin
         if (ABuf[0] = 'P') and (ABuf[1] = 'O') and (ABuf[2] = 'S') and (ABuf[3] = 'T') then
           Exit(hmPost);
         if (ABuf[0] = 'H') and (ABuf[1] = 'E') and (ABuf[2] = 'A') and (ABuf[3] = 'D') then
           Exit(hmHead);
       end;
    5: begin
         if (ABuf[0] = 'P') and (ABuf[1] = 'A') and (ABuf[2] = 'T') and (ABuf[3] = 'C') and (ABuf[4] = 'H') then
           Exit(hmPatch);
         if (ABuf[0] = 'T') and (ABuf[1] = 'R') and (ABuf[2] = 'A') and (ABuf[3] = 'C') and (ABuf[4] = 'E') then
           Exit(hmTrace);
       end;
    6: begin
         if (ABuf[0] = 'D') and (ABuf[1] = 'E') and (ABuf[2] = 'L') and (ABuf[3] = 'E') and (ABuf[4] = 'T') and (ABuf[5] = 'E') then
           Exit(hmDelete);
       end;
    7: begin
         if (ABuf[0] = 'O') and (ABuf[1] = 'P') and (ABuf[2] = 'T') and (ABuf[3] = 'I') and (ABuf[4] = 'O') and (ABuf[5] = 'N') and (ABuf[6] = 'S') then
           Exit(hmOptions);
         if (ABuf[0] = 'C') and (ABuf[1] = 'O') and (ABuf[2] = 'N') and (ABuf[3] = 'N') and (ABuf[4] = 'E') and (ABuf[5] = 'C') and (ABuf[6] = 'T') then
           Exit(hmConnect);
       end;
  end;
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

function FastParseRequest(const ABuf: PAnsiChar; const ALen: SizeUInt): TFastParseResult;
var
  LHeaderEnd: SizeInt;
  LReqLineEnd: SizeInt;
  LSpace1, LSpace2: SizeUInt;
  LI: SizeUInt;
  LMethodLen: SizeUInt;
  LVersionStart: SizeUInt;
  LVersionLen: SizeUInt;
  LLineStart, LLineEnd: SizeUInt;
  LColonOff: SizeInt;
  LNameStart, LNameLen: SizeUInt;
  LValStart, LValLen: SizeUInt;
  LHdrName, LHdrVal: string;
  LBodyStart: SizeUInt;
  LCLStr: string;
  LCL: Int64;
begin
  Result := Default(TFastParseResult);
  Result.ContentLength := -1;

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

  // Parse method
  Result.Method := ParseMethodFast(ABuf, LMethodLen);
  // Validate method was recognized: check by round-trip
  case LMethodLen of
    3: if not ((ABuf[0] = 'G') or (ABuf[0] = 'P')) then Exit;
    4: if not ((ABuf[0] = 'P') or (ABuf[0] = 'H')) then Exit;
    5: if not ((ABuf[0] = 'P') or (ABuf[0] = 'T')) then Exit;
    6: if ABuf[0] <> 'D' then Exit;
    7: if not ((ABuf[0] = 'O') or (ABuf[0] = 'C')) then Exit;
  else
    Exit; // unknown method length
  end;

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
  Result.Headers := NewHttpHeaders;
  LLineStart := SizeUInt(LReqLineEnd) + 2; // skip past \r\n of request line

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

    SetString(LHdrName, ABuf + LNameStart, LNameLen);
    SetString(LHdrVal, ABuf + LValStart, LValLen);
    Result.Headers.Add(LHdrName, LHdrVal);

    // Check for Transfer-Encoding: chunked
    if (LNameLen = 17) and
       ((ABuf[LNameStart] = 't') or (ABuf[LNameStart] = 'T')) then
    begin
      // Quick case-insensitive check for "transfer-encoding"
      LCLStr := LHdrName;
      // Lowercase first char already checked
      if (Length(LCLStr) = 17) then
      begin
        // Normalize to lowercase for comparison
        SetString(LCLStr, ABuf + LNameStart, LNameLen);
        if (LCLStr[1] in ['t','T']) and (LCLStr[2] in ['r','R']) and
           (LCLStr[3] in ['a','A']) and (LCLStr[4] in ['n','N']) and
           (LCLStr[5] in ['s','S']) and (LCLStr[6] in ['f','F']) and
           (LCLStr[7] in ['e','E']) and (LCLStr[8] in ['r','R']) and
           (LCLStr[9] = '-') and
           (LCLStr[10] in ['e','E']) and (LCLStr[11] in ['n','N']) and
           (LCLStr[12] in ['c','C']) and (LCLStr[13] in ['o','O']) and
           (LCLStr[14] in ['d','D']) and (LCLStr[15] in ['i','I']) and
           (LCLStr[16] in ['n','N']) and (LCLStr[17] in ['g','G']) then
        begin
          // Has Transfer-Encoding — check if chunked
          if Pos('chunked', LHdrVal) > 0 then
            Exit; // fallback to llhttp
        end;
      end;
    end;

    // Advance past \r\n
    LLineStart := LLineEnd + 2;
  end;

  // Step 4: Determine body
  LBodyStart := SizeUInt(LHeaderEnd) + 4; // past \r\n\r\n
  Result.BodyStart := LBodyStart;

  // Check Content-Length
  LCLStr := Result.Headers.Get('Content-Length');
  if LCLStr <> '' then
  begin
    LCL := ParseInt64Fast(PAnsiChar(LCLStr), Length(LCLStr));
    if LCL < 0 then
      Exit; // invalid Content-Length
    Result.ContentLength := LCL;
    Result.Consumed := LBodyStart + SizeUInt(LCL);
  end
  else
  begin
    Result.ContentLength := 0;
    Result.Consumed := LBodyStart;
  end;

  Result.Success := True;
end;

end.
