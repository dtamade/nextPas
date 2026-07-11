unit nextpas.core.text.unicode;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.casefold,
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.script,
  nextpas.core.text.unicode.block,
  nextpas.core.text.unicode.segment,
  nextpas.core.text.unicode.collate;

type
  // 基础类型
  TUnicodeCodepoint = nextpas.core.text.unicode.types.TUnicodeCodepoint;
  TGeneralCategory = nextpas.core.text.unicode.types.TGeneralCategory;
  TBinaryProperty = nextpas.core.text.unicode.types.TBinaryProperty;
  TGeneralCategorySet = nextpas.core.text.unicode.types.TGeneralCategorySet;
  TCodepointRange2 = nextpas.core.text.unicode.types.TCodepointRange2;
  TCodepointRange3 = nextpas.core.text.unicode.types.TCodepointRange3;
  TCaseFoldMap = nextpas.core.text.unicode.types.TCaseFoldMap;
  TCaseFoldEntry = nextpas.core.text.unicode.types.TCaseFoldEntry;
  TGraphemeBreakProperty = nextpas.core.text.unicode.types.TGraphemeBreakProperty;

  TCollationStrength = nextpas.core.text.unicode.collate.TCollationStrength;
  TCollationOptions = nextpas.core.text.unicode.collate.TCollationOptions;
  TCollationKey = nextpas.core.text.unicode.collate.TCollationKey;
  IUnicodeCollator = nextpas.core.text.unicode.collate.IUnicodeCollator;
  TUnicodeCollator = nextpas.core.text.unicode.collate.TUnicodeCollator;

  // 新增类型
  TUnicodeScript = nextpas.core.text.unicode.types.TUnicodeScript;
  TUnicodeBlock = nextpas.core.text.unicode.types.TUnicodeBlock;
  TSegmentType = nextpas.core.text.unicode.segment.TSegmentType;
  TSegmentResult = nextpas.core.text.unicode.segment.TSegmentResult;
  TSegmentResultArray = nextpas.core.text.unicode.segment.TSegmentResultArray;

  // 接口类型
  IUnicodeSegmenter = nextpas.core.text.unicode.segment.IUnicodeSegmenter;

const
  UNICODE_MAX_CODEPOINT = nextpas.core.text.unicode.types.UNICODE_MAX_CODEPOINT;
  UNICODE_SURROGATE_FIRST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_FIRST;
  UNICODE_SURROGATE_LAST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_LAST;

// 属性查询函数
function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean; inline;
function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory; inline;
function GetGraphemeBreakProperty(const ACp: TUnicodeCodepoint): TGraphemeBreakProperty; inline;
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

// Script/Block 属性查询
function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript; inline;
function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean; inline;
function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock; inline;
function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean; inline;

// 大小写映射函数
function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte; inline;
function UTF8ToUpper(const AValue: string): string; inline;
function UTF8ToLower(const AValue: string): string; inline;
function UTF8CaseFold(const AValue: string): string; inline;
function UTF8CaseFoldSimple(const AValue: string): string; inline;

// 规范化函数
function NFD(const s: string): string; inline;
function NFC(const s: string): string; inline;
function NFKD(const s: string): string; inline;
function NFKC(const s: string): string; inline;
function IsNormalizedNFD(const s: string): Boolean; inline;
function IsNormalizedNFC(const s: string): Boolean; inline;

// 文本分割函数
function UnicodeSegmenter: IUnicodeSegmenter; inline;
function SegmentGraphemeClusters(const AText: string): TSegmentResultArray; inline;
function SegmentWords(const AText: string): TSegmentResultArray; inline;
function SegmentLines(const AText: string): TSegmentResultArray; inline;
function SegmentSentences(const AText: string): TSegmentResultArray; inline;

// 排序规则函数
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32; inline;
function UnpackPrimary(const AWeight: UInt32): UInt16; inline;
function UnpackSecondary(const AWeight: UInt32): Byte; inline;
function UnpackTertiary(const AWeight: UInt32): Byte; inline;
function UnicodeCollator: IUnicodeCollator; inline;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator; inline;
function DefaultCollationOptions: TCollationOptions; inline;

implementation

function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean;
begin
  Result := nextpas.core.text.unicode.props.HasBinaryProperty(ACp, AProperty);
end;

function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory;
begin
  Result := nextpas.core.text.unicode.props.GetGeneralCategory(ACp);
end;

function GetGraphemeBreakProperty(const ACp: TUnicodeCodepoint): TGraphemeBreakProperty;
begin
  Result := nextpas.core.text.unicode.props.GetGraphemeBreakProperty(ACp);
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

function GetScript(const ACp: TUnicodeCodepoint): TUnicodeScript;
begin
  Result := nextpas.core.text.unicode.script.GetScript(ACp);
end;

function IsScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
begin
  Result := nextpas.core.text.unicode.script.IsScript(ACp, AScript);
end;

function GetBlock(const ACp: TUnicodeCodepoint): TUnicodeBlock;
begin
  Result := nextpas.core.text.unicode.block.GetBlock(ACp);
end;

function IsBlock(const ACp: TUnicodeCodepoint; const ABlock: TUnicodeBlock): Boolean;
begin
  Result := nextpas.core.text.unicode.block.IsBlock(ACp, ABlock);
end;

function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToLower(ACp);
end;

function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToUpper(ACp);
end;

function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CodepointToTitle(ACp);
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldSimple(ACp);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldFull(ACp, ADst);
end;

function UTF8ToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToUpper(AValue);
end;

function UTF8ToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToLower(AValue);
end;

function UTF8CaseFold(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFold(AValue);
end;

function UTF8CaseFoldSimple(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFoldSimple(AValue);
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

function UnicodeSegmenter: IUnicodeSegmenter;
begin
  Result := nextpas.core.text.unicode.segment.UnicodeSegmenter;
end;

function SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
begin
  Result := nextpas.core.text.unicode.segment.UnicodeSegmenter.SegmentGraphemeClusters(AText);
end;

function SegmentWords(const AText: string): TSegmentResultArray;
begin
  Result := nextpas.core.text.unicode.segment.UnicodeSegmenter.SegmentWords(AText);
end;

function SegmentLines(const AText: string): TSegmentResultArray;
begin
  Result := nextpas.core.text.unicode.segment.UnicodeSegmenter.SegmentLines(AText);
end;

function SegmentSentences(const AText: string): TSegmentResultArray;
begin
  Result := nextpas.core.text.unicode.segment.UnicodeSegmenter.SegmentSentences(AText);
end;

function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
begin
  Result := nextpas.core.text.unicode.collate.GetCollationWeight(ACp);
end;

function UnpackPrimary(const AWeight: UInt32): UInt16;
begin
  Result := nextpas.core.text.unicode.collate.UnpackPrimary(AWeight);
end;

function UnpackSecondary(const AWeight: UInt32): Byte;
begin
  Result := nextpas.core.text.unicode.collate.UnpackSecondary(AWeight);
end;

function UnpackTertiary(const AWeight: UInt32): Byte;
begin
  Result := nextpas.core.text.unicode.collate.UnpackTertiary(AWeight);
end;

function UnicodeCollator: IUnicodeCollator;
begin
  Result := nextpas.core.text.unicode.collate.UnicodeCollator;
end;

function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
begin
  Result := nextpas.core.text.unicode.collate.UnicodeCollatorWithOptions(AOptions);
end;

function DefaultCollationOptions: TCollationOptions;
begin
  Result := nextpas.core.text.unicode.collate.DefaultCollationOptions;
end;

end.
