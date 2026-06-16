unit nextpas.core.text;
{**
 * @desc nextpas.core.text 的 UTF-8 门面。
 *
 * 该门面聚合最常用的字符串操作、格式化、视图、Builder、Unicode 比较、
 * JSON 转义、grapheme 宽度与规范化助手，方便大多数消费者只 `uses
 * nextpas.core.text` 即可完成常见文本工作。
 *
 * 范围原则：
 *   - 常用高层文本能力通过类型别名与 inline forward 暴露。
 *   - 低层、指针导向或批量处理 API（如 scan/property 细粒度表）仍留在
 *     对应子模块，避免门面膨胀。
 *   - 需要完整 Unicode/property surface 时，直接引用
 *     nextpas.core.text.unicode 或其子模块。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.text.builder,
  nextpas.core.text.compare,
  nextpas.core.text.conv,
  nextpas.core.text.escape,
  nextpas.core.text.format,
  nextpas.core.text.grapheme,
  nextpas.core.text.strings,
  nextpas.core.text.unicode,
  nextpas.core.text.utf8,
  nextpas.core.text.utils,
  nextpas.core.text.view,
  nextpas.core.text.width;

type
  TStringArray = nextpas.core.text.base.TStringArray;
  IStringBuilder = nextpas.core.text.builder.IStringBuilder;
  TStringView = nextpas.core.text.view.TStringView;
  TUnescapeError = nextpas.core.text.escape.TUnescapeError;
  TGraphemeResult = nextpas.core.text.grapheme.TGraphemeResult;

const
  ueNone = nextpas.core.text.escape.ueNone;
  ueInvalidEscape = nextpas.core.text.escape.ueInvalidEscape;
  ueInvalidUnicode = nextpas.core.text.escape.ueInvalidUnicode;
  ueTruncated = nextpas.core.text.escape.ueTruncated;

function TextTrim(const AValue: string): string; inline;
function TextTrimLeft(const AValue: string): string; inline;
function TextTrimRight(const AValue: string): string; inline;

function TextStartsWith(const AValue, APrefix: string): Boolean; inline;
function TextEndsWith(const AValue, ASuffix: string): Boolean; inline;
function TextContains(const AValue, ASubStr: string): Boolean; inline;
function TextEqualCanonical(const AValue, AOther: string): Boolean; inline;
function TextEqualCaseFold(const AValue, AOther: string): Boolean; inline;

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
function MakeStringBuilder(const AInitialCap: SizeUInt = 256): IStringBuilder; inline;

{ Builder / escape / display width / grapheme helpers }
function JsonEscapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar): SizeUInt; inline;
function JsonUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt; inline;
function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult; inline;
function CodepointWidth(const ACodePoint: UInt32): Byte; inline;
function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt; overload; inline;
function StringDisplayWidth(const AStr: AnsiString): SizeUInt; overload; inline;

{ Common UTF-8 Unicode helpers (full property surface stays in text.unicode) }
function UTF8ToUpper(const AValue: string): string; inline;
function UTF8ToLower(const AValue: string): string; inline;
function UTF8CaseFold(const AValue: string): string; inline;
function NFD(const AValue: string): string; inline;
function NFC(const AValue: string): string; inline;
function IsNormalizedNFC(const AValue: string): Boolean; inline;

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

function TextEqualCanonical(const AValue, AOther: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextEqualCanonical(AValue, AOther);
end;

function TextEqualCaseFold(const AValue, AOther: string): Boolean;
begin
  Result := nextpas.core.text.compare.TextEqualCaseFold(AValue, AOther);
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
  Result := nextpas.core.text.utils.StringReplace(AValue, AOld, ANew, False);
end;

function TextReplaceAll(const AValue, AOld, ANew: string): string;
begin
  Result := nextpas.core.text.utils.StringReplace(AValue, AOld, ANew, True);
end;

function TextToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.UTF8ToUpper(AValue);
end;

function TextToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.UTF8ToLower(AValue);
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

function MakeStringBuilder(const AInitialCap: SizeUInt): IStringBuilder;
begin
  Result := nextpas.core.text.builder.MakeStringBuilder(AInitialCap);
end;

function JsonEscapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar): SizeUInt;
begin
  Result := nextpas.core.text.escape.JsonEscapeToBuffer(ASrc, ALen, ADst);
end;

function JsonUnescapeToBuffer(const ASrc: PAnsiChar; const ALen: SizeUInt;
  const ADst: PAnsiChar; out AError: TUnescapeError): SizeUInt;
begin
  Result := nextpas.core.text.escape.JsonUnescapeToBuffer(ASrc, ALen, ADst, AError);
end;

function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult;
begin
  Result := nextpas.core.text.grapheme.GraphemeNext(AData, ALen);
end;

function CodepointWidth(const ACodePoint: UInt32): Byte;
begin
  Result := nextpas.core.text.width.CodepointWidth(ACodePoint);
end;

function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.text.width.StringDisplayWidth(AData, ALen);
end;

function StringDisplayWidth(const AStr: AnsiString): SizeUInt;
begin
  Result := nextpas.core.text.width.StringDisplayWidth(AStr);
end;

function UTF8ToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.UTF8ToUpper(AValue);
end;

function UTF8ToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.UTF8ToLower(AValue);
end;

function UTF8CaseFold(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.UTF8CaseFold(AValue);
end;

function NFD(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.NFD(AValue);
end;

function NFC(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.NFC(AValue);
end;

function IsNormalizedNFC(const AValue: string): Boolean;
begin
  Result := nextpas.core.text.unicode.IsNormalizedNFC(AValue);
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
