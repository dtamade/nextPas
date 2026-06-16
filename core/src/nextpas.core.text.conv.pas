unit nextpas.core.text.conv;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function IntToStr(const AValue: Int64): string; inline;
function UIntToStr(const AValue: UInt64): string; inline;
function FloatToStr(const AValue: Double): string; inline;
function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
function FormatFloat(const AFmt: string; const AValue: Double): string;
function BoolToStr(const AValue: Boolean): string; inline;
function BoolToStr(const AValue: Boolean; const ATrueStr: string;
  const AFalseStr: string): string; inline; overload;

function StrToInt(const AStr: string): Int64; inline;
function StrToIntDef(const AStr: string; const ADefault: Int64): Int64; inline;
function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64; inline;
function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean; inline;
function StrToFloat(const AStr: string): Double; inline;
function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
function TryStrToFloat(const AStr: string; out AValue: Single): Boolean;

function Format(const AFmt: string; const AArgs: array of const): string; deprecated 'Use nextpas.core.text.format.TextFormat or nextpas.core.text.TextFormat';

{** @note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode. *}
function LowerCase(const AStr: string): string;
{** @note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode. *}
function UpperCase(const AStr: string): string;
function Trim(const AStr: string): string;
function TrimLeft(const AStr: string): string;
function TrimRight(const AStr: string): string;
function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean = False): string;

function TextOfChar(const ACh: Char; const ACount: Integer): string; inline;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;

{== Encoding — byte<->string conversions ==}
function UTF8BytesToString(const AData: TBytes): string;
function StringToUTF8Bytes(const AStr: string): TBytes;
function ASCIIBytesToString(const AData: TBytes): string;
function StringToASCIIBytes(const AStr: string): TBytes;
function BigEndianUnicodeBytesToString(const AData: TBytes): string;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.format,
  nextpas.core.text.number,
  nextpas.core.text.utils;

{== Integer/String conversion — uses System.Str/Val ==}

function IntToStr(const AValue: Int64): string;
begin
  Str(AValue, Result);
end;

function UIntToStr(const AValue: UInt64): string;
begin
  Str(AValue, Result);
end;

{== Float/String conversion ==}

function FloatToStr(const AValue: Double): string;
var LI, LDot: Integer;
begin
  Str(AValue:0:15, Result);
  LDot := Pos('.', Result);
  if LDot > 0 then
  begin
    LI := Length(Result);
    while (LI > LDot) and (Result[LI] = '0') do
      Dec(LI);
    if LI = LDot then
      SetLength(Result, LDot - 1)
    else
      SetLength(Result, LI);
  end;
end;

function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
begin
  Str(AValue:0:ADecimals, Result);
end;

function FormatFloat(const AFmt: string; const AValue: Double): string;
var LDecimals, LI: Integer;
begin
  LDecimals := 0;
  LI := Pos('.', AFmt);
  if LI > 0 then
    while (LI + LDecimals + 1 <= Length(AFmt)) and
          (AFmt[LI + LDecimals + 1] in ['0', '#']) do
      Inc(LDecimals);
  if LDecimals > 0 then
    Str(AValue:0:LDecimals, Result)
  else
    Str(AValue:0:2, Result);
  while (Length(Result) > 0) and (Result[1] = ' ') do
    Delete(Result, 1, 1);
end;

function BoolToStr(const AValue: Boolean): string;
begin
  Result := nextpas.core.text.utils.BoolToStr(AValue);
end;

function BoolToStr(const AValue: Boolean; const ATrueStr: string;
  const AFalseStr: string): string;
begin
  Result := nextpas.core.text.utils.BoolToStr(AValue, ATrueStr, AFalseStr);
end;

{== String to number ==}

procedure RaiseInvalidIntegerValue(const AStr: string);
begin
  raise EConvertError.CreateFmt('Invalid integer value: "%s"', [AStr]);
end;

procedure RaiseInvalidFloatValue(const AStr: string);
begin
  raise EConvertError.CreateFmt('Invalid floating-point value: "%s"', [AStr]);
end;

function StrToInt(const AStr: string): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    RaiseInvalidIntegerValue(AStr);
end;

function StrToIntDef(const AStr: string; const ADefault: Int64): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
var
  LStart: SizeInt;
  LStop: SizeInt;
begin
  LStart := 1;
  LStop := Length(AStr);
  while (LStart <= LStop) and (AStr[LStart] <= ' ') do
    Inc(LStart);
  while (LStop >= LStart) and (AStr[LStop] <= ' ') do
    Dec(LStop);

  if LStart > LStop then
  begin
    AValue := 0;
    Exit(False);
  end;

  Result := ParseInt64(@AStr[LStart], LStop - LStart + 1, AValue);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
var LVal: Int64; LCode: Integer;
begin
  Val(AStr, LVal, LCode);
  Result := (LCode = 0);
  if Result then AValue := Integer(LVal);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer;
begin
  Val(AStr, AValue, LCode);
  Result := (LCode = 0);
end;

function StrToFloat(const AStr: string): Double;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    RaiseInvalidFloatValue(AStr);
end;

function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
var LCode: Integer;
begin
  Val(AStr, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
var
  LStart: SizeInt;
  LStop: SizeInt;
begin
  LStart := 1;
  LStop := Length(AStr);
  while (LStart <= LStop) and (AStr[LStart] <= ' ') do
    Inc(LStart);
  while (LStop >= LStart) and (AStr[LStop] <= ' ') do
    Dec(LStop);

  if LStart > LStop then
  begin
    AValue := 0.0;
    Exit(False);
  end;

  Result := ParseDouble(@AStr[LStart], LStop - LStart + 1, AValue);
end;

function TryStrToFloat(const AStr: string; out AValue: Single): Boolean;
var LDbl: Double; LCode: Integer;
begin
  Val(AStr, LDbl, LCode);
  Result := (LCode = 0);
  if Result then AValue := Single(LDbl);
end;

{== Format compatibility entrypoint ==}

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.format.TextFormat(AFmt, AArgs);
end;

{== String manipulation ==}

function LowerCase(const AStr: string): string;
begin
  Result := nextpas.core.text.utils.LowerCase(AStr);
end;

function UpperCase(const AStr: string): string;
begin
  Result := nextpas.core.text.utils.UpperCase(AStr);
end;

function Trim(const AStr: string): string;
begin
  Result := nextpas.core.text.utils.Trim(AStr);
end;

function TrimLeft(const AStr: string): string;
begin
  Result := nextpas.core.text.utils.TrimLeft(AStr);
end;

function TrimRight(const AStr: string): string;
begin
  Result := nextpas.core.text.utils.TrimRight(AStr);
end;

function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean): string;
begin
  Result := nextpas.core.text.utils.StringReplace(AStr, AOld, ANew, AAll);
end;

{== Misc ==}

function TextOfChar(const ACh: Char; const ACount: Integer): string;
begin
  Result := StringOfChar(ACh, ACount);
end;

function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
var LBuf: array[0..31] of AnsiChar; LLen, I: Int32;
begin
  LLen := nextpas.core.text.number.IntToHexBuffer(AValue, @LBuf[0], ADigits);
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    if (LBuf[I] >= 'a') and (LBuf[I] <= 'f') then
      Result[I + 1] := Chr(Ord(LBuf[I]) - 32)
    else
      Result[I + 1] := LBuf[I];
end;

function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
var LCode: Integer; LVal: Int32;
begin
  Val(AStr, LVal, LCode);
  AValue := LVal;
  Result := LCode = 0;
end;

function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;
var LCode: Integer;
begin
  Val(AStr, AValue, LCode);
  Result := LCode = 0;
end;

{== Encoding — byte<->string conversions ==}

function UTF8BytesToString(const AData: TBytes): string;
var
  LUTF8: RawByteString;
begin
  Result := '';
  if Length(AData) = 0 then
    Exit;
  SetLength(LUTF8, Length(AData));
  Move(AData[0], LUTF8[1], Length(AData));
  SetCodePage(LUTF8, CP_UTF8, False);
  Result := string(UTF8String(LUTF8));
end;

function StringToUTF8Bytes(const AStr: string): TBytes;
var
  LUTF8: UTF8String;
  LLen: SizeInt;
begin
  Result := nil;
  LUTF8 := UTF8String(AStr);
  LLen := Length(LUTF8);
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(LUTF8[1], Result[0], LLen);
end;

function ASCIIBytesToString(const AData: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function StringToASCIIBytes(const AStr: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AStr));
  if Length(AStr) > 0 then
    Move(AStr[1], Result[0], Length(AStr));
end;

function BigEndianUnicodeBytesToString(const AData: TBytes): string;
var
  I, LCount: SizeInt;
  LWChars: array of WideChar;
begin
  Result := '';
  LCount := Length(AData) div 2;
  if LCount = 0 then Exit;
  SetLength(LWChars, LCount);
  for I := 0 to LCount - 1 do
    LWChars[I] := WideChar((UInt16(AData[I * 2]) shl 8) or AData[I * 2 + 1]);
  SetString(Result, PWideChar(LWChars), LCount);
end;

end.
