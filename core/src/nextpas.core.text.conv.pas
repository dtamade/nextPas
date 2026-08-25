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

function SameText(const A, B: string): Boolean; inline;

{** Returns the position of the last occurrence of any character from ADelimiters in S.
    Returns 0 if none of the characters are found. }
function LastDelimiter(const ADelimiters: string; const S: string): Integer;

{== Pointer-based conversion ==}
{** NUL-terminated PAnsiChar → string；nil 安全（返回空串）。
    C ABI 字符串读回的统一入口：本工具链上 string(AnsiString(ptr))
    强转在返回托管记录数组的函数内会损坏临时管理（db 家族实证的
    工具链硬边界），消费方一律经本函数而非直接强转。 }
function AnsiPtrToStr(const AStr: PAnsiChar): string;

implementation

uses
  nextpas.core.errors,
  { ASCII SameText only — do not pull text.compare (unicode.casefold/normalize). }
  nextpas.core.text.char,
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
  C: Char;
begin
  Str(AValue:0:15, Result);
  { Find the decimal separator (could be '.' or ',' depending on locale) }
  LDot := 0;
  for LI := 1 to Length(Result) do
    if Result[LI] in ['.', ','] then
    begin
      LDot := LI;
      Break;
    end;
  if LDot > 0 then
  begin
    C := Result[LDot];
    LI := Length(Result);
    while (LI > LDot) and (Result[LI] = '0') do
      Dec(LI);
    if LI = LDot then
      SetLength(Result, LDot - 1)
    else
      SetLength(Result, LI);
    { Normalize to '.' for locale-independent output }
    if C <> '.' then
    begin
      LDot := Pos(C, Result);
      if LDot > 0 then
        Result[LDot] := '.';
    end;
  end;
end;

function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
var I: Integer;
begin
  Str(AValue:0:ADecimals, Result);
  { Normalize decimal separator to '.' }
  for I := 1 to Length(Result) do
    if Result[I] = ',' then
    begin
      Result[I] := '.';
      Break;
    end;
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
  { Normalize decimal separator to '.' }
  for LI := 1 to Length(Result) do
    if Result[LI] = ',' then
    begin
      Result[LI] := '.';
      Break;
    end;
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
  { Int64 解析成功还不够: 超出 Int32 值域必须报失败,
    否则截断回绕把 "4294967297" 静默变 1, 下游范围校验被穿透 }
  Result := (LCode = 0)
    and (LVal >= Low(Integer)) and (LVal <= High(Integer));
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

{** @note ASCII case-fold only (matches LowerCase/UpperCase stance on this unit).
    Unicode-aware equality lives in text.compare (UTF8CaseFoldSimple path). *}
function SameText(const A, B: string): Boolean;
var
  I, LenA, LenB: SizeInt;
begin
  LenA := Length(A);
  LenB := Length(B);
  if LenA <> LenB then
    Exit(False);
  for I := 1 to LenA do
    if ToLower(Byte(A[I])) <> ToLower(Byte(B[I])) then
      Exit(False);
  Result := True;
end;

function LastDelimiter(const ADelimiters: string; const S: string): Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := Length(S) downto 1 do
    for J := 1 to Length(ADelimiters) do
      if S[I] = ADelimiters[J] then
        Exit(I);
end;

function AnsiPtrToStr(const AStr: PAnsiChar): string;
var
  LP: PAnsiChar;
  LLen: Integer;
begin
  Result := '';
  if AStr = nil then
    Exit;
  LP := AStr;
  while LP^ <> #0 do
    Inc(LP);
  LLen := Integer(LP - AStr);
  if LLen = 0 then
    Exit;
  SetLength(Result, LLen);
  Move(AStr^, Result[1], SizeUInt(LLen));
end;

end.
