unit nextpas.core.text;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.text.format;

type
  TStringArray = nextpas.core.text.base.TStringArray;

function TextTrim(const AValue: string): string;
function TextTrimLeft(const AValue: string): string;
function TextTrimRight(const AValue: string): string;

function TextStartsWith(const AValue, APrefix: string): Boolean;
function TextEndsWith(const AValue, ASuffix: string): Boolean;
function TextContains(const AValue, ASubStr: string): Boolean;

function TextSplit(const AValue, ADelimiter: string): TStringArray;
function TextJoin(const AParts: TStringArray; const ASeparator: string): string;

function TextReplace(const AValue, AOld, ANew: string): string;
function TextReplaceAll(const AValue, AOld, ANew: string): string;

function TextToUpper(const AValue: string): string;
function TextToLower(const AValue: string): string;

function TextPadLeft(const AValue: string; const AWidth: Integer; const APadChar: Char = ' '): string;
function TextPadRight(const AValue: string; const AWidth: Integer; const APadChar: Char = ' '): string;

function TextRepeat(const AValue: string; const ACount: Integer): string;

function TextIndexOf(const AValue, ASubStr: string): Integer;
function TextLastIndexOf(const AValue, ASubStr: string): Integer;

function TextIsEmpty(const AValue: string): Boolean;
function TextIsBlank(const AValue: string): Boolean;

function TextUTF8Length(const AValue: string): Integer;
function TextUTF8CodePointAt(const AValue: string; const AIndex: Integer): UInt32;

{ Number conversion (from text.conv) }
function IntToStr(const AValue: Int64): string; inline;
function UIntToStr(const AValue: UInt64): string; inline;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string; inline;
function StrToInt(const AStr: string): Int64; inline;
function TryStrToInt(const AStr: string; out AValue: Int64): Boolean; inline;
function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean; inline;
function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean; inline;
function FloatToStr(const AValue: Double): string; inline;
function TryStrToFloat(const AStr: string; out AValue: Double): Boolean; inline;
function TextOfChar(const ACh: Char; const ACount: Integer): string; inline;

{ Formatting (from text.format) }
function TextFormat(const AFmt: string; const AArgs: array of const): string;

implementation

function MemEqual(const A, B: Pointer; const ASize: SizeUInt): Boolean;
var
  LI: SizeUInt;
  LP, LQ: PByte;
begin
  if ASize = 0 then Exit(True);
  LP := PByte(A);
  LQ := PByte(B);
  for LI := 0 to ASize - 1 do
    if LP[LI] <> LQ[LI] then
      Exit(False);
  Result := True;
end;

{ Trim }

function TextTrim(const AValue: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(AValue);
  while (LStart <= LEnd) and (AValue[LStart] <= ' ') do
    Inc(LStart);
  while (LEnd >= LStart) and (AValue[LEnd] <= ' ') do
    Dec(LEnd);
  Result := Copy(AValue, LStart, LEnd - LStart + 1);
end;

function TextTrimLeft(const AValue: string): string;
var
  LStart: Integer;
begin
  LStart := 1;
  while (LStart <= Length(AValue)) and (AValue[LStart] <= ' ') do
    Inc(LStart);
  Result := Copy(AValue, LStart, Length(AValue) - LStart + 1);
end;

function TextTrimRight(const AValue: string): string;
var
  LEnd: Integer;
begin
  LEnd := Length(AValue);
  while (LEnd >= 1) and (AValue[LEnd] <= ' ') do
    Dec(LEnd);
  Result := Copy(AValue, 1, LEnd);
end;

{ StartsWith / EndsWith / Contains }

function TextStartsWith(const AValue, APrefix: string): Boolean;
var
  LPrefixLen: Integer;
begin
  LPrefixLen := Length(APrefix);
  if LPrefixLen = 0 then
    Exit(True);
  if Length(AValue) < LPrefixLen then
    Exit(False);
  Result := MemEqual(@AValue[1], @APrefix[1], LPrefixLen);
end;

function TextEndsWith(const AValue, ASuffix: string): Boolean;
var
  LSuffixLen, LOffset: Integer;
begin
  LSuffixLen := Length(ASuffix);
  if LSuffixLen = 0 then
    Exit(True);
  if Length(AValue) < LSuffixLen then
    Exit(False);
  LOffset := Length(AValue) - LSuffixLen + 1;
  Result := MemEqual(@AValue[LOffset], @ASuffix[1], LSuffixLen);
end;

function TextContains(const AValue, ASubStr: string): Boolean;
begin
  if Length(ASubStr) = 0 then
    Exit(True);
  Result := Pos(ASubStr, AValue) > 0;
end;

{ Split / Join }

function TextSplit(const AValue, ADelimiter: string): TStringArray;
var
  LPos, LStart, LDelimLen, LCount, LCapacity: Integer;
begin
  Result := nil;
  LDelimLen := Length(ADelimiter);
  if LDelimLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := AValue;
    Exit;
  end;
  LCount := 0;
  LCapacity := 0;
  LStart := 1;
  repeat
    LPos := Pos(ADelimiter, AValue, LStart);
    if LPos = 0 then
      LPos := Length(AValue) + 1;
    if LCount >= LCapacity then
    begin
      if LCapacity = 0 then
        LCapacity := 8
      else
        LCapacity := LCapacity * 2;
      SetLength(Result, LCapacity);
    end;
    Result[LCount] := Copy(AValue, LStart, LPos - LStart);
    Inc(LCount);
    LStart := LPos + LDelimLen;
  until LPos > Length(AValue);
  SetLength(Result, LCount);
end;

function TextJoin(const AParts: TStringArray; const ASeparator: string): string;
var
  LIdx: Integer;
begin
  if Length(AParts) = 0 then
    Exit('');
  Result := AParts[0];
  for LIdx := 1 to High(AParts) do
    Result := Result + ASeparator + AParts[LIdx];
end;

{ Replace }

function TextReplace(const AValue, AOld, ANew: string): string;
var
  LPos: Integer;
begin
  LPos := Pos(AOld, AValue);
  if (LPos = 0) or (Length(AOld) = 0) then
    Exit(AValue);
  Result := Copy(AValue, 1, LPos - 1) + ANew +
            Copy(AValue, LPos + Length(AOld), Length(AValue));
end;

function TextReplaceAll(const AValue, AOld, ANew: string): string;
var
  LPos, LStart, LOldLen: Integer;
begin
  LOldLen := Length(AOld);
  if LOldLen = 0 then
    Exit(AValue);
  Result := '';
  LStart := 1;
  repeat
    LPos := Pos(AOld, AValue, LStart);
    if LPos = 0 then
    begin
      Result := Result + Copy(AValue, LStart, Length(AValue) - LStart + 1);
      Break;
    end;
    Result := Result + Copy(AValue, LStart, LPos - LStart) + ANew;
    LStart := LPos + LOldLen;
  until False;
end;

{ ToUpper / ToLower (ASCII fast path) }

function TextToUpper(const AValue: string): string;
var
  LIdx: Integer;
  LC: Byte;
begin
  SetLength(Result, Length(AValue));
  for LIdx := 1 to Length(AValue) do
  begin
    LC := Byte(AValue[LIdx]);
    if (LC >= Byte('a')) and (LC <= Byte('z')) then
      Result[LIdx] := Char(LC - 32)
    else
      Result[LIdx] := AValue[LIdx];
  end;
end;

function TextToLower(const AValue: string): string;
var
  LIdx: Integer;
  LC: Byte;
begin
  SetLength(Result, Length(AValue));
  for LIdx := 1 to Length(AValue) do
  begin
    LC := Byte(AValue[LIdx]);
    if (LC >= Byte('A')) and (LC <= Byte('Z')) then
      Result[LIdx] := Char(LC + 32)
    else
      Result[LIdx] := AValue[LIdx];
  end;
end;

{ PadLeft / PadRight }

function TextPadLeft(const AValue: string; const AWidth: Integer; const APadChar: Char): string;
var
  LPadCount: Integer;
begin
  LPadCount := AWidth - Length(AValue);
  if LPadCount <= 0 then
    Exit(AValue);
  Result := nextpas.core.text.conv.TextOfChar(APadChar, LPadCount) + AValue;
end;

function TextPadRight(const AValue: string; const AWidth: Integer; const APadChar: Char): string;
var
  LPadCount: Integer;
begin
  LPadCount := AWidth - Length(AValue);
  if LPadCount <= 0 then
    Exit(AValue);
  Result := AValue + nextpas.core.text.conv.TextOfChar(APadChar, LPadCount);
end;

{ Repeat }

function TextRepeat(const AValue: string; const ACount: Integer): string;
var
  LIdx: Integer;
begin
  if ACount <= 0 then
    Exit('');
  Result := '';
  for LIdx := 1 to ACount do
    Result := Result + AValue;
end;

{ IndexOf / LastIndexOf }

function TextIndexOf(const AValue, ASubStr: string): Integer;
begin
  if ASubStr = '' then
    Exit(0);
  Result := Pos(ASubStr, AValue);
  if Result > 0 then
    Dec(Result)
  else
    Result := -1;
end;

function TextLastIndexOf(const AValue, ASubStr: string): Integer;
var
  LPos, LLast, LSubLen: Integer;
begin
  LSubLen := Length(ASubStr);
  if (LSubLen = 0) or (Length(AValue) < LSubLen) then
    Exit(-1);
  LLast := -1;
  LPos := 1;
  repeat
    LPos := Pos(ASubStr, AValue, LPos);
    if LPos = 0 then
      Break;
    LLast := LPos - 1;
    Inc(LPos);
  until False;
  Result := LLast;
end;

{ IsEmpty / IsBlank }

function TextIsEmpty(const AValue: string): Boolean;
begin
  Result := Length(AValue) = 0;
end;

function TextIsBlank(const AValue: string): Boolean;
var
  LIdx: Integer;
begin
  for LIdx := 1 to Length(AValue) do
    if AValue[LIdx] > ' ' then
      Exit(False);
  Result := True;
end;

{ UTF-8 }

function TextUTF8Length(const AValue: string): Integer;
var
  LIdx, LLen: Integer;
  LByte: Byte;
begin
  Result := 0;
  LLen := Length(AValue);
  LIdx := 1;
  while LIdx <= LLen do
  begin
    LByte := Byte(AValue[LIdx]);
    Inc(Result);
    if LByte < $80 then
      Inc(LIdx)
    else if (LByte and $E0) = $C0 then
      Inc(LIdx, 2)
    else if (LByte and $F0) = $E0 then
      Inc(LIdx, 3)
    else
      Inc(LIdx, 4);
  end;
end;

function TextUTF8CodePointAt(const AValue: string; const AIndex: Integer): UInt32;
var
  LIdx, LLen, LCharIdx: Integer;
  LByte: Byte;
begin
  Result := 0;
  LLen := Length(AValue);
  LIdx := 1;
  LCharIdx := 0;
  while LIdx <= LLen do
  begin
    LByte := Byte(AValue[LIdx]);
    if LCharIdx = AIndex then
    begin
      if LByte < $80 then
        Result := LByte
      else if (LByte and $E0) = $C0 then
        Result := ((UInt32(LByte) and $1F) shl 6) or
                  (UInt32(Byte(AValue[LIdx + 1])) and $3F)
      else if (LByte and $F0) = $E0 then
        Result := ((UInt32(LByte) and $0F) shl 12) or
                  ((UInt32(Byte(AValue[LIdx + 1])) and $3F) shl 6) or
                  (UInt32(Byte(AValue[LIdx + 2])) and $3F)
      else
        Result := ((UInt32(LByte) and $07) shl 18) or
                  ((UInt32(Byte(AValue[LIdx + 1])) and $3F) shl 12) or
                  ((UInt32(Byte(AValue[LIdx + 2])) and $3F) shl 6) or
                  (UInt32(Byte(AValue[LIdx + 3])) and $3F);
      Exit;
    end;
    if LByte < $80 then
      Inc(LIdx)
    else if (LByte and $E0) = $C0 then
      Inc(LIdx, 2)
    else if (LByte and $F0) = $E0 then
      Inc(LIdx, 3)
    else
      Inc(LIdx, 4);
    Inc(LCharIdx);
  end;
end;

{ Re-export: conv }

function IntToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function UIntToStr(const AValue: UInt64): string;
begin
  Result := nextpas.core.text.conv.UIntToStr(AValue);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
begin
  Result := nextpas.core.text.conv.IntToHex(AValue, ADigits);
end;

function StrToInt(const AStr: string): Int64;
begin
  Result := nextpas.core.text.conv.StrToInt(AStr);
end;

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
begin
  Result := nextpas.core.text.conv.TryStrToInt(AStr, AValue);
end;

function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
begin
  Result := nextpas.core.text.conv.TryStrToInt32(AStr, AValue);
end;

function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;
begin
  Result := nextpas.core.text.conv.TryStrToUInt64(AStr, AValue);
end;

function FloatToStr(const AValue: Double): string;
begin
  Result := nextpas.core.text.conv.FloatToStr(AValue);
end;

function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
begin
  Result := nextpas.core.text.conv.TryStrToFloat(AStr, AValue);
end;

function TextOfChar(const ACh: Char; const ACount: Integer): string;
begin
  Result := nextpas.core.text.conv.TextOfChar(ACh, ACount);
end;

{ Re-export: format }

function TextFormat(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);
end;

end.
