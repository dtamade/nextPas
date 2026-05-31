unit nextpas.core.http.impl.h1.scan;
{**
 * @desc SIMD-accelerated byte scanning for HTTP/1.1 parsing.
 *       Finds CRLF, double-CRLF, colon, and validates token characters.
 *}

{$I nextpas.core.settings.inc}

interface

{ Find first \r\n in buffer. Returns offset of \r, or -1 if not found. }
function ScanFindCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;

{ Find \r\n\r\n (header terminator). Returns offset of first \r, or -1. }
function ScanFindDoubleCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;

{ Find first ':' in buffer. Returns offset, or -1. }
function ScanFindColon(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;

{ Validate all bytes are valid HTTP token chars (RFC 7230 tchar).
  Returns True if all valid, False if any invalid byte found. }
function ScanValidateToken(const ABuf: PAnsiChar; const ALen: SizeUInt): Boolean;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec16;

function ScanFindCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
var
  LI: SizeUInt;
  LMask: TMask16;
  LBit: Int32;
begin
  LI := 0;
  while LI + 16 <= ALen do
  begin
    LMask := Vec16CmpEq(@ABuf[LI], Ord(#13));
    while LMask <> 0 do
    begin
      LBit := Vec16Ctz(LMask);
      if (LI + SizeUInt(LBit) + 1 < ALen) and (ABuf[LI + LBit + 1] = #10) then
        Exit(SizeInt(LI) + LBit);
      LMask := LMask and (LMask - 1);
    end;
    Inc(LI, 16);
  end;
  { Scalar tail }
  while LI + 1 < ALen do
  begin
    if (ABuf[LI] = #13) and (ABuf[LI + 1] = #10) then
      Exit(SizeInt(LI));
    Inc(LI);
  end;
  Result := -1;
end;

function ScanFindDoubleCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
var
  LI: SizeUInt;
  LMask: TMask16;
  LBit: Int32;
  LPos: SizeUInt;
begin
  if ALen < 4 then
    Exit(-1);
  LI := 0;
  while LI + 16 <= ALen do
  begin
    LMask := Vec16CmpEq(@ABuf[LI], Ord(#13));
    while LMask <> 0 do
    begin
      LBit := Vec16Ctz(LMask);
      LPos := LI + SizeUInt(LBit);
      if (LPos + 3 < ALen) and
         (ABuf[LPos + 1] = #10) and
         (ABuf[LPos + 2] = #13) and
         (ABuf[LPos + 3] = #10) then
        Exit(SizeInt(LPos));
      LMask := LMask and (LMask - 1);
    end;
    Inc(LI, 16);
  end;
  { Scalar tail }
  while LI + 3 < ALen do
  begin
    if (ABuf[LI] = #13) and (ABuf[LI + 1] = #10) and
       (ABuf[LI + 2] = #13) and (ABuf[LI + 3] = #10) then
      Exit(SizeInt(LI));
    Inc(LI);
  end;
  Result := -1;
end;

function ScanFindColon(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
var
  LI: SizeUInt;
  LMask: TMask16;
  LBit: Int32;
begin
  LI := 0;
  while LI + 16 <= ALen do
  begin
    LMask := Vec16CmpEq(@ABuf[LI], Ord(':'));
    if LMask <> 0 then
    begin
      LBit := Vec16Ctz(LMask);
      Exit(SizeInt(LI) + LBit);
    end;
    Inc(LI, 16);
  end;
  { Scalar tail }
  while LI < ALen do
  begin
    if ABuf[LI] = ':' then
      Exit(SizeInt(LI));
    Inc(LI);
  end;
  Result := -1;
end;

function ScanValidateToken(const ABuf: PAnsiChar; const ALen: SizeUInt): Boolean;
var
  LI: SizeUInt;
  LB: Byte;
begin
  if ALen = 0 then
    Exit(True);
  for LI := 0 to ALen - 1 do
  begin
    LB := Byte(ABuf[LI]);
    if (LB < 33) or (LB > 126) then
      Exit(False);
    case AnsiChar(LB) of
      '(', ')', '<', '>', '@', ',', ';', ':', '\', '"',
      '/', '[', ']', '?', '=', '{', '}':
        Exit(False);
    end;
  end;
  Result := True;
end;

end.
