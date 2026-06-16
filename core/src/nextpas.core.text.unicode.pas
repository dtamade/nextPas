unit nextpas.core.text.unicode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.&case,
  nextpas.core.text.unicode.normalize;

type
  TUnicodeCodepoint = nextpas.core.text.unicode.base.TUnicodeCodepoint;
  TGeneralCategory = nextpas.core.text.unicode.base.TGeneralCategory;
  TBinaryProperty = nextpas.core.text.unicode.base.TBinaryProperty;
  TGeneralCategorySet = nextpas.core.text.unicode.base.TGeneralCategorySet;
  TCodepointRange2 = nextpas.core.text.unicode.base.TCodepointRange2;
  TCodepointRange3 = nextpas.core.text.unicode.base.TCodepointRange3;
  TCaseFoldMap = nextpas.core.text.unicode.base.TCaseFoldMap;
  TCaseFoldEntry = nextpas.core.text.unicode.base.TCaseFoldEntry;

const
  UNICODE_MAX_CODEPOINT = nextpas.core.text.unicode.base.UNICODE_MAX_CODEPOINT;
  UNICODE_SURROGATE_FIRST = nextpas.core.text.unicode.base.UNICODE_SURROGATE_FIRST;
  UNICODE_SURROGATE_LAST = nextpas.core.text.unicode.base.UNICODE_SURROGATE_LAST;

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
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte; inline;
function UTF8ToUpper(const AValue: string): string; inline;
function UTF8ToLower(const AValue: string): string; inline;
function UTF8CaseFold(const AValue: string): string; inline;
function UTF8CaseFoldSimple(const AValue: string): string; inline;
function NFD(const s: string): string; inline;
function NFC(const s: string): string; inline;
function NFKD(const s: string): string; inline;
function NFKC(const s: string): string; inline;
function IsNormalizedNFD(const s: string): Boolean; inline;
function IsNormalizedNFC(const s: string): Boolean; inline;

implementation

function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
begin
  Result := nextpas.core.text.unicode.props.HasBinaryProperty(ACp, AProperty);
end;

function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
begin
  Result := nextpas.core.text.unicode.props.GetGeneralCategory(ACp);
end;

function IsUpper(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsUpper(ACp);
end;

function IsLower(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsLower(ACp);
end;

function IsAlpha(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsAlpha(ACp);
end;

function IsDigit(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsDigit(ACp);
end;

function IsWhitespace(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsWhitespace(ACp);
end;

function IsControl(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsControl(ACp);
end;

function IsLetter(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsLetter(ACp);
end;

function IsMark(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsMark(ACp);
end;

function IsNumber(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsNumber(ACp);
end;

function IsPunctuation(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsPunctuation(ACp);
end;

function IsSymbol(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsSymbol(ACp);
end;

function IsSeparator(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsSeparator(ACp);
end;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.&case.CodepointToLower(ACp);
end;

function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.&case.CodepointToUpper(ACp);
end;

function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.&case.CodepointToTitle(ACp);
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.&case.CaseFoldSimple(ACp);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  Result := nextpas.core.text.unicode.&case.CaseFoldFull(ACp, ADst);
end;

function UTF8ToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.&case.UTF8ToUpper(AValue);
end;

function UTF8ToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.&case.UTF8ToLower(AValue);
end;

function UTF8CaseFold(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.&case.UTF8CaseFold(AValue);
end;

function UTF8CaseFoldSimple(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.&case.UTF8CaseFoldSimple(AValue);
end;

function NFD(const s: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFD(s);
end;

function NFC(const s: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFC(s);
end;

function NFKD(const s: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFKD(s);
end;

function NFKC(const s: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFKC(s);
end;

function IsNormalizedNFD(const s: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFD(s);
end;

function IsNormalizedNFC(const s: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFC(s);
end;

end.
