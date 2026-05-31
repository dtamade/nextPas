unit nextpas.core.text.conv;

{$I nextpas.core.settings.inc}

interface

{**
 * 字符串/数值转换便利函数
 * 内部当前委托 FPC RTL，未来替换为 nextPas 原生实现
 *}

function IntToStr(const AValue: Int64): string; inline;
function UIntToStr(const AValue: UInt64): string; inline;
function FloatToStr(const AValue: Double): string; inline;
function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
function FormatFloat(const AFmt: string; const AValue: Double): string;
function BoolToStr(const AValue: Boolean): string; inline;

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

function Format(const AFmt: string; const AArgs: array of const): string; inline;

function LowerCase(const AStr: string): string; inline;
function UpperCase(const AStr: string): string; inline;
function Trim(const AStr: string): string; inline;
function TrimLeft(const AStr: string): string; inline;
function TrimRight(const AStr: string): string; inline;
function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean = False): string;


function TextOfChar(const ACh: Char; const ACount: Integer): string; inline;
function IntToHex(const AValue: UInt64; const ADigits: Integer): string;
function TryStrToInt32(const AStr: string; out AValue: Integer): Boolean;
function TryStrToUInt64(const AStr: string; out AValue: UInt64): Boolean;

implementation

uses
  nextpas.core.text.number,
  SysUtils;

function IntToStr(const AValue: Int64): string;
begin
  Result := SysUtils.IntToStr(AValue);
end;

function UIntToStr(const AValue: UInt64): string;
begin
  Str(AValue, Result);
end;

function FloatToStr(const AValue: Double): string;
begin
  Result := SysUtils.FloatToStr(AValue);
end;

function FloatToStrF(const AValue: Double; ADecimals: Integer): string;
begin
  Str(AValue:0:ADecimals, Result);
end;

function FormatFloat(const AFmt: string; const AValue: Double): string;
begin
  Result := SysUtils.FormatFloat(AFmt, AValue);
end;

function BoolToStr(const AValue: Boolean): string;
begin
  if AValue then Result := 'true' else Result := 'false';
end;

function StrToInt(const AStr: string): Int64;
begin
  Result := SysUtils.StrToInt64(AStr);
end;

function StrToIntDef(const AStr: string; const ADefault: Int64): Int64;
begin
  Result := SysUtils.StrToInt64Def(AStr, ADefault);
end;

function StrToInt64Def(const AStr: string; const ADefault: Int64): Int64;
begin
  Result := SysUtils.StrToInt64Def(AStr, ADefault);
end;

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer; LTrimmed: string;
begin
  LTrimmed := SysUtils.Trim(AStr);
  Val(LTrimmed, AValue, LCode);
  Result := (LCode = 0);
end;

function TryStrToInt(const AStr: string; out AValue: Integer): Boolean;
var LVal: Int64; LCode: Integer;
begin
  Val(SysUtils.Trim(AStr), LVal, LCode);
  Result := (LCode = 0);
  if Result then AValue := Integer(LVal);
end;

function TryStrToInt64(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer;
begin
  Val(SysUtils.Trim(AStr), AValue, LCode);
  Result := (LCode = 0);
end;

function StrToFloat(const AStr: string): Double;
begin
  Result := SysUtils.StrToFloat(AStr);
end;

function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
begin
  if not SysUtils.TryStrToFloat(AStr, Result) then
    Result := ADefault;
end;

function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;
begin
  Result := SysUtils.TryStrToFloat(AStr, AValue);
end;

function TryStrToFloat(const AStr: string; out AValue: Single): Boolean;
var LDbl: Double;
begin
  Result := SysUtils.TryStrToFloat(AStr, LDbl);
  if Result then AValue := Single(LDbl);
end;

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := SysUtils.Format(AFmt, AArgs);
end;

function LowerCase(const AStr: string): string;
begin
  Result := SysUtils.LowerCase(AStr);
end;

function UpperCase(const AStr: string): string;
begin
  Result := SysUtils.UpperCase(AStr);
end;

function Trim(const AStr: string): string;
begin
  Result := SysUtils.Trim(AStr);
end;

function TrimLeft(const AStr: string): string;
begin
  Result := SysUtils.TrimLeft(AStr);
end;

function TrimRight(const AStr: string): string;
begin
  Result := SysUtils.TrimRight(AStr);
end;

function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean): string;
var LFlags: TReplaceFlags;
begin
  LFlags := [];
  if AAll then LFlags := [rfReplaceAll];
  Result := SysUtils.StringReplace(AStr, AOld, ANew, LFlags);
end;


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

end.
