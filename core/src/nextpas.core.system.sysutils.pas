unit nextpas.core.system.sysutils;
{**
 * @desc Minimal SysUtils compatibility facade for proven compiler/bootstrap pressure.
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
function SameText(const ALeft, ARight: string): Boolean;
function IntToStr(const AValue: Int64): string;
function Trim(const AValue: string): string;

implementation

function FoldAsciiLower(const AByte: Byte): Byte; inline;
begin
  case AByte of
    Ord('A')..Ord('Z'): Result := AByte or $20;
  else
    Result := AByte;
  end;
end;

function Format(const AFmt: string; const AArgs: array of const): string;
begin
  Result := nextpas.core.text.conv.Format(AFmt, AArgs);
end;

function SameText(const ALeft, ARight: string): Boolean;
var
  LI, LLength: SizeInt;
begin
  LLength := System.Length(ALeft);
  if LLength <> System.Length(ARight) then
    Exit(False);

  for LI := 1 to LLength do
    if FoldAsciiLower(Byte(ALeft[LI])) <> FoldAsciiLower(Byte(ARight[LI])) then
      Exit(False);

  Result := True;
end;

function IntToStr(const AValue: Int64): string;
begin
  Result := nextpas.core.text.conv.IntToStr(AValue);
end;

function Trim(const AValue: string): string;
begin
  Result := nextpas.core.text.conv.Trim(AValue);
end;

end.
