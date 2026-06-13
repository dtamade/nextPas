unit nextpas.core.text.unicode.props;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.base;

function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean; inline;
function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory; inline;
function IsUpper(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsLower(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsAlpha(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsDigit(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsWhitespace(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsControl(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsLetter(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsMark(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsNumber(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsPunctuation(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsSymbol(const ACp: TUnicodeCodepoint): Boolean; inline;
function IsSeparator(const ACp: TUnicodeCodepoint): Boolean; inline;
function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;

implementation

uses
  nextpas.core.text.char;

const
  LETTER_CATEGORIES: TGeneralCategorySet = [
    gcuUppercaseLetter,
    gcuLowercaseLetter,
    gcuTitlecaseLetter,
    gcuModifierLetter,
    gcuOtherLetter
  ];

  MARK_CATEGORIES: TGeneralCategorySet = [
    gcuNonspacingMark,
    gcuSpacingMark,
    gcuEnclosingMark
  ];

  NUMBER_CATEGORIES: TGeneralCategorySet = [
    gcuDecimalNumber,
    gcuLetterNumber,
    gcuOtherNumber
  ];

  PUNCTUATION_CATEGORIES: TGeneralCategorySet = [
    gcuConnectorPunctuation,
    gcuDashPunctuation,
    gcuOpenPunctuation,
    gcuClosePunctuation,
    gcuInitialPunctuation,
    gcuFinalPunctuation,
    gcuOtherPunctuation
  ];

  SYMBOL_CATEGORIES: TGeneralCategorySet = [
    gcuMathSymbol,
    gcuCurrencySymbol,
    gcuModifierSymbol,
    gcuOtherSymbol
  ];

  SEPARATOR_CATEGORIES: TGeneralCategorySet = [
    gcuSpaceSeparator,
    gcuLineSeparator,
    gcuParagraphSeparator
  ];

{$I nextpas.core.text.unicode.data.inc}
{$I nextpas.core.text.unicode.props.inc}

function GetAsciiGeneralCategory(const ACp: Byte): TGeneralCategory; inline;
begin
  case ACp of
    0..31, 127:
      Result := gcuControl;
    32:
      Result := gcuSpaceSeparator;
    Ord('$'):
      Result := gcuCurrencySymbol;
    Ord('('), Ord('['), Ord('{'):
      Result := gcuOpenPunctuation;
    Ord(')'), Ord(']'), Ord('}'):
      Result := gcuClosePunctuation;
    Ord('+'), Ord('<'), Ord('='), Ord('>'), Ord('|'), Ord('~'):
      Result := gcuMathSymbol;
    Ord('-'):
      Result := gcuDashPunctuation;
    Ord('^'), Ord('`'):
      Result := gcuModifierSymbol;
    Ord('_'):
      Result := gcuConnectorPunctuation;
    Ord('0')..Ord('9'):
      Result := gcuDecimalNumber;
    Ord('A')..Ord('Z'):
      Result := gcuUppercaseLetter;
    Ord('a')..Ord('z'):
      Result := gcuLowercaseLetter;
  else
    Result := gcuOtherPunctuation;
  end;
end;

function ContainsRange2(const ACp: TUnicodeCodepoint; const ARanges: array of TCodepointRange2): Boolean;
begin
  Result := FindRange2(ACp, ARanges) >= 0;
end;

function ApplyDelta(const ACp: TUnicodeCodepoint; const ADelta: Int32): TUnicodeCodepoint; inline;
begin
  Result := TUnicodeCodepoint(Int64(ACp) + ADelta);
end;

function ApplySimpleMap(const ACp: TUnicodeCodepoint; const ABmpRanges: array of TCodepointRange2;
  const ASmpRanges: array of TCodepointRange2): TUnicodeCodepoint;
var
  LIdx: Int32;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(ACp);

  if ACp <= $FFFF then
  begin
    LIdx := FindRange2(ACp, ABmpRanges);
    if LIdx >= 0 then
      Exit(ApplyDelta(ACp, ABmpRanges[LIdx].Delta));
  end
  else
  begin
    LIdx := FindRange2(ACp, ASmpRanges);
    if LIdx >= 0 then
      Exit(ApplyDelta(ACp, ASmpRanges[LIdx].Delta));
  end;

  Result := ACp;
end;

function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
begin
  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(False);

  Result := False;
  case AProperty of
    ubpAlphabetic:
      Result := ContainsRange2(ACp, PROP_ALPHABETIC_RANGES);
    ubpLowercase:
      Result := ContainsRange2(ACp, PROP_LOWERCASE_RANGES);
    ubpUppercase:
      Result := ContainsRange2(ACp, PROP_UPPERCASE_RANGES);
    ubpCased:
      Result := ContainsRange2(ACp, PROP_CASED_RANGES);
    ubpCaseIgnorable:
      Result := ContainsRange2(ACp, PROP_CASE_IGNORABLE_RANGES);
    ubpIdStart:
      Result := ContainsRange2(ACp, PROP_ID_START_RANGES);
    ubpIdContinue:
      Result := ContainsRange2(ACp, PROP_ID_CONTINUE_RANGES);
    ubpXidStart:
      Result := ContainsRange2(ACp, PROP_XID_START_RANGES);
    ubpXidContinue:
      Result := ContainsRange2(ACp, PROP_XID_CONTINUE_RANGES);
    ubpWhiteSpace:
      Result := ContainsRange2(ACp, PROP_WHITE_SPACE_RANGES);
    ubpGraphemeBase:
      Result := ContainsRange2(ACp, PROP_GRAPHEME_BASE_RANGES);
    ubpGraphemeExtend:
      Result := ContainsRange2(ACp, PROP_GRAPHEME_EXTEND_RANGES);
    ubpMath:
      Result := ContainsRange2(ACp, PROP_MATH_RANGES);
    ubpEmoji:
      Result := ContainsRange2(ACp, PROP_EMOJI_RANGES);
    ubpEmojiPresentation:
      Result := ContainsRange2(ACp, PROP_EMOJI_PRESENTATION_RANGES);
    ubpEmojiModifier:
      Result := ContainsRange2(ACp, PROP_EMOJI_MODIFIER_RANGES);
    ubpEmojiModifierBase:
      Result := ContainsRange2(ACp, PROP_EMOJI_MODIFIER_BASE_RANGES);
    ubpEmojiComponent:
      Result := ContainsRange2(ACp, PROP_EMOJI_COMPONENT_RANGES);
    ubpDefaultIgnorableCodePoint:
      Result := ContainsRange2(ACp, PROP_DEFAULT_IGNORABLE_CODE_POINT_RANGES);
    ubpDeprecated:
      Result := ContainsRange2(ACp, PROP_DEPRECATED_RANGES);
    ubpSoftDotted:
      Result := ContainsRange2(ACp, PROP_SOFT_DOTTED_RANGES);
  end;
end;

function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
var
  LValue: Byte;
begin
  if ACp < 128 then
    Exit(GetAsciiGeneralCategory(Byte(ACp)));

  if ACp > UNICODE_MAX_CODEPOINT then
    Exit(gcuUnassigned);

  if ACp <= $FFFF then
    Exit(TGeneralCategory(BMP_CATEGORY_TABLE[Byte(ACp shr 8), Byte(ACp and $FF)]));

  if FindRange3Value(ACp, SMP_CATEGORY_RANGES, LValue) then
    Exit(TGeneralCategory(LValue));

  Result := gcuUnassigned;
end;

function IsUpper(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsUpper(Byte(ACp)));
  Result := HasBinaryProperty(ACp, ubpUppercase);
end;

function IsLower(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsLower(Byte(ACp)));
  Result := HasBinaryProperty(ACp, ubpLowercase);
end;

function IsAlpha(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsAlpha(Byte(ACp)));
  Result := HasBinaryProperty(ACp, ubpAlphabetic);
end;

function IsDigit(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsDigit(Byte(ACp)));
  Result := GetGeneralCategory(ACp) = gcuDecimalNumber;
end;

function IsWhitespace(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsWhitespace(Byte(ACp)));
  Result := HasBinaryProperty(ACp, ubpWhiteSpace);
end;

function IsControl(const ACp: TUnicodeCodepoint): Boolean;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.IsControl(Byte(ACp)));
  Result := GetGeneralCategory(ACp) = gcuControl;
end;

function IsLetter(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in LETTER_CATEGORIES;
end;

function IsMark(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in MARK_CATEGORIES;
end;

function IsNumber(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in NUMBER_CATEGORIES;
end;

function IsPunctuation(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in PUNCTUATION_CATEGORIES;
end;

function IsSymbol(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in SYMBOL_CATEGORIES;
end;

function IsSeparator(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := GetGeneralCategory(ACp) in SEPARATOR_CATEGORIES;
end;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.ToLower(Byte(ACp)));
  Result := ApplySimpleMap(ACp, BMP_LOWER_DELTA, SMP_LOWER_DELTA);
end;

function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.ToUpper(Byte(ACp)));
  Result := ApplySimpleMap(ACp, BMP_UPPER_DELTA, SMP_UPPER_DELTA);
end;

function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  if ACp < 128 then
    Exit(nextpas.core.text.char.ToUpper(Byte(ACp)));
  Result := ApplySimpleMap(ACp, BMP_TITLE_DELTA, SMP_TITLE_DELTA);
end;

end.
