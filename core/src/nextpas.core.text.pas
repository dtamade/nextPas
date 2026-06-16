unit nextpas.core.text;
{**
 * @desc 字符串操作门面：Unicode、格式化、转换、Builder。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.text.compare,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.text.strings,
  nextpas.core.text.utf8,
  nextpas.core.text.utils,
  nextpas.core.text.view;

type
  TStringArray = nextpas.core.text.base.TStringArray;

function TextTrim(const AValue: string): string; inline;
function TextTrimLeft(const AValue: string): string; inline;
function TextTrimRight(const AValue: string): string; inline;

function TextStartsWith(const AValue, APrefix: string): Boolean; inline;
function TextEndsWith(const AValue, ASuffix: string): Boolean; inline;
function TextContains(const AValue, ASubStr: string): Boolean; inline;

function TextSplit(const AValue, ADelimiter: string): TStringArray; inline;
function TextJoin(const AParts: TStringArray; const ASeparator: string): string; inline;

function TextReplace(const AValue, AOld, ANew: string): string; inline;
function TextReplaceAll(const AValue, AOld, ANew: string): string; inline;

function TextToUpper(const AValue: string): string; inline;
function TextToLower(const AValue: string): string; inline;

function TextPadLeft(const AValue: string; const AWidth: Integer; const APadChar: Char = ' '): string; inline;
function TextPadRight(const AValue: string; const AWidth: Integer; const APadChar: Char = ' '): string; inline;

function TextRepeat(const AValue: string; const ACount: Integer): string; inline;

function TextIndexOf(const AValue, ASubStr: string): Integer; inline;
function TextLastIndexOf(const AValue, ASubStr: string): Integer; inline;

function TextIsEmpty(const AValue: string): Boolean; inline;
function TextIsBlank(const AValue: string): Boolean; inline;

function TextUTF8Length(const AValue: string): Integer; inline;
function TextUTF8CodePointAt(const AValue: string; const AIndex: Integer): UInt32; inline;

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
function TextFormat(const AFmt: string; const AArgs: array of const): string; inline;

{ Case-insensitive ASCII comparison (from text.conv) }
function SameText(const A, B: string): Boolean; inline;

implementation

function TextTrim(const AValue: string): string;
begin
  Result := nextpas.core.text.utils.Trim(AValue);
end;

function TextTrimLeft(const AValue: string): string;
begin
  Result := nextpas.core.text.utils.TrimLeft(AValue);
end;

function TextTrimRight(const AValue: string): string;
begin
  Result := nextpas.core.text.utils.TrimRight(AValue);
end;

function TextStartsWith(const AValue, APrefix: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextStartsWith(AValue, APrefix);
end;

function TextEndsWith(const AValue, ASuffix: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextEndsWith(AValue, ASuffix);
end;

function TextContains(const AValue, ASubStr: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextContains(AValue, ASubStr);
end;

function TextSplit(const AValue, ADelimiter: string): TStringArray;
begin
  Result := nextpas.core.text.strings.StringsSplit(AValue, ADelimiter);
end;

function TextJoin(const AParts: TStringArray; const ASeparator: string): string;
begin
  Result := nextpas.core.text.strings.StringsJoin(AParts, ASeparator);
end;

function TextReplace(const AValue, AOld, ANew: string): string;
begin
  Result := nextpas.core.text.conv.StringReplace(AValue, AOld, ANew, False);
end;

function TextReplaceAll(const AValue, AOld, ANew: string): string;
begin
  Result := nextpas.core.text.conv.StringReplace(AValue, AOld, ANew, True);
end;

function TextToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.conv.UpperCase(AValue);
end;

function TextToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.conv.LowerCase(AValue);
end;

function TextPadLeft(const AValue: string; const AWidth: Integer; const APadChar: Char): string;
begin
  Result := nextpas.core.text.utils.PadLeft(AValue, AWidth, APadChar);
end;

function TextPadRight(const AValue: string; const AWidth: Integer; const APadChar: Char): string;
begin
  Result := nextpas.core.text.utils.PadRight(AValue, AWidth, APadChar);
end;

function TextRepeat(const AValue: string; const ACount: Integer): string;
begin
  Result := nextpas.core.text.utils.RepeatString(AValue, ACount);
end;

function TextIndexOf(const AValue, ASubStr: string): Integer;
begin
  Result := Integer(nextpas.core.text.view.IndexOfStr(AValue, ASubStr));
end;

function TextLastIndexOf(const AValue, ASubStr: string): Integer;
begin
  Result := Integer(nextpas.core.text.view.LastIndexOfStr(AValue, ASubStr));
end;

function TextIsEmpty(const AValue: string): Boolean;
begin
  Result := nextpas.core.text.utils.IsEmpty(AValue);
end;

function TextIsBlank(const AValue: string): Boolean;
begin
  Result := nextpas.core.text.utils.IsBlank(AValue);
end;

function TextUTF8Length(const AValue: string): Integer;
begin
  Result := Integer(nextpas.core.text.utf8.UTF8Length(AValue));
end;

function TextUTF8CodePointAt(const AValue: string; const AIndex: Integer): UInt32;
begin
  Result := nextpas.core.text.utf8.UTF8CodePointAt(AValue, AIndex);
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

{ Re-export: SameText }

function SameText(const A, B: string): Boolean;
begin
  Result := nextpas.core.text.conv.SameText(A, B);
end;

end.
