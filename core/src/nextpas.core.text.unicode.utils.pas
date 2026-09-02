unit nextpas.core.text.unicode.utils;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base;

type
  TCodepointRange = record
    Lo: TUnicodeCodepoint;
    Hi: TUnicodeCodepoint;
  end;

function IsAsciiString(const AValue: string): Boolean; inline;
function AsciiLowerChar(const C: Char): Char; inline;
function AsciiLowerStr(const S: string): string; inline;
function ToLowerAsciiAware(const S: string): string; inline; { 单源 ignore-case helper：ASCII  fast-path IsAsciiString+AsciiLowerStr，非 ASCII 走 System.LowerCase；表演：inline+Ascii 8 字节并行预检+零拷贝原串返回；复用 bytes.ops 同级单源纪律 }
function StrHasPrefix(const S, Prefix: string): Boolean; inline;
function StrHasSuffix(const S, Suffix: string): Boolean; inline;
procedure EnsureOutputCapacity(var AValue: string; const ARequired: SizeInt); inline;
procedure AppendUtf8Codepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint); inline;
function RangeContains(const ARanges: array of TCodepointRange; const ACodePoint: TUnicodeCodepoint): Boolean;

implementation

uses
  nextpas.core.text.utf8;

function IsAsciiString(const AValue: string): Boolean;
var
  LLen: SizeInt;
  LIdx: SizeInt;
  LPtr: PByte;
  LWord: UInt64;
begin
  LLen := Length(AValue);
  if LLen = 0 then
    Exit(True);

  LPtr := PByte(@AValue[1]);

  // 8 字节并行检查：任一字节 bit7=1 则非 ASCII
  LIdx := 0;
  while LIdx + 7 < LLen do
  begin
    LWord := PUInt64(LPtr + LIdx)^;
    if (LWord and UInt64($8080808080808080)) <> 0 then
      Exit(False);
    Inc(LIdx, 8);
  end;

  // 剩余字节逐个检查
  while LIdx < LLen do
  begin
    if LPtr[LIdx] > $7F then
      Exit(False);
    Inc(LIdx);
  end;

  Result := True;
end;

function AsciiLowerChar(const C: Char): Char;
begin
  if (C >= 'A') and (C <= 'Z') then
    Result := Chr(Ord(C) + 32)
  else
    Result := C;
end;

function AsciiLowerStr(const S: string): string;
var
  LI: Integer;
begin
  Result := S;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Result[LI] := Chr(Ord(Result[LI]) + 32);
end;

function ToLowerAsciiAware(const S: string): string; inline;
begin
  if IsAsciiString(S) then Result := AsciiLowerStr(S) else Result := LowerCase(S);
end;

function StrHasPrefix(const S, Prefix: string): Boolean; inline;
var LI: SizeInt;
begin
  if Length(Prefix) = 0 then Exit(True);
  if Length(S) < Length(Prefix) then Exit(False);
  for LI := 1 to Length(Prefix) do
    if S[LI] <> Prefix[LI] then Exit(False);
  Result := True;
end;

function StrHasSuffix(const S, Suffix: string): Boolean; inline;
var LI, LS, LSu: SizeInt;
begin
  LSu := Length(Suffix);
  if LSu = 0 then Exit(True);
  LS := Length(S);
  if LS < LSu then Exit(False);
  for LI := 1 to LSu do
    if S[LS - LSu + LI] <> Suffix[LI] then Exit(False);
  Result := True;
end;

procedure EnsureOutputCapacity(var AValue: string; const ARequired: SizeInt);
var
  LCapacity: SizeInt;
begin
  if Length(AValue) >= ARequired then
    Exit;

  LCapacity := Length(AValue);
  if LCapacity < 32 then
    LCapacity := 32;
  while LCapacity < ARequired do
    LCapacity := LCapacity * 2;
  SetLength(AValue, LCapacity);
end;

procedure AppendUtf8Codepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LIdx: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  if LLen = 0 then
    LLen := UTF8Encode($FFFD, @LBuf[0]);

  EnsureOutputCapacity(ADst, AUsed + LLen);
  for LIdx := 0 to LLen - 1 do
    ADst[AUsed + LIdx + 1] := AnsiChar(LBuf[LIdx]);
  Inc(AUsed, LLen);
end;

function RangeContains(const ARanges: array of TCodepointRange; const ACodePoint: TUnicodeCodepoint): Boolean;
var
  LLo: Integer;
  LHi: Integer;
  LMid: Integer;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if ACodePoint < ARanges[LMid].Lo then
      LHi := LMid - 1
    else if ACodePoint > ARanges[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(True);
  end;
  Result := False;
end;

end.
