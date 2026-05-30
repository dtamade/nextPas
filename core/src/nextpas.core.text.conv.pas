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
function BoolToStr(const AValue: Boolean): string; inline;

function StrToInt(const AStr: string): Int64; inline;
function StrToIntDef(const AStr: string; const ADefault: Int64): Int64; inline;
function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
function StrToFloat(const AStr: string): Double; inline;
function StrToFloatDef(const AStr: string; const ADefault: Double): Double;
function TryStrToFloat(const AStr: string; out AValue: Double): Boolean;

function Format(const AFmt: string; const AArgs: array of const): string; inline;

function LowerCase(const AStr: string): string; inline;
function UpperCase(const AStr: string): string; inline;
function Trim(const AStr: string): string; inline;
function TrimLeft(const AStr: string): string; inline;
function TrimRight(const AStr: string): string; inline;
function StringReplace(const AStr, AOld, ANew: string; AAll: Boolean = False): string;

implementation

uses
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

function TryStrToInt(const AStr: string; out AValue: Int64): Boolean;
var LCode: Integer;
begin
  Val(AStr, AValue, LCode);
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

end.
