unit nextpas.core.system.sysutils;
{**
 * @desc Minimal SysUtils compatibility facade for exception formatting.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.compare,
  nextpas.core.text.conv;

type
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;

function Format(const AFmt: string; const AArgs: array of const): string;
function SameText(const ALeft, ARight: string): Boolean;
function IntToStr(const AValue: Int64): string;

implementation

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.conv.Format(AFmt, AArgs);
end;

function SameText(const ALeft, ARight: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextEqualI(ALeft, ARight);
end;

function IntToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

end.
