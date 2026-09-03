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

function JsonEscape(const AValue: string): string;
function EscapeLlvmStr(const AValue: string): string;

{== Encoding - byte<->string conversions == single source is bytes.ops (zero-copy Move) ==}
{ UTF8 pair is the encoding-intent facade; ASCII pair is subset alias - deprecated. }
function UTF8BytesToString(const AData: TBytes): string; inline;
function StringToUTF8Bytes(const AStr: string): TBytes; inline;
function ASCIIBytesToString(const AData: TBytes): string; inline; deprecated 'Use UTF8BytesToString - ASCII is UTF8 subset, single source bytes.ops.BytesToString';
function StringToASCIIBytes(const AStr: string): TBytes; inline; deprecated 'Use StringToUTF8Bytes - ASCII is UTF8 subset, single source bytes.ops.StringToBytes';
function BigEndianUnicodeBytesToString(const AData: TBytes): string;

function SameText(const A, B: string): Boolean;

{** Returns the position of the last occurrence of any character from ADelimiters in S.
    Returns 0 if none of the characters are found. }
function LastDelimiter(const ADelimiters: string; const S: string): Integer;

{== Variant helpers — text/convert normalization point, single source via bytes.ops (INV-5)
    perf: inline thin forward to bytes.ops (zero-copy TVarData view, masked varTypeMask), no alloc }
function VarType(const V: Variant): Word; inline;
function VarIsNull(const V: Variant): Boolean; inline;
function VarIsEmpty(const V: Variant): Boolean; inline;
function VarIsClear(const V: Variant): Boolean; inline;

{== Pointer-based conversion ==}
{** NUL-terminated PAnsiChar → string；nil 安全（返回空串）。
    C ABI 字符串读回的统一入口：本工具链上 string(AnsiString(ptr))
    强转在返回托管记录数组的函数内会损坏临时管理（db 家族实证的
    工具链硬边界），消费方一律经本函数而非直接强转。
    perf: inline thin forward to bytes.ops.AnsiPtrToString (single source zero-copy Move) }
function AnsiPtrToStr(const AStr: PAnsiChar): string; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  { ASCII SameText only - do not pull text.compare (unicode.casefold/normalize). }
  nextpas.core.text.builder,
  nextpas.core.text.char,
  nextpas.core.text.escape,
  nextpas.core.text.format,
  nextpas.core.text.number,
  nextpas.core.text.utils,
  nextpas.core.text.view;

{== Integer/String conversion - uses System.Str/Val ==}

function IntToStr(const AValue: Int64): string;
begin
  Str(AValue, Result);
end;

function UIntToStr(const AValue: UInt64): string;
begin
  Str(AValue, Result);
end;

{== Float/String conversion ==}
{ perf: inline thin forward to text.number zero-alloc buffer; single SetLength+Move, O(n), locale-independent '.' }

function FloatToStr(const AValue: Double): string; inline;
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  LLen := nextpas.core.text.number.FloatToBuffer(AValue, @LBuf[0]);
  SetLength(Result, LLen);
  if LLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(Pointer(Result), @LBuf[0], SizeUInt(LLen)); // perf: inline single Move via bytes.ops single source (zero-copy), single SetLength+BytesCopy, no locale
end;

function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  { perf: owner text.number FloatToFixedBuffer zero-alloc, single BytesCopy via bytes.ops single source, no locale scan }
  if ADecimals < 0 then ADecimals := 0 else if ADecimals > 18 then ADecimals := 18;
  LLen := nextpas.core.text.number.FloatToFixedBuffer(AValue, Int32(ADecimals), @LBuf[0]);
  SetLength(Result, LLen);
  if LLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(Pointer(Result), @LBuf[0], SizeUInt(LLen)); // perf: inline single Move via bytes.ops single source (zero-copy)
end;

function FormatFloat(const AFmt: string; const AValue: Double): string;
var
  LDecimals, LI: Integer;
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  LDecimals := 0;
  LI := Pos('.', AFmt);
  if LI > 0 then
    while (LI + LDecimals + 1 <= Length(AFmt)) and
          (AFmt[LI + LDecimals + 1] in ['0', '#']) do
      Inc(LDecimals);
  { perf: owner text.number FloatToFixedBuffer zero-alloc, single BytesCopy via bytes.ops single source, no Delete O(n²), no locale ',' scan }
  if LDecimals > 0 then
    LLen := nextpas.core.text.number.FloatToFixedBuffer(AValue, Int32(LDecimals), @LBuf[0])
  else
    LLen := nextpas.core.text.number.FloatToFixedBuffer(AValue, 2, @LBuf[0]);
  SetLength(Result, LLen);
  if LLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(Pointer(Result), @LBuf[0], SizeUInt(LLen)); // perf: inline single Move via bytes.ops single source (zero-copy)
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

function IntToHex(const AValue: UInt64; const ADigits: Integer): string; inline;
var LBuf: array[0..31] of AnsiChar; LLen: Int32;
begin
  { perf: direct uppercase HEX_CHARS_UPPER via IntToHexBufferUpper, single BytesCopy via bytes.ops single source (zero-copy), O(n) without second branch scan }
  LLen := nextpas.core.text.number.IntToHexBufferUpper(AValue, @LBuf[0], ADigits);
  SetLength(Result, LLen);
  if LLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(Pointer(Result), @LBuf[0], SizeUInt(LLen)); // perf: inline single Move via bytes.ops single source (zero-copy)
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

function JsonEscape(const AValue: string): string;
var
  LBuilder: TStringBuilder;
  LView: TStringView;
begin
  Result := '';
  if AValue = '' then
    Exit;
  LView := TStringView.Create(PAnsiChar(AValue), Length(AValue));
  LBuilder.Init(Length(AValue));
  try
    nextpas.core.text.escape.JsonEscapeToBuilder(LView, LBuilder);
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function EscapeLlvmStr(const AValue: string): string;
var
  LBuilder: TStringBuilder;
  I: SizeInt;
  C: Byte;
const
  Hex: array[0..15] of AnsiChar = '0123456789abcdef';
begin
  Result := '';
  if AValue = '' then
    Exit;
  LBuilder.Init(Length(AValue) * 3);
  try
    for I := 1 to Length(AValue) do
    begin
      C := Byte(AValue[I]);
      if (C < 32) or (C > 126) or (C = 34) or (C = 92) then
      begin
        LBuilder.AppendChar('\');
        LBuilder.AppendChar(Hex[C shr 4]);
        LBuilder.AppendChar(Hex[C and $F]);
      end
      else
        LBuilder.AppendChar(AnsiChar(C));
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

{== Encoding - byte<->string conversions ==}

function UTF8BytesToString(const AData: TBytes): string; inline;
begin
  { perf: inline thin forward to bytes.ops.BytesToString single source (zero-copy TByteSpan view, single Move in owner); facades no duplicate Move }
  Result := nextpas.core.bytes.ops.BytesToString(AData);
end;

function StringToUTF8Bytes(const AStr: string): TBytes; inline;
begin
  { perf: inline thin forward to bytes.ops.StringToBytes single source (zero-copy PAnsiChar(AText)^ Move, single SetLength+Move in owner); alloc not inline in owner per red-line 1 }
  Result := nextpas.core.bytes.ops.StringToBytes(AStr);
end;

function ASCIIBytesToString(const AData: TBytes): string; inline;
begin
  Result := UTF8BytesToString(AData);
end;

function StringToASCIIBytes(const AStr: string): TBytes; inline;
begin
  Result := StringToUTF8Bytes(AStr);
end;

function BigEndianUnicodeBytesToString(const AData: TBytes): string; inline;
begin
  { perf: inline thin forward to bytes.ops single source (zero-copy WideChar view); not inline red-line 2 kept in owner }
  Result := nextpas.core.bytes.ops.BigEndianUnicodeBytesToString(AData);
end;

{** @note ASCII case-fold only (matches LowerCase/UpperCase stance on this unit).
    Unicode-aware equality lives in text.compare (UTF8CaseFoldSimple path).
    perf: not inline per red-line 2; single source bytes.ops SpanEqualIgnoreCase zero-copy TByteSpan view }
function SameText(const A, B: string): Boolean;
var
  LA, LB: TByteSpan;
begin
  if Length(A) = 0 then
    LA := TByteSpan.Empty
  else
    LA := TByteSpan.Create(PByte(PAnsiChar(A)), SizeUInt(Length(A)));
  if Length(B) = 0 then
    LB := TByteSpan.Empty
  else
    LB := TByteSpan.Create(PByte(PAnsiChar(B)), SizeUInt(Length(B)));
  Result := nextpas.core.bytes.ops.SpanEqualIgnoreCase(LA, LB);
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

function VarType(const V: Variant): Word; inline;
begin
  { perf: inline thin forward to bytes.ops single source (zero-copy TVarData view, masked), no alloc }
  Result := nextpas.core.bytes.ops.VarType(V);
end;

function VarIsNull(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.VarIsNull(V);
end;

function VarIsEmpty(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.VarIsEmpty(V);
end;

function VarIsClear(const V: Variant): Boolean; inline;
begin
  Result := nextpas.core.bytes.ops.VarIsClear(V);
end;

function AnsiPtrToStr(const AStr: PAnsiChar): string; inline;
begin
  { perf: inline thin forward to bytes.ops.AnsiPtrToString (single source zero-copy Move Pointer(Result)^); not inline kept in owner }
  Result := nextpas.core.bytes.ops.AnsiPtrToString(AStr);
end;

end.
