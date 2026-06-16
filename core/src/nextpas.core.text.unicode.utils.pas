unit nextpas.core.text.unicode.utils;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.base;

type
  TCodepointRange = record
    Lo: TUnicodeCodepoint;
    Hi: TUnicodeCodepoint;
  end;

function IsAsciiString(const AValue: string): Boolean; inline;
procedure EnsureOutputCapacity(var AValue: string; const ARequired: SizeInt); inline;
procedure AppendUtf8Codepoint(var ADst: string; var AUsed: SizeInt; const ACp: TUnicodeCodepoint); inline;
function RangeContains(const ARanges: array of TCodepointRange; const ACodePoint: TUnicodeCodepoint): Boolean;

implementation

uses
  nextpas.core.text.utf8;

function IsAsciiString(const AValue: string): Boolean;
var
  LIdx: SizeInt;
begin
  for LIdx := 1 to Length(AValue) do
    if Ord(AValue[LIdx]) > $7F then
      Exit(False);
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
