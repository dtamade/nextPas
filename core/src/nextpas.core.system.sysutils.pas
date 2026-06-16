unit nextpas.core.system.sysutils;
{**
 * @desc Minimal SysUtils compatibility facade for exception formatting,
 *   text conversion helpers, and case-insensitive comparison.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv;

type
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;

function Format(const AFmt: string; const AArgs: array of const): string;
function SameText(const A, B: string): Boolean;
function IntToStr(const AValue: Int64): string;
function Trim(const AStr: string): string;

implementation

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.conv.Format(AFmt, AArgs);
end;

function SameText(const A, B: string): Boolean;
var
  I: SizeInt;
  LLen: SizeInt;
begin
  LLen := Length(A);
  if Length(B) <> LLen then
    Exit(False);
  for I := 1 to LLen do
  begin
    if UpCase(A[I]) <> UpCase(B[I]) then
      Exit(False);
  end;
  Result := True;
end;

function IntToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function Trim(const AStr: string): string;
begin
  Result := nextpas.core.text.conv.Trim(AStr);
end;

end.
