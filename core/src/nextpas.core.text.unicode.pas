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
  nextpas.core.text.unicode.idna,
  nextpas.core.text.unicode.confusable;

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
  TBidiLevel = nextpas.core.text.unicode.bidi.TBidiLevel;
  TBidiLevelArray = nextpas.core.text.unicode.bidi.TBidiLevelArray;
  TBidiIndexArray = nextpas.core.text.unicode.bidi.TBidiIndexArray;
  TIDNAErrorKind = nextpas.core.text.unicode.idna.TIDNAErrorKind;
  TIDNAMapStatus = nextpas.core.text.unicode.idna.TIDNAMapStatus;

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
  CONFUSABLE_MAX_PROTOTYPE = nextpas.core.text.unicode.confusable.CONFUSABLE_MAX_PROTOTYPE;
  UNICODE_SURROGATE_FIRST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_FIRST;
  UNICODE_SURROGATE_LAST = nextpas.core.text.unicode.types.UNICODE_SURROGATE_LAST;
  cvwNonIgnorable = nextpas.core.text.unicode.collate.cvwNonIgnorable;
  cvwShifted = nextpas.core.text.unicode.collate.cvwShifted;
  idnaOk = nextpas.core.text.unicode.idna.idnaOk;
  idnaEmptyDomain = nextpas.core.text.unicode.idna.idnaEmptyDomain;
  idnaEmptyLabel = nextpas.core.text.unicode.idna.idnaEmptyLabel;
  idnaInvalidDomain = nextpas.core.text.unicode.idna.idnaInvalidDomain;
  idnaInvalidAsciiLabel = nextpas.core.text.unicode.idna.idnaInvalidAsciiLabel;
  idnaNfcFailed = nextpas.core.text.unicode.idna.idnaNfcFailed;
  idnaPunycodeEncodeFailed = nextpas.core.text.unicode.idna.idnaPunycodeEncodeFailed;
  idnaPunycodeDecodeFailed = nextpas.core.text.unicode.idna.idnaPunycodeDecodeFailed;
  idnaEmptyAceBody = nextpas.core.text.unicode.idna.idnaEmptyAceBody;
  idnaAceLabelTooLong = nextpas.core.text.unicode.idna.idnaAceLabelTooLong;
  idnaDomainTooLong = nextpas.core.text.unicode.idna.idnaDomainTooLong;
  idnaDisallowed = nextpas.core.text.unicode.idna.idnaDisallowed;
  idnaInvalidUtf8 = nextpas.core.text.unicode.idna.idnaInvalidUtf8;
  idnaNotNfc = nextpas.core.text.unicode.idna.idnaNotNfc;
  idnaCheckHyphens = nextpas.core.text.unicode.idna.idnaCheckHyphens;
  idnaLeadingCombiningMark = nextpas.core.text.unicode.idna.idnaLeadingCombiningMark;
  idnaInvalidAceLabel = nextpas.core.text.unicode.idna.idnaInvalidAceLabel;
  idnaContextJ = nextpas.core.text.unicode.idna.idnaContextJ;
  idnaCheckBidi = nextpas.core.text.unicode.idna.idnaCheckBidi;
  idnaDisallowedSTD3 = nextpas.core.text.unicode.idna.idnaDisallowedSTD3;
  idmsValid = nextpas.core.text.unicode.idna.idmsValid;
  idmsMapped = nextpas.core.text.unicode.idna.idmsMapped;
  idmsIgnored = nextpas.core.text.unicode.idna.idmsIgnored;
  idmsDeviation = nextpas.core.text.unicode.idna.idmsDeviation;
  idmsDisallowed = nextpas.core.text.unicode.idna.idmsDisallowed;
  idmsDisallowedSTD3Valid = nextpas.core.text.unicode.idna.idmsDisallowedSTD3Valid;
  idmsDisallowedSTD3Mapped = nextpas.core.text.unicode.idna.idmsDisallowedSTD3Mapped;

// 属性查询函数
function HasBinaryProperty(const ACp: TUnicodeCodepoint; const AProperty: TBinaryProperty): Boolean; inline;
function GetGeneralCategory(const ACp: TUnicodeCodepoint): TGeneralCategory; inline;
function GetGraphemeBreakProperty(const ACp: TUnicodeCodepoint): TGraphemeBreakProperty; inline;
function GetIndicConjunctBreak(const ACp: TUnicodeCodepoint): TIndicConjunctBreak; inline;
function GetWordBreakProperty(const ACp: TUnicodeCodepoint): TWordBreakProperty; inline;
function GetSentenceBreakProperty(const ACp: TUnicodeCodepoint): TSentenceBreakProperty; inline;
function GetLineBreakClass(const ACp: TUnicodeCodepoint): TLineBreakClass; inline;
function GetBidiClass(const ACp: TUnicodeCodepoint): TBidiClass; inline;
function GetJoiningType(const ACp: TUnicodeCodepoint): TJoiningType; inline;
function GetBidiPairedBracket(const ACp: TUnicodeCodepoint): TUnicodeCodepoint; inline;
function GetBidiPairedBracketType(const ACp: TUnicodeCodepoint): TBidiPairedBracketType; inline;
function GetEastAsianWidth(const ACp: TUnicodeCodepoint): TEastAsianWidth; inline;
function IsEastAsianFWH(const ACp: TUnicodeCodepoint): Boolean; inline;
function ResolveBidi(const AText: string; const AParagraphDir: Integer = 2): TBidiResolveResult;
function ResolveBidiClasses(const AClasses: array of TBidiClass;
  const AParagraphDir: Integer = 2): TBidiResolveResult;
function ReorderBidiVisually(const ALevels: array of TBidiLevel): TBidiIndexArray;
function InvertBidiIndexMap(const AVisualToLogical: array of SizeInt;
  const ALogicalCount: SizeInt): TBidiIndexArray;
function ApplyBidiVisualOrder(const AText: string;
  const AParagraphDir: Integer = 2): string;

function PunycodeEncode(const ALabel: string): string;
function PunycodeDecode(const AAscii: string): string;
function IDNAToASCII(const ADomain: string): string; overload;
function IDNAToUnicode(const ADomain: string): string; overload;
function IDNAToASCII(const ADomain: string; out AError: string): string; overload;
function IDNAToUnicode(const ADomain: string; out AError: string): string; overload;
function IDNAToASCII(const ADomain: string; out AKind: TIDNAErrorKind): string; overload;
function IDNAToUnicode(const ADomain: string; out AKind: TIDNAErrorKind): string; overload;
function IDNAErrorKindName(const AKind: TIDNAErrorKind): string; inline;
function GetIdnaMapStatus(const ACp: TUnicodeCodepoint;
  out AMap: array of TUnicodeCodepoint; out AMapLen: Byte): TIDNAMapStatus; inline;
function ApplyIdnaMap(const AText: string; out AKind: TIDNAErrorKind): string;

function GetConfusablePrototype(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte): Boolean;
function ConfusableSkeleton(const AText: string): string;
function AreConfusable(const A, B: string): Boolean;
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
function GetScriptExtensions(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeScript; out ACount: Byte): Boolean; inline;
function HasScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean; inline;
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
function UTF8ToUpper(const AValue: string): string; overload;
function UTF8ToLower(const AValue: string): string; overload;
function UTF8ToTitle(const AValue: string): string; overload;
function UTF8CaseFold(const AValue: string): string; overload;
function UTF8CaseFoldSimple(const AValue: string): string; overload;
function UTF8ToUpper(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8ToLower(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8ToTitle(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8CaseFold(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8CaseFoldSimple(const AValue: string; const AOptions: TCaseOptions): string; overload;
function UTF8ToTitleWords(const AValue: string): string; overload;
function UTF8ToTitleWords(const AValue: string; const AOptions: TCaseOptions): string; overload;
function DefaultCaseOptions: TCaseOptions; inline;

// 规范化函数 — 重逻辑（分解/组合/QuickCheck 全串扫描）按红线2外联，避免门面 inline 膨胀
function NFD(const AText: string): string;
function NFC(const AText: string): string;
function NFKD(const AText: string): string;
function NFKC(const AText: string): string;
function IsNormalizedNFD(const AText: string): Boolean;
function IsNormalizedNFC(const AText: string): Boolean;
function IsNormalizedNFKD(const AText: string): Boolean;
function IsNormalizedNFKC(const AText: string): Boolean;
function QuickCheckNFD(const AText: string): Boolean;
function QuickCheckNFKD(const AText: string): Boolean;
function QuickCheckNFC(const AText: string): Boolean;
function QuickCheckNFKC(const AText: string): Boolean;
function GetCanonicalCombiningClass(const ACp: TUnicodeCodepoint): Byte; inline;
function GetDecompositionMapping(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte;
  out AIsCompatibility: Boolean): Boolean; inline;
function IsCompositionExcluded(const ACp: TUnicodeCodepoint): Boolean; inline;

// 文本分割函数 — 重逻辑（全串扫描/循环）外联；单例获取器保持 inline
function UnicodeSegmenter: IUnicodeSegmenter; inline;
function SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
function SegmentWords(const AText: string): TSegmentResultArray;
function SegmentLines(const AText: string): TSegmentResultArray;
function SegmentSentences(const AText: string): TSegmentResultArray;
function SegmentLineBreaks(const AText: string): TSegmentResultArray;
{ Shared UAX #29 grapheme-cluster core (byte-oriented). — 循环体禁 inline }
function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function WordBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function SentenceBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function LineBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function NextLineBreak(const AText: string; const APos: SizeInt): SizeInt;

// 排序规则函数 — 重逻辑（CollectElements/排序）外联；小访问器/选项构造保持 inline
function GetCollationWeight(const ACp: TUnicodeCodepoint): UInt32;
function UnpackPrimary(const AWeight: UInt32): UInt16; inline;
function UnpackSecondary(const AWeight: UInt32): Byte; inline;
function UnpackTertiary(const AWeight: UInt32): Byte; inline;
function UnicodeCollator: IUnicodeCollator;
function UnicodeCollatorWithOptions(const AOptions: TCollationOptions): IUnicodeCollator;
function DefaultCollationOptions: TCollationOptions; inline;
function UCACollationOptions(const AVariable: TCollationVariableWeighting): TCollationOptions; inline;

// 便利函数 — 委派 collator Compare/GetSortKey，重逻辑外联
function CompareText(const A, B: string): Integer;
function GetSortKey(const AText: string): TCollationKey;
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

function GetJoiningType(const ACp: TUnicodeCodepoint): TJoiningType;
begin
  Result := nextpas.core.text.unicode.props.GetJoiningType(ACp);
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

function ReorderBidiVisually(const ALevels: array of TBidiLevel): TBidiIndexArray;
begin
  Result := nextpas.core.text.unicode.bidi.ReorderBidiVisually(ALevels);
end;

function InvertBidiIndexMap(const AVisualToLogical: array of SizeInt;
  const ALogicalCount: SizeInt): TBidiIndexArray;
begin
  Result := nextpas.core.text.unicode.bidi.InvertBidiIndexMap(AVisualToLogical, ALogicalCount);
end;

function ApplyBidiVisualOrder(const AText: string;
  const AParagraphDir: Integer): string;
begin
  Result := nextpas.core.text.unicode.bidi.ApplyBidiVisualOrder(AText, AParagraphDir);
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

function GetScriptExtensions(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeScript; out ACount: Byte): Boolean;
begin
  Result := nextpas.core.text.unicode.script.GetScriptExtensions(ACp, ADst, ACount);
end;

function HasScript(const ACp: TUnicodeCodepoint; const AScript: TUnicodeScript): Boolean;
begin
  Result := nextpas.core.text.unicode.script.HasScript(ACp, AScript);
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

function IDNAToASCII(const ADomain: string; out AKind: TIDNAErrorKind): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToASCII(ADomain, AKind);
end;

function IDNAToUnicode(const ADomain: string; out AKind: TIDNAErrorKind): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAToUnicode(ADomain, AKind);
end;

function IDNAErrorKindName(const AKind: TIDNAErrorKind): string;
begin
  Result := nextpas.core.text.unicode.idna.IDNAErrorKindName(AKind);
end;

function GetIdnaMapStatus(const ACp: TUnicodeCodepoint;
  out AMap: array of TUnicodeCodepoint; out AMapLen: Byte): TIDNAMapStatus;
begin
  Result := nextpas.core.text.unicode.idna.GetIdnaMapStatus(ACp, AMap, AMapLen);
end;

function ApplyIdnaMap(const AText: string; out AKind: TIDNAErrorKind): string;
begin
  Result := nextpas.core.text.unicode.idna.ApplyIdnaMap(AText, AKind);
end;

function GetConfusablePrototype(const ACp: TUnicodeCodepoint;
  out ADst: array of TUnicodeCodepoint; out ALen: Byte): Boolean;
begin
  Result := nextpas.core.text.unicode.confusable.GetConfusablePrototype(ACp, ADst, ALen);
end;

function ConfusableSkeleton(const AText: string): string;
begin
  Result := nextpas.core.text.unicode.confusable.ConfusableSkeleton(AText);
end;

function AreConfusable(const A, B: string): Boolean;
begin
  Result := nextpas.core.text.unicode.confusable.AreConfusable(A, B);
end;

end.
