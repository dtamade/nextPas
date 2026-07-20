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
  nextpas.core.text.unicode.bidi,
  nextpas.core.text.unicode.collate,
  nextpas.core.text.unicode.data,
  nextpas.core.text.unicode.punycode,
  nextpas.core.text.unicode.idna;

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
  TIndicConjunctBreak = nextpas.core.text.unicode.types.TIndicConjunctBreak;
  TWordBreakProperty = nextpas.core.text.unicode.types.TWordBreakProperty;
  TSentenceBreakProperty = nextpas.core.text.unicode.types.TSentenceBreakProperty;
  TLineBreakClass = nextpas.core.text.unicode.types.TLineBreakClass;
  TBidiClass = nextpas.core.text.unicode.types.TBidiClass;
  TBidiPairedBracketType = nextpas.core.text.unicode.types.TBidiPairedBracketType;
  TEastAsianWidth = nextpas.core.text.unicode.types.TEastAsianWidth;
  TBidiResolveResult = nextpas.core.text.unicode.bidi.TBidiResolveResult;
  TBidiLevelArray = nextpas.core.text.unicode.bidi.TBidiLevelArray;
  TBidiIndexArray = nextpas.core.text.unicode.bidi.TBidiIndexArray;

  TCollationStrength = nextpas.core.text.unicode.collate.TCollationStrength;
  TCollationVariableWeighting = nextpas.core.text.unicode.collate.TCollationVariableWeighting;
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
  IUnicodeDataManager = nextpas.core.text.unicode.data.IUnicodeDataManager;

const
  UNICODE_MAX_CODEPOINT = nextpas.core.text.unicode.types.UNICODE_MAX_CODEPOINT;
  UNICODE_SURROGATE_FIRST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_FIRST;
  UNICODE_SURROGATE_LAST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_LAST;
  cvwNonIgnorable = nextpas.core.text.unicode.collate.cvwNonIgnorable;
  cvwShifted = nextpas.core.text.unicode.collate.cvwShifted;

// 属性查询函数
function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean; inline;
function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory; inline;
function GetGraphemeBreakProperty(const ACp: TUnicodeCodepoint): TGraphemeBreakProperty; inline;
function GetIndicConjunctBreak(const ACp: TUnicodeCodepoint): TIndicConjunctBreak; inline;
function GetWordBreakProperty(const ACp: TUnicodeCodepoint): TWordBreakProperty; inline;
function GetSentenceBreakProperty(const ACp: TUnicodeCodepoint): TSentenceBreakProperty; inline;
function GetLineBreakClass(const ACp: TUnicodeCodepoint): TLineBreakClass; inline;
function GetBidiClass(const ACp: TUnicodeCodepoint): TBidiClass; inline;
function GetBidiPairedBracket(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function GetBidiPairedBracketType(const ACp: TUnicodeCodepoint): TBidiPairedBracketType; inline;
function GetEastAsianWidth(const ACp: TUnicodeCodepoint): TEastAsianWidth; inline;
function IsEastAsianFWH(const ACp: TUnicodeCodepoint): Boolean; inline;
function ResolveBidi(const AText: string; const AParagraphDir: Integer = 2): TBidiResolveResult; inline;

function PunycodeEncode(const ALabel: string): string; inline;
function PunycodeDecode(const AAscii: string): string; inline;
function IDNAToASCII(const ADomain: string): string; overload; inline;
function IDNAToUnicode(const ADomain: string): string; overload; inline;
function IDNAToASCII(const ADomain: string; out AError: string): string; overload; inline;
function IDNAToUnicode(const ADomain: string; out AError: string): string; overload; inline;
function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer = 2): TBidiResolveResult; inline;
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

// 大小写映射类型（locale Case）
type
  TCaseLocale = nextpas.core.text.unicode.casefold.TCaseLocale;
  TCaseOptions = nextpas.core.text.unicode.casefold.TCaseOptions;

const
  clRoot = nextpas.core.text.unicode.casefold.clRoot;
  clTurkish = nextpas.core.text.unicode.casefold.clTurkish;
  clAzeri = nextpas.core.text.unicode.casefold.clAzeri;
  clLithuanian = nextpas.core.text.unicode.casefold.clLithuanian;

// 大小写映射函数
function CodepointToLower(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToUpper(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CodepointToTitle(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; overload; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte; overload; inline;
function CaseFoldSimple(const ACp: TUnicodeCodepoint; const AOptions: TCaseOptions): TUnicodeCodepoint; overload; inline;
function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap;
  const AOptions: TCaseOptions): Byte; overload; inline;
function UTF8ToUpper(const AValue: string): string; overload; inline;
function UTF8ToLower(const AValue: string): string; overload; inline;
function UTF8ToTitle(const AValue: string): string; overload; inline;
function UTF8CaseFold(const AValue: string): string; overload; inline;
function UTF8CaseFoldSimple(const AValue: string): string; overload; inline;
function UTF8ToUpper(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function UTF8ToLower(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function UTF8ToTitle(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function UTF8CaseFold(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function UTF8CaseFoldSimple(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function UTF8ToTitleWords(const AValue: string): string; overload; inline;
function UTF8ToTitleWords(const AValue: string; const AOptions: TCaseOptions): string; overload; inline;
function DefaultCaseOptions: TCaseOptions; inline;

// 规范化函数
function NFD(const AText: string): string; inline;
function NFC(const AText: string): string; inline;
function NFKD(const AText: string): string; inline;
function NFKC(const AText: string): string; inline;
function IsNormalizedNFD(const AText: string): Boolean; inline;
function IsNormalizedNFC(const AText: string): Boolean; inline;
function IsNormalizedNFKD(const AText: string): Boolean; inline;
function IsNormalizedNFKC(const AText: string): Boolean; inline;
function QuickCheckNFD(const AText: string): Boolean; inline;
function QuickCheckNFKD(const AText: string): Boolean; inline;
function QuickCheckNFC(const AText: string): Boolean; inline;
function QuickCheckNFKC(const AText: string): Boolean; inline;
function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte; inline;
function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean; inline;
function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean; inline;

// 文本分割函数
function UnicodeSegmenter: IUnicodeSegmenter; inline;
function SegmentGraphemeClusters(const AText: string): TSegmentResultArray; inline;
function SegmentWords(const AText: string): TSegmentResultArray; inline;
function SegmentLines(const AText: string): TSegmentResultArray; inline;
function SegmentSentences(const AText: string): TSegmentResultArray; inline;
function SegmentLineBreaks(const AText: string): TSegmentResultArray; inline;
{ Shared UAX #29 grapheme-cluster core (byte-oriented). }
function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt; inline;
function WordBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt; inline;
function SentenceBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt; inline;
function LineBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt; inline;
function NextLineBreak(const AText: string; const APos: SizeInt): SizeInt; inline;

// 排序规则函数
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32; inline;
function UnpackPrimary(const AWeight: UInt32): UInt16; inline;
function UnpackSecondary(const AWeight: UInt32): Byte; inline;
function UnpackTertiary(const AWeight: UInt32): Byte; inline;
function UnicodeCollator: IUnicodeCollator; inline;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator; inline;
function DefaultCollationOptions: TCollationOptions; inline;
function UCACollationOptions(const AVariable: TCollationVariableWeighting): TCollationOptions; inline;

// 便利函数
function CompareText(const A, B: string): Integer; inline;
function GetSortKey(const AText: string): TCollationKey; inline;
procedure SortStrings(var AStrings: array of string);

// 数据管理器
function UnicodeData: IUnicodeDataManager; inline;

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

function GetIndicConjunctBreak(const ACp: TUnicodeCodepoint): TIndicConjunctBreak;
begin
  Result := nextpas.core.text.unicode.props.GetIndicConjunctBreak(ACp);
end;

function GetWordBreakProperty(const ACp: TUnicodeCodepoint): TWordBreakProperty;
begin
  Result := nextpas.core.text.unicode.props.GetWordBreakProperty(ACp);
end;

function GetSentenceBreakProperty(const ACp: TUnicodeCodepoint): TSentenceBreakProperty;
begin
  Result := nextpas.core.text.unicode.props.GetSentenceBreakProperty(ACp);
end;

function GetLineBreakClass(const ACp: TUnicodeCodepoint): TLineBreakClass;
begin
  Result := nextpas.core.text.unicode.props.GetLineBreakClass(ACp);
end;

function GetBidiClass(const ACp: TUnicodeCodepoint): TBidiClass;
begin
  Result := nextpas.core.text.unicode.props.GetBidiClass(ACp);
end;

function GetBidiPairedBracket(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.props.GetBidiPairedBracket(ACp);
end;

function GetBidiPairedBracketType(const ACp: TUnicodeCodepoint): TBidiPairedBracketType;
begin
  Result := nextpas.core.text.unicode.props.GetBidiPairedBracketType(ACp);
end;

function GetEastAsianWidth(const ACp: TUnicodeCodepoint): TEastAsianWidth;
begin
  Result := nextpas.core.text.unicode.props.GetEastAsianWidth(ACp);
end;

function IsEastAsianFWH(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.props.IsEastAsianFWH(ACp);
end;


function ResolveBidi(const AText: string; const AParagraphDir: Integer): TBidiResolveResult;
begin
  Result := nextpas.core.text.unicode.bidi.ResolveBidi(AText, AParagraphDir);
end;

function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer): TBidiResolveResult;
begin
  Result := nextpas.core.text.unicode.bidi.ResolveBidiClasses(AClasses, AParagraphDir);
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

function DefaultCaseOptions: TCaseOptions;
begin
  Result := nextpas.core.text.unicode.casefold.DefaultCaseOptions;
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldSimple(ACp);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap): Byte;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldFull(ACp, ADst);
end;

function CaseFoldSimple(const ACp: TUnicodeCodepoint; const AOptions: TCaseOptions): TUnicodeCodepoint;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldSimple(ACp, AOptions);
end;

function CaseFoldFull(const ACp: TUnicodeCodepoint; out ADst: TCaseFoldMap;
  const AOptions: TCaseOptions): Byte;
begin
  Result := nextpas.core.text.unicode.casefold.CaseFoldFull(ACp, ADst, AOptions);
end;

function UTF8ToUpper(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToUpper(AValue);
end;

function UTF8ToLower(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToLower(AValue);
end;

function UTF8ToTitle(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToTitle(AValue);
end;

function UTF8CaseFold(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFold(AValue);
end;

function UTF8CaseFoldSimple(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFoldSimple(AValue);
end;

function UTF8ToUpper(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToUpper(AValue, AOptions);
end;

function UTF8ToLower(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToLower(AValue, AOptions);
end;

function UTF8ToTitle(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToTitle(AValue, AOptions);
end;

function UTF8CaseFold(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFold(AValue, AOptions);
end;

function UTF8CaseFoldSimple(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8CaseFoldSimple(AValue, AOptions);
end;

function UTF8ToTitleWords(const AValue: string): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToTitleWords(AValue);
end;

function UTF8ToTitleWords(const AValue: string; const AOptions: TCaseOptions): string;
begin
  Result := nextpas.core.text.unicode.casefold.UTF8ToTitleWords(AValue, AOptions);
end;

function NFD(const AText: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFD(AText);
end;

function NFC(const AText: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFC(AText);
end;

function NFKD(const AText: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFKD(AText);
end;

function NFKC(const AText: string): string;
begin
  Result := nextpas.core.text.unicode.normalize.NFKC(AText);
end;

function IsNormalizedNFD(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFD(AText);
end;

function IsNormalizedNFC(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFC(AText);
end;

function IsNormalizedNFKD(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFKD(AText);
end;

function IsNormalizedNFKC(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsNormalizedNFKC(AText);
end;

function QuickCheckNFD(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.QuickCheckNFD(AText);
end;

function QuickCheckNFC(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.QuickCheckNFC(AText);
end;

function QuickCheckNFKD(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.QuickCheckNFKD(AText);
end;

function QuickCheckNFKC(const AText: string): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.QuickCheckNFKC(AText);
end;

function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte;
begin
  Result := nextpas.core.text.unicode.normalize.GetCanonicalCombiningClass(ACp);
end;

function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.GetDecompositionMapping(ACp, ADst, ALen, AIsCompatibility);
end;

function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean;
begin
  Result := nextpas.core.text.unicode.normalize.IsCompositionExcluded(ACp);
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

function SegmentLineBreaks(const AText: string): TSegmentResultArray;
begin
  Result := nextpas.core.text.unicode.segment.SegmentLineBreaks(AText);
end;

function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.text.unicode.segment.GraphemeClusterByteLen(AData, ALen);
end;

function WordBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.text.unicode.segment.WordBreakByteLen(AData, ALen);
end;

function SentenceBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.text.unicode.segment.SentenceBreakByteLen(AData, ALen);
end;

function LineBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
begin
  Result := nextpas.core.text.unicode.segment.LineBreakByteLen(AData, ALen);
end;

function NextLineBreak(const AText: string; const APos: SizeInt): SizeInt;
begin
  Result := nextpas.core.text.unicode.segment.NextLineBreak(AText, APos);
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

function UCACollationOptions(const AVariable: TCollationVariableWeighting): TCollationOptions;
begin
  Result := nextpas.core.text.unicode.collate.UCACollationOptions(AVariable);
end;

function CompareText(const A, B: string): Integer;
begin
  Result := UnicodeCollator.Compare(A, B);
end;

function GetSortKey(const AText: string): TCollationKey;
begin
  Result := UnicodeCollator.GetSortKey(AText);
end;

procedure QuickSortStrings(var AStrings: array of string;
  const ACollator: IUnicodeCollator; ALo, AHi: SizeInt);
var
  LPivot: string;
  LI, LJ: SizeInt;
  LTemp: string;
begin
  if ALo >= AHi then
    Exit;
  // Lomuto partition: pivot at AHi
  LPivot := AStrings[AHi];
  LJ := ALo;
  for LI := ALo to AHi - 1 do
  begin
    if ACollator.Compare(AStrings[LI], LPivot) <= 0 then
    begin
      LTemp := AStrings[LJ]; AStrings[LJ] := AStrings[LI]; AStrings[LI] := LTemp;
      Inc(LJ);
    end;
  end;
  // Place pivot at final position
  LTemp := AStrings[LJ]; AStrings[LJ] := AStrings[AHi]; AStrings[AHi] := LTemp;

  QuickSortStrings(AStrings, ACollator, ALo, LJ - 1);
  QuickSortStrings(AStrings, ACollator, LJ + 1, AHi);
end;

procedure SortStrings(var AStrings: array of string);
var
  LCollator: IUnicodeCollator;
  LLen: SizeInt;
  LI, LJ: SizeInt;
  LTemp: string;
begin
  LLen := High(AStrings) - Low(AStrings) + 1;
  if LLen <= 1 then
    Exit;
  LCollator := UnicodeCollator;
  // Small arrays: insertion sort; large arrays: quicksort
  if LLen <= 16 then
  begin
    for LI := 1 to High(AStrings) do
    begin
      LTemp := AStrings[LI];
      LJ := LI;
      while (LJ > 0) and (LCollator.Compare(AStrings[LJ - 1], LTemp) > 0) do
      begin
        AStrings[LJ] := AStrings[LJ - 1];
        Dec(LJ);
      end;
      AStrings[LJ] := LTemp;
    end;
  end
  else
    QuickSortStrings(AStrings, LCollator, Low(AStrings), High(AStrings));
end;

function UnicodeData: IUnicodeDataManager;
begin
  Result := nextpas.core.text.unicode.data.UnicodeData;
end;

function PunycodeEncode(const ALabel: string): string;
begin
  Result := nextpas.core.text.unicode.punycode.PunycodeEncode(ALabel);
end;

function PunycodeDecode(const AAscii: string): string;
begin
  Result := nextpas.core.text.unicode.punycode.PunycodeDecode(AAscii);
end;

function IDNAToASCII(const ADomain: string): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToASCII(ADomain);
end;

function IDNAToUnicode(const ADomain: string): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToUnicode(ADomain);
end;

function IDNAToASCII(const ADomain: string; out AError: string): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToASCII(ADomain, AError);
end;

function IDNAToUnicode(const ADomain: string; out AError: string): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToUnicode(ADomain, AError);
end;


end.
