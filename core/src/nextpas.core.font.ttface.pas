unit nextpas.core.font.ttface;
{**
 * @desc 纯 Pascal TTF/OTF 字体文件解析器。
 *       支持 sfnt 表目录、head/hhea/maxp/cmap/loca/glyf/hmtx/os2 表。
 *       只支持 TrueType glyf 轮廓，不支持 CFF/CFF2。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.io.intf,
  nextpas.core.fs.base,
  nextpas.core.fs.stream,
  nextpas.core.fs.util,
  nextpas.core.font.base;

type
  {** 纯 Pascal TrueType 字体面 }
  TTFontFace = class
  private
    FData: array of Byte;           // 完整文件数据
    FDataLength: Int32;
    FTTCFaceOffset: Int32;          // TTC 第一个 face 的文件偏移（单 TTF 为 0）
    FTableCount: Int32;
    FTables: TFontTableEntryArray;
    FFormat: TFontFileFormat;
    FHead: TFontHeadTable;
    FHhea: TFontHheaTable;
    FMaxp: TFontMaxpTable;
    FHmtx: TFontHorizontalMetricArray;
    FCmapFmt4: TFontCmapFmt4;
    FCmapFmt12: TFontCmapFmt12;
    FHasFmt4: Boolean;
    FHasFmt12: Boolean;
    FHasFmt14: Boolean;
    { cmap Format 14 IVS data }
    FFmt14Base: Int32;                   { cmap table base for offset calculations }
    FFmt14Records: array of record       { VarSelector records }
      VarSelector: UInt32;               { variation selector codepoint }
      DefaultUVSOffset: Int32;           { absolute offset to DefaultUVS table }
      NonDefaultUVSOffset: Int32;        { absolute offset to NonDefaultUVS table }
    end;
    FLocaOffsets: array of UInt32;
    FOs2: TFontOs2Table;
    FPairPosSubtables: TFontPairPosSubtableArray;
    FLigatureSubtables: TFontLigatureSubtableArray;
    FSingleSubstSubtables: TFontSingleSubstSubtableArray;
    FSinglePosSubtables: TFontSinglePosSubtableArray;
    FMarkToBaseSubtables: TFontMarkToBaseSubtableArray;
    FMarkToMarkSubtables: TFontMarkToMarkSubtableArray;
    FCursivePosSubtables: TFontCursivePosSubtableArray;
    FPairPosFmt1Subtables: TFontPairPosFmt1SubtableArray;
    FMultipleSubstSubtables: TFontMultipleSubstSubtableArray;
    FAlternateSubstSubtables: TFontAlternateSubstSubtableArray;
    FMarkToLigatureSubtables: TFontMarkToLigatureSubtableArray;
    FContextSubstSubtables: TFontContextSubtableArray;
    FContextPosSubtables: TFontContextSubtableArray;
    { GSUB LookupList index → (type, first subtable index, subtable count) 映射 }
    FLookupEntries: array of record
      LookupType: Int32;
      FirstSubtableIndex: Int32;
      SubtableCount: Int32;
    end;
    { COLR 表 — 颜色层 (color glyph layers) }
    FColorLayerRecords: TFontColorLayerRecordArray;
    { CPAL 表 — 调色板 }
    FPaletteColors: TFontPaletteColorArray;
    FPaletteCount: Int32;        { 调色板数量 }
    FColorsPerPalette: Int32;    { 每个调色板的颜色数 }
    { CBDT/CBLC 表 — 位图字形 }
    FHasBitmapStrikes: Boolean;
    FBitmapStrikePpem: UInt8;    { 当前 strike 的 ppem }
    FBitmapStrikeStartGlyph: UInt16;
    FBitmapStrikeEndGlyph: UInt16;
    FBitmapIndexSubTables: array of record
      FirstGlyph, LastGlyph: UInt16;
      IndexFormat: UInt16;
      ImageFormat: UInt16;
      ImageDataOffset: UInt32;   { 相对 CBDT 表起始 }
      Offsets: array of UInt32;  { 每字形偏移 (glyphCount+1) }
    end;
    { 可变字体坐标缓存 }
    FVariationCoords: array of Single;
    FHasVariationCoords: Boolean;
    FFeatureTags: array of UInt32;
    { fvar 表 }
    FFvarAxes: array of TFontVariationAxis;
    FFvarInstances: array of TFontNamedInstance;
    FFvarAxisCount: Int32;
    FFvarInstanceCount: Int32;
    { avar 表 segment maps }
    FAvarSegmentMaps: array of array of record
      FromCoord, ToCoord: Single;
    end;
    FAvarAxisCount: Int32;
    { gvar 表 }
    FGvarParsed: Boolean;
    FGvarAxisCount: Int32;
    FGvarGlyphCount: Int32;
    FGvarSharedTupleCount: Int32;
    FGvarSharedTuples: array of array of Int16;  { [sharedTupleIdx][axis] = F2.14 }
    FGvarDataOffsets: array of UInt32;           { glyph data offsets (glyphCount+1) }
    FGvarDataArrayBase: Int32;                   { gvarBase + offsetToGlyphVariationData }
    FGvarBase: Int32;
    FGvarLongOffsets: Boolean;                   { True = uint32 offsets, False = uint16 * 2 }
    { HVAR 表 }
    FHvarParsed: Boolean;
    FHvarAxisCount: Int32;
    FHvarRegions: array of array of Int16;       { [regionIdx][axis] = F2.14 start/end/peak }
    FHvarItemCount: Int32;                       { per-item delta count }
    FHvarDeltas: array of array of Int16;        { [outerIdx][innerIdx] = delta }
    FHvarDeltaBits: Int32;                       { 0 = int16 deltas, 1 = int32 }
    FHvarIndexMap: array of UInt32;              { glyph → deltaSetIndex (outer<<16|inner) }
    FHvarIndexFormat: Int32;                     { DeltaSetIndexMap entry format }
    { CFF 表 (OpenType CFF outlines) }
    FCffParsed: Boolean;
    FCffGlyphCount: Int32;
    FCffCharStringsBase: Int32;                  { CFF table base + CharStrings offset }
    FCffCharStringOffsets: array of UInt32;      { per-glyph charstring offset (glyphCount+1) }
    FCffDefaultWidthX: Int32;
    FCffNominalWidthX: Int32;
    FCffGlobalSubrs: array of record             { global subroutines }
      Data: array of Byte;
    end;
    FCffLocalSubrs: array of record              { local subroutines }
      Data: array of Byte;
    end;
    { CFF2 表 (OpenType CFF2 outlines) }
    FCff2Parsed: Boolean;
    FCff2GlyphCount: Int32;
    FCff2TableBase: Int32;                       { CFF2 table absolute offset }
    FCff2CharStringsBase: Int32;
    FCff2CharStringOffsets: array of UInt32;
    FCff2GlobalSubrs: array of record
      Data: array of Byte;
    end;
    FCff2LocalSubrs: array of record             { per-FD local subroutines }
      Data: array of Byte;
    end;
    FCff2FDCount: Int32;
    FCff2FDSelectFormat: Int32;
    FCff2FDSelectData: array of Byte;            { raw FDSelect bytes after format }
    FCff2FDSelectGlyphCount: Int32;
    { CFF2 variation store }
    FCff2VStoreParsed: Boolean;
    FCff2AxisCount: Int32;
    FCff2RegionCount: Int32;
    FCff2Regions: array of record                { [regionCount] }
      Axes: array of record                     { [axisCount] }
        Start, Peak, EndCoord: Int16;           { raw F2DOT14 values }
      end;
    end;
    FCff2VStoreDataCount: Int32;                 { ItemVariationData 子表数 }
    FCff2VStoreDataSubtables: array of record    { [dataCount] }
      RegionIndices: array of UInt16;            { 该子表引用的 region 索引 }
      RegionIndexCount: Int32;
      ItemCount: Int32;
      Deltas: array of Int16;                   { [itemCount * regionIndexCount] }
    end;
    { name 表 }
    FFamilyName: string;
    FSubfamilyName: string;
    FFullName: string;
    FPostScriptName: string;
    { post 表 }
    FHasPostTable: Boolean;
    FIsFixedPitch: Boolean;
    FUnderlinePosition: Int16;
    FUnderlineThickness: Int16;
    FValid: Boolean;
    FLastError: string;
    procedure ParseHeader;
    procedure ParseTableDirectory;
    function FindTable(ATag: UInt32): Int32;
    procedure ParseHead;
    procedure ParseHhea;
    procedure ParseMaxp;
    procedure ParseCmap;
    procedure ParseLoca;
    procedure ParseHmtx;
    procedure ParseOs2;
    procedure ParseGpos;
    procedure ParseGsub;
    procedure ParseFvar;
    procedure ParseAvar;
    procedure ParseGvar;
    procedure ParseHvar;
    procedure ParseCpal;
    procedure ParseColr;
    procedure ParseCbdt;
    procedure ParseCff;
    function CffGlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;
    procedure ParseCff2;
    function Cff2GlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;
    procedure ParseName;
    procedure ParsePost;
    function ReadUInt16BE(AOffset: Int32): UInt16;
    function ReadUInt32BE(AOffset: Int32): UInt32;
    function ReadInt16BE(AOffset: Int32): Int16;
    function ReadUInt8(AOffset: Int32): Byte;
    function ReadFixed(AOffset: Int32): Single;
    procedure ParseGlyphOutlineSimple(AOffset, AEndPointCount: Int32;
      out AOutline: TFontGlyphOutline);
    procedure ParseCompoundComponents(AOffset: Int32;
      out AComponents: TFontCompoundComponentArray);
    function ExpandCompoundOutline(
      const AComponents: TFontCompoundComponentArray): TFontGlyphOutline;
    function CoverageIndex(ACovOffset, AGlyphId: Int32): Int32;
    function ClassDefClassId(AClassDefOffset, AGlyphId: Int32): Int32;
    function ReadAnchor(AOffset: Int32): TFontAnchor;
    { Helpers for ContextSubst/ContextPos offset computation }
    function CtxRuleSetArrBase(const ASub: TFontContextSubtable): Int32;
    function CtxClassSetArrBase(const ASub: TFontContextSubtable): Int32;
    procedure ParseContextSubtable(AOffset, AFormat: Int32; AIsChained: Boolean;
      var ATarget: TFontContextSubtableArray);
    {** 从 Points 重新计算 XMin/YMin/XMax/YMax 边界框 }
    procedure RecalcOutlineBounds(var AOutline: TFontGlyphOutline);
  public
    {** 从文件路径加载字体 }
    constructor Create(const AFilePath: string);
    {** 从内存数据加载字体（AData 不复制，调用方需保活） }
    constructor CreateFromMemory(const AData: array of Byte);
    destructor Destroy; override;

    {** 字体是否成功加载 }
    function IsValid: Boolean;
    {** 最后一次加载错误信息 }
    function LastError: string;
    {** 字体格式 }
    function Format: TFontFileFormat;
    {** 字体级指标 }
    function Metrics: TFontMetrics;
    {** 字形总数 }
    function GlyphCount: UInt32;
    {** Unicode codepoint → glyph index (0 = .notdef) }
    function LookupCodepoint(ACodepoint: UInt32): UInt32;
    {** 字形水平度量 }
    function GlyphHorizontalMetric(AGlyphIndex: UInt32): TFontHorizontalMetric;
    {** 字形指标（边界框 + 步进，font units） }
    function GlyphMetrics(AGlyphIndex: UInt32): TFontGlyphMetrics;
    {** 提取字形轮廓（简单字形 + 复合字形展开） }
    function GlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;

    {** 是否包含 kern 对数据（GPOS PairPos） }
    function HasKernPairs: Boolean;
    {** 是否包含连字数据（GSUB Ligature） }
    function HasLigatures: Boolean;
    {** 查找 kern 对调整值（font units，0 = 无调整） }
    function LookupKern(ALeftGlyph, ARightGlyph: UInt16): Int16;
    {** 查找连字替换。输入字形序列匹配时返回替换字形索引。
        不匹配返回 0。 }
    function LookupLigature(const AGlyphs: array of UInt16): UInt16;
    {** 查找连字替换（带长度参数，避免数组长度查询）。 }
    function LookupLigature(const AGlyphs: array of UInt16; ACount: Int32): UInt16;

    {** 是否包含 GSUB SingleSubst 数据 }
    function HasSingleSubst: Boolean;
    function SingleSubstSubtableCount: Int32;
    {** 查找 SingleSubst 替换。不匹配返回 0。 }
    function LookupSingleSubst(AGlyphId: UInt16): UInt16;
    {** 在指定 subtable 索引处查找 SingleSubst 替换。不匹配返回 0。 }
    function LookupSingleSubstAt(AIndex: Int32; AGlyphId: UInt16): UInt16;
    {** 是否包含 GPOS SinglePos 数据 }
    function HasSinglePos: Boolean;
    {** 查找 SinglePos XAdvance 调整值。不匹配返回 0。 }
    function LookupSinglePosXAdvance(AGlyphId: UInt16): Int16;
    {** 是否包含 GPOS MarkToBase 数据 }
    function HasMarkToBase: Boolean;
    {** 查找 MarkToBase 锚点。不匹配返回 (0,0)。 }
    function LookupMarkToBase(AMarkGlyph, ABaseGlyph: UInt16): TFontAnchor;
    {** 是否包含 GPOS MarkToMark 数据 }
    function HasMarkToMark: Boolean;
    {** 查找 MarkToMark 锚点。不匹配返回 (0,0)。 }
    function LookupMarkToMark(AMarkGlyph, ABaseMarkGlyph: UInt16): TFontAnchor;
    {** 是否包含 GPOS CursivePos 数据 }
    function HasCursivePos: Boolean;
    {** CursivePos Entry/Exit 锚点查询 }
    function LookupCursivePosEntryAnchor(AGlyph: UInt16): TFontAnchor;
    function LookupCursivePosExitAnchor(AGlyph: UInt16): TFontAnchor;
    {** GSUB MultipleSubst }
    function HasMultipleSubst: Boolean;
    function LookupMultipleSubst(AGlyphId: UInt16): TFontGlyphIdArray;
    {** GSUB AlternateSubst }
    function HasAlternateSubst: Boolean;
    function LookupAlternateSubst(AGlyphId: UInt16): TFontGlyphIdArray;
    {** GPOS MarkToLig }
    function HasMarkToLig: Boolean;
    function LookupMarkToLig(AMarkGlyph, ALigatureGlyph, AComponentIndex: UInt16): TFontAnchor;
    {** GSUB ContextSubst }
    function HasContextSubst: Boolean;
    function ContextSubstCount: Int32;
    function GetContextSubstFmt(AIndex: Int32): Int32;
    function GetContextSubstRuleSetCount(AIndex: Int32): Int32;
    function GetContextSubstForGlyph(AIndex: Int32; AGlyphId: UInt16): TFontContextLookupRecordArray;
    {** 匹配 ContextSubst 规则（完整输入序列匹配）。
        AGlyphs: 完整字形序列，APosition: 当前检查位置。
        返回匹配的 lookup records（空数组 = 不匹配）。 }
    function MatchContextSubst(AIndex: Int32;
      const AGlyphs: array of UInt16; APosition: Int32): TFontContextLookupRecordArray;
    {** 应用 ContextSubst 引用的 lookup。支持 SingleSubst (type 1)。
        返回替换后的 glyph ID；不支持的 lookup type 返回原始 glyph。 }
    function ApplyContextSubstLookup(ALookupIndex: Int32; AGlyphId: UInt16): UInt16;
    {** 应用 ContextSubst 引用的 lookup，返回 glyph 数组。
        SingleSubst → 1 个 glyph；MultipleSubst → N 个 glyph；
        Ligature → 1 个 glyph（需要上下文，暂只处理 MultipleSubst）。 }
    function ApplyContextSubstLookupMulti(ALookupIndex: Int32;
      AGlyphId: UInt16): TFontGlyphIdArray;
    procedure GetContextSubstInfo(AIndex: Int32;
      out AInputGlyphCount, ASubstCount: Int32);
    function GetContextSubstLookup(AIndex, ASubIndex: Int32;
      out ASeqIdx, ALookupIdx: UInt16): Boolean;
    function GetContextSubstInputCoverage(AIndex, ASubIndex: Int32): Int32;
    {** GPOS ContextPos }
    function HasContextPos: Boolean;
    function ContextPosCount: Int32;
    procedure GetContextPosInfo(AIndex: Int32;
      out AInputGlyphCount, APosCount: Int32);
    function GetContextPosLookup(AIndex, ASubIndex: Int32;
      out ASeqIdx, ALookupIdx: UInt16): Boolean;
    function GetContextPosInputCoverage(AIndex, ASubIndex: Int32): Int32;
    {** 是否包含 GPOS PairPos Fmt1 数据 }
    function HasKernFmt1Pairs: Boolean;
    {** 查找 PairPos Fmt1 kern 值。不匹配返回 0。 }
    function LookupKernFmt1(ALeftGlyph, ARightGlyph: UInt16): Int16;
    {** 是否包含 Feature List 中的指定 tag }
    function HasFeatureTag(ATag: UInt32): Boolean;
    function HasFeatureKern: Boolean;
    function HasFeatureMark: Boolean;
    function HasFeatureMkmk: Boolean;

    {** COLR: 是否有颜色层数据 }
    function HasColorLayers: Boolean;
    {** COLR: 获取 base glyph 的颜色层。无层返回空数组。 }
    function GetColorLayers(AGlyphId: UInt16): TFontColorLayerArray;
    {** CPAL: 是否有调色板数据 }
    function HasPalette: Boolean;
    {** CPAL: 获取调色板颜色数 }
    function ColorsPerPalette: Int32;
    {** CPAL: 获取指定调色板中指定索引的颜色。BGRA 顺序。 }
    function GetPaletteColor(APaletteIndex, AColorIndex: Int32): TFontPaletteColor;

    {** CBDT/CBLC: 是否有位图 strike 数据 }
    function HasBitmapStrikes: Boolean;
    {** CBDT/CBLC: 获取位图字形数据。无数据返回空 PngData。 }
    function GetBitmapGlyph(AGlyphId: UInt16): TFontBitmapGlyph;

    {** cmap Format 14 (IVS) }
    function HasFmt14: Boolean;
    function LookupIVS(ABaseCodepoint, AVariationSelector: UInt32): UInt32;

    {** name 表查询 }
    function FamilyName: string;
    function SubfamilyName: string;
    function FullName: string;
    function PostScriptName: string;

    {** post 表 }
    function HasPostTable: Boolean;
    function IsFixedPitch: Boolean;
    function UnderlinePosition: Int16;
    function UnderlineThickness: Int16;

    {** fvar 表 }
    function HasFvar: Boolean;
    function HasCff2: Boolean;
    function FvarAxisCount: Int32;
    function VariationAxisCount: Int32;
    function GetFvarAxis(AIndex: Int32): TFontVariationAxis;
    function FindFvarAxisByTag(ATag: UInt32): Int32;

    {** Variation store }
    function HasVariationStore: Boolean;
    function VariationRegionCount: Int32;
    function CalcRegionScalar(ARegionIndex: Int32;
      const ACoords: array of Single): Single;

    {** avar 表 }
    function HasAvar: Boolean;
    function NormalizeAxisValue(AAxisIndex: Int32; AUserValue: Single): Single;

    {** fvar 实例 }
    function FvarInstanceCount: Int32;
    function GetFvarInstance(AIndex: Int32): TFontNamedInstance;

    {** Variable font advance delta }
    function HasGvar: Boolean;
    function HasHvar: Boolean;
    procedure ApplyGvarDeltas(AGlyphIndex: UInt32;
      var AOutline: TFontGlyphOutline; const ACoords: array of Single);
    function CalcHvarAdvanceDelta(AGlyphIndex: UInt32;
      const ACoords: array of Single): Single;
    procedure SetVariationCoords(const ACoords: array of Single);

    {** CFF2 }
    function Cff2FontDictCount: Int32;
    function GetCff2GlyphFD(AGlyphIndex: UInt32): Int32;
    function GetCff2FontDict(AIndex: Int32): TFontCff2FontDict;
  end;

implementation

{ ========================================================================= }
{ 内部读取 helpers                                                          }
{ ========================================================================= }

function SwapUInt16(AValue: UInt16): UInt16;
begin
  Result := ((AValue and $FF) shl 8) or ((AValue shr 8) and $FF);
end;

function SwapUInt32(AValue: UInt32): UInt32;
begin
  Result := ((AValue and $FF) shl 24) or
            (((AValue shr 8) and $FF) shl 16) or
            (((AValue shr 16) and $FF) shl 8) or
            ((AValue shr 24) and $FF);
end;

function SwapInt16(AValue: Int16): Int16;
begin
  Result := Int16(SwapUInt16(UInt16(AValue)));
end;

{ ========================================================================= }
{ TTFontFace 构造/析构                                                      }
{ ========================================================================= }

constructor TTFontFace.Create(const AFilePath: string);
var
  LStream: IStream;
  LSize: Int64;
begin
  inherited Create;
  FValid := False;
  FTTCFaceOffset := 0;
  FHasFmt4 := False;
  FHasFmt12 := False;
  FLastError := '';

  if not FsExists(AFilePath) then
    Exit;

  try
    LStream := FsOpen(AFilePath, [fmRead]);
    try
      LSize := LStream.GetSize;
      if LSize < 12 then
        Exit;
      SetLength(FData, LSize);
      FDataLength := LSize;
      LStream.Read(FData[0], LSize);
    finally
      LStream := nil;
    end;
  except
    Exit;
  end;

  try
    ParseHeader;
    ParseTableDirectory;
    { name、post、OS/2、cmap 表不依赖轮廓格式，始终解析 }
    try
      ParseName;
    except
    end;
    try
      ParsePost;
    except
    end;
    try
      ParseOs2;
    except
    end;
    try
      ParseCmap;
    except
    end;
    { CFF2 字体优先检测 }
    if (FFormat = fffOpenTypeCff) and (FindTable(TABLE_TAG_CFF2) >= 0) then
    begin
      try ParseHead; except end;
      try ParseHhea; except end;
      try ParseMaxp; except end;
      try ParseHmtx; except end;
      try ParseCff2; except end;
      try ParseFvar; except end;
      try ParseAvar; except end;
      FValid := (Length(FFamilyName) > 0) and (FCff2GlyphCount > 0);
      Exit;
    end;
    { CFF 字体：解析 head/hhea/hmtx/CFF 轮廓 }
    if FFormat = fffOpenTypeCff then
    begin
      try ParseHead; except end;
      try ParseHhea; except end;
      try ParseMaxp; except end;
      try ParseHmtx; except end;
      try ParseCff; except end;
      try ParseGpos; except end;
      try ParseGsub; except end;
      try ParseFvar; except end;
      try ParseAvar; except end;
      FValid := (Length(FFamilyName) > 0) and (FCffGlyphCount > 0);
      Exit;
    end;
    { 只支持 TrueType glyf 轮廓的完整解析 }
    if not (FFormat in [fffTrueType]) then
    begin
      FValid := Length(FFamilyName) > 0;
      Exit;
    end;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseLoca;
    ParseHmtx;
    try
      ParseGpos;
    except
    end;
    try
      ParseGsub;
    except
    end;
    try
      ParseFvar;
    except
    end;
    try
      ParseAvar;
    except
    end;
    try
      ParseGvar;
    except
    end;
    try
      ParseHvar;
    except
    end;
    try
      ParseCpal;
    except
    end;
    try
      ParseColr;
    except
    end;
    try
      ParseCbdt;
    except
    end;
    FValid := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FValid := False;
    end;
  end;
end;

constructor TTFontFace.CreateFromMemory(const AData: array of Byte);
var
  LLen: Int32;
begin
  inherited Create;
  FValid := False;
  FTTCFaceOffset := 0;
  FHasFmt4 := False;
  FHasFmt12 := False;
  FLastError := '';

  LLen := Length(AData);
  if LLen < 12 then
    Exit;

  SetLength(FData, LLen);
  FDataLength := LLen;
  Move(AData[0], FData[0], LLen);

  try
    ParseHeader;
    ParseTableDirectory;
    { name、post、OS/2、cmap 表不依赖轮廓格式，始终解析 }
    try
      ParseName;
    except
    end;
    try
      ParsePost;
    except
    end;
    try
      ParseOs2;
    except
    end;
    try
      ParseCmap;
    except
    end;
    { CFF2 字体优先检测 }
    if (FFormat = fffOpenTypeCff) and (FindTable(TABLE_TAG_CFF2) >= 0) then
    begin
      try ParseHead; except end;
      try ParseHhea; except end;
      try ParseMaxp; except end;
      try ParseHmtx; except end;
      try ParseCff2; except end;
      try ParseFvar; except end;
      try ParseAvar; except end;
      FValid := (Length(FFamilyName) > 0) and (FCff2GlyphCount > 0);
      Exit;
    end;
    { CFF 字体：解析 head/hhea/hmtx/CFF 轮廓 }
    if FFormat = fffOpenTypeCff then
    begin
      try ParseHead; except end;
      try ParseHhea; except end;
      try ParseMaxp; except end;
      try ParseHmtx; except end;
      try ParseCff; except end;
      try ParseGpos; except end;
      try ParseGsub; except end;
      try ParseFvar; except end;
      try ParseAvar; except end;
      FValid := (Length(FFamilyName) > 0) and (FCffGlyphCount > 0);
      Exit;
    end;
    { 只支持 TrueType glyf 轮廓的完整解析 }
    if not (FFormat in [fffTrueType]) then
    begin
      FValid := Length(FFamilyName) > 0;
      Exit;
    end;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseLoca;
    ParseHmtx;
    try
      ParseGpos;
    except
    end;
    try
      ParseGsub;
    except
    end;
    try
      ParseFvar;
    except
    end;
    try
      ParseAvar;
    except
    end;
    try
      ParseGvar;
    except
    end;
    try
      ParseHvar;
    except
    end;
    FValid := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FValid := False;
    end;
  end;
end;

destructor TTFontFace.Destroy;
var
  I: Int32;
begin
  SetLength(FData, 0);
  SetLength(FTables, 0);
  SetLength(FHmtx, 0);
  SetLength(FLocaOffsets, 0);
  SetLength(FCmapFmt4.StartCode, 0);
  SetLength(FCmapFmt4.EndCode, 0);
  SetLength(FCmapFmt4.IdDelta, 0);
  SetLength(FCmapFmt4.IdRangeOffset, 0);
  SetLength(FCmapFmt4.GlyphIdArray, 0);
  SetLength(FCmapFmt12.Groups, 0);
  { fvar cleanup }
  SetLength(FFvarAxes, 0);
  for I := 0 to High(FFvarInstances) do
    SetLength(FFvarInstances[I].Coordinates, 0);
  SetLength(FFvarInstances, 0);
  { avar cleanup }
  for I := 0 to High(FAvarSegmentMaps) do
    SetLength(FAvarSegmentMaps[I], 0);
  SetLength(FAvarSegmentMaps, 0);
  inherited Destroy;
end;

{ ========================================================================= }
{ 底层读取                                                                   }
{ ========================================================================= }

function TTFontFace.ReadUInt8(AOffset: Int32): Byte;
begin
  if (AOffset < 0) or (AOffset >= FDataLength) then
    raise EFontError.Create('TTF read offset out of bounds');
  Result := FData[AOffset];
end;

function TTFontFace.ReadUInt16BE(AOffset: Int32): UInt16;
begin
  if (AOffset < 0) or (AOffset + 1 >= FDataLength) then
    raise EFontError.Create('TTF read UInt16 out of bounds');
  Result := (UInt16(FData[AOffset]) shl 8) or UInt16(FData[AOffset + 1]);
end;

function TTFontFace.ReadUInt32BE(AOffset: Int32): UInt32;
begin
  if (AOffset < 0) or (AOffset + 3 >= FDataLength) then
    raise EFontError.Create('TTF read UInt32 out of bounds');
  Result := (UInt32(FData[AOffset]) shl 24) or
            (UInt32(FData[AOffset + 1]) shl 16) or
            (UInt32(FData[AOffset + 2]) shl 8) or
            UInt32(FData[AOffset + 3]);
end;

function TTFontFace.ReadInt16BE(AOffset: Int32): Int16;
begin
  Result := Int16(ReadUInt16BE(AOffset));
end;

function TTFontFace.ReadFixed(AOffset: Int32): Single;
var
  LRaw: UInt32;
begin
  LRaw := ReadUInt32BE(AOffset);
  Result := (LRaw shr 16) + (LRaw and $FFFF) / 65536.0;
end;

{ ========================================================================= }
{ 表解析                                                                     }
{ ========================================================================= }

procedure TTFontFace.ParseHeader;
var
  LMagic: UInt32;
  LFaceCount, LFaceMagic: UInt32;
begin
  FFormat := fffUnknown;
  LMagic := ReadUInt32BE(0);
  if LMagic = FONT_MAGIC_TRUETYPE then
    FFormat := fffTrueType
  else if LMagic = FONT_MAGIC_OTTO then
    FFormat := fffOpenTypeCff
  else if LMagic = FONT_MAGIC_TTC then
  begin
    { TTC: 读取第一个 face 偏移 }
    LFaceCount := ReadUInt32BE(8);
    if LFaceCount < 1 then
      Exit;
    FTTCFaceOffset := ReadUInt32BE(12);
    if (FTTCFaceOffset < 12) or (FTTCFaceOffset >= FDataLength - 12) then
    begin
      FTTCFaceOffset := 0;
      Exit;
    end;
    LFaceMagic := ReadUInt32BE(FTTCFaceOffset);
    if LFaceMagic = FONT_MAGIC_TRUETYPE then
      FFormat := fffTrueType
    else if LFaceMagic = FONT_MAGIC_OTTO then
      FFormat := fffOpenTypeCff
    else
      FTTCFaceOffset := 0;
  end;
end;

procedure TTFontFace.ParseTableDirectory;
var
  I: Int32;
  LOffset: Int32;
begin
  FTableCount := ReadUInt16BE(4 + FTTCFaceOffset);
  if (FTableCount < 1) or (FTableCount > 256) then
    raise EFontError.Create('Invalid table count');

  SetLength(FTables, FTableCount);
  LOffset := 12 + FTTCFaceOffset;
  for I := 0 to FTableCount - 1 do
  begin
    FTables[I].Tag := ReadUInt32BE(LOffset);
    FTables[I].Offset := ReadUInt32BE(LOffset + 8);
    FTables[I].Length := ReadUInt32BE(LOffset + 12);
    Inc(LOffset, 16);
  end;
end;

function TTFontFace.FindTable(ATag: UInt32): Int32;
var
  I: Int32;
begin
  for I := 0 to FTableCount - 1 do
    if FTables[I].Tag = ATag then
      Exit(I);
  Result := -1;
end;

procedure TTFontFace.ParseHead;
var
  LIdx, LOff: Int32;
begin
  LIdx := FindTable(TABLE_TAG_HEAD);
  if LIdx < 0 then
    raise EFontError.Create('head table not found');

  LOff := Int32(FTables[LIdx].Offset);
  if Int32(FTables[LIdx].Length) < 54 then
    raise EFontError.Create('head table too short');

  FHead.MajorVersion := ReadUInt16BE(LOff);
  FHead.MinorVersion := ReadUInt16BE(LOff + 2);
  FHead.FontRevision := ReadUInt32BE(LOff + 4);
  FHead.UnitsPerEm := ReadUInt16BE(LOff + 18);
  FHead.Created := ReadUInt32BE(LOff + 20); // 高 32 位，简化
  FHead.Modified := ReadUInt32BE(LOff + 24); // 高 32 位，简化
  FHead.XMin := ReadInt16BE(LOff + 36);
  FHead.YMin := ReadInt16BE(LOff + 38);
  FHead.XMax := ReadInt16BE(LOff + 40);
  FHead.YMax := ReadInt16BE(LOff + 42);
  FHead.MacStyle := ReadUInt16BE(LOff + 44);
  FHead.LowestRecPpem := ReadUInt16BE(LOff + 46);
  FHead.IndexToLocFormat := ReadInt16BE(LOff + 50);
end;

procedure TTFontFace.ParseHhea;
var
  LIdx, LOff: Int32;
begin
  LIdx := FindTable(TABLE_TAG_HHEA);
  if LIdx < 0 then
    raise EFontError.Create('hhea table not found');

  LOff := Int32(FTables[LIdx].Offset);
  FHhea.Ascender := ReadInt16BE(LOff + 4);
  FHhea.Descender := ReadInt16BE(LOff + 6);
  FHhea.LineGap := ReadInt16BE(LOff + 8);
  FHhea.AdvanceWidthMax := ReadUInt16BE(LOff + 10);
  FHhea.MinLeftSideBearing := ReadInt16BE(LOff + 12);
  FHhea.MinRightSideBearing := ReadInt16BE(LOff + 14);
  FHhea.XMaxExtent := ReadInt16BE(LOff + 16);
  FHhea.NumberOfHMetrics := ReadUInt16BE(LOff + 34);
end;

procedure TTFontFace.ParseMaxp;
var
  LIdx, LOff: Int32;
begin
  LIdx := FindTable(TABLE_TAG_MAXP);
  if LIdx < 0 then
    raise EFontError.Create('maxp table not found');

  LOff := Int32(FTables[LIdx].Offset);
  FMaxp.NumGlyphs := ReadUInt16BE(LOff + 4);
end;

procedure TTFontFace.ParseCmap;
var
  LIdx, LOff: Int32;
  LSubtableCount: Int32;
  I, LSubtableOffset: Int32;
  LPlatformId, LEncodingId: Int32;
  LFormat: UInt16;
  LSubtableBase: Int32;
  LLength, LSegCount: Int32;
  J, LGlyphIdOffset, LIdRangeOffsetBase: Int32;
  LStartCode, LEndCode: UInt16;
  LIdDelta, LIdRangeOff: UInt16;
  LGlyphId: UInt16;
  LGroupCount, K: Int32;
begin
  LIdx := FindTable(TABLE_TAG_CMAP);
  if LIdx < 0 then
    Exit; // 没有 cmap 不致命

  LOff := Int32(FTables[LIdx].Offset);
  LSubtableCount := ReadUInt16BE(LOff + 2);

  FHasFmt4 := False;
  FHasFmt12 := False;
  FHasFmt14 := False;

  for I := 0 to LSubtableCount - 1 do
  begin
    LSubtableOffset := LOff + 4 + I * 8;
    LPlatformId := ReadUInt16BE(LSubtableOffset);
    LEncodingId := ReadUInt16BE(LSubtableOffset + 2);
    LSubtableBase := LOff + Int32(ReadUInt32BE(LSubtableOffset + 4));

    LFormat := ReadUInt16BE(LSubtableBase);

    // 优先选 Format 4（BMP 最常用）
    if (LFormat = CMAP_FORMAT_4) and (not FHasFmt4) then
    begin
      // 选择合适的子表：
      // - Platform 0 (Unicode) 任何 encoding
      // - Platform 3 (Windows) encoding 1 (Unicode BMP)
      if (LPlatformId = CMAP_PLATFORM_UNICODE) or
         ((LPlatformId = CMAP_PLATFORM_WINDOWS) and
          (LEncodingId = CMAP_ENCODING_WINDOWS_UNICODE_BMP)) then
      begin
        LLength := ReadUInt16BE(LSubtableBase + 2);
        LSegCount := ReadUInt16BE(LSubtableBase + 6) div 2;
        if LSegCount <= 0 then
          Continue;

        SetLength(FCmapFmt4.StartCode, LSegCount);
        SetLength(FCmapFmt4.EndCode, LSegCount);
        SetLength(FCmapFmt4.IdDelta, LSegCount);
        SetLength(FCmapFmt4.IdRangeOffset, LSegCount);
        FCmapFmt4.SegmentCount := LSegCount;

        // EndCode
        LIdRangeOffsetBase := LSubtableBase + 14 + LSegCount * 2; // +2 for reserved padding
        for J := 0 to LSegCount - 1 do
          FCmapFmt4.EndCode[J] := ReadUInt16BE(LSubtableBase + 14 + J * 2);

        // StartCode
        for J := 0 to LSegCount - 1 do
          FCmapFmt4.StartCode[J] := ReadUInt16BE(LIdRangeOffsetBase + J * 2);

        // IdDelta
        LIdRangeOffsetBase := LIdRangeOffsetBase + LSegCount * 2;
        for J := 0 to LSegCount - 1 do
          FCmapFmt4.IdDelta[J] := ReadInt16BE(LIdRangeOffsetBase + J * 2);

        // IdRangeOffset
        LIdRangeOffsetBase := LIdRangeOffsetBase + LSegCount * 2;
        for J := 0 to LSegCount - 1 do
          FCmapFmt4.IdRangeOffset[J] := ReadUInt16BE(LIdRangeOffsetBase + J * 2);

        // GlyphIdArray（IdRangeOffset 引用的数组）
        LGlyphIdOffset := LIdRangeOffsetBase + LSegCount * 2;
        LLength := LLength - (LGlyphIdOffset - LSubtableBase);
        if LLength > 0 then
        begin
          SetLength(FCmapFmt4.GlyphIdArray, LLength div 2);
          for J := 0 to (LLength div 2) - 1 do
            FCmapFmt4.GlyphIdArray[J] := ReadUInt16BE(LGlyphIdOffset + J * 2);
        end;

        FHasFmt4 := True;
      end;
    end;

    // Format 12（全 Unicode，SMP emoji 等）
    if (LFormat = CMAP_FORMAT_12) and (not FHasFmt12) then
    begin
      if (LPlatformId = CMAP_PLATFORM_UNICODE) or
         (LPlatformId = CMAP_PLATFORM_WINDOWS) then
      begin
        LGroupCount := Int32(ReadUInt32BE(LSubtableBase + 12));
        if (LGroupCount > 0) and (LGroupCount < 65536) then
        begin
          SetLength(FCmapFmt12.Groups, LGroupCount);
          for K := 0 to LGroupCount - 1 do
          begin
            J := LSubtableBase + 16 + K * 12;
            FCmapFmt12.Groups[K].StartCharCode := ReadUInt32BE(J);
            FCmapFmt12.Groups[K].EndCharCode := ReadUInt32BE(J + 4);
            FCmapFmt12.Groups[K].StartGlyphCode := ReadUInt32BE(J + 8);
          end;
          FHasFmt12 := True;
        end;
      end;
    end;

    // Format 14 (IVS - Variation Selector)
    if LFormat = 14 then
    begin
      if not FHasFmt14 then
      begin
        FFmt14Base := LSubtableBase; { Format 14 子表基址，偏移量相对此处 }
        LGroupCount := Int32(ReadUInt32BE(LSubtableBase + 6)); { numVarSelectorRecords }
        if (LGroupCount > 0) and (LGroupCount < 10000) then
        begin
          SetLength(FFmt14Records, LGroupCount);
          for K := 0 to LGroupCount - 1 do
          begin
            J := LSubtableBase + 10 + K * 11;
            if J + 11 > FDataLength then Break;
            FFmt14Records[K].VarSelector :=
              (UInt32(ReadUInt8(J)) shl 16) or
              (UInt32(ReadUInt8(J + 1)) shl 8) or
              UInt32(ReadUInt8(J + 2));
            FFmt14Records[K].DefaultUVSOffset := LSubtableBase + Int32(ReadUInt32BE(J + 3));
            FFmt14Records[K].NonDefaultUVSOffset := LSubtableBase + Int32(ReadUInt32BE(J + 7));
          end;
          FHasFmt14 := True;
        end;
      end;
    end;
  end;
end;

procedure TTFontFace.ParseLoca;
var
  LIdx, LOff: Int32;
  I, LEntryCount: Int32;
begin
  LIdx := FindTable(TABLE_TAG_LOCA);
  if LIdx < 0 then
    Exit; // 非致命

  LOff := Int32(FTables[LIdx].Offset);
  LEntryCount := FMaxp.NumGlyphs + 1;
  SetLength(FLocaOffsets, LEntryCount);

  if FHead.IndexToLocFormat = 0 then
  begin
    // Short format: offsets / 2
    for I := 0 to LEntryCount - 1 do
      FLocaOffsets[I] := UInt32(ReadUInt16BE(LOff + I * 2)) * 2;
  end
  else
  begin
    // Long format: direct offsets
    for I := 0 to LEntryCount - 1 do
      FLocaOffsets[I] := ReadUInt32BE(LOff + I * 4);
  end;
end;

procedure TTFontFace.ParseHmtx;
var
  LIdx, LOff: Int32;
  I: Int32;
begin
  LIdx := FindTable(TABLE_TAG_HMTX);
  if LIdx < 0 then
    Exit; // 非致命

  LOff := Int32(FTables[LIdx].Offset);
  SetLength(FHmtx, FMaxp.NumGlyphs);

  for I := 0 to FHhea.NumberOfHMetrics - 1 do
  begin
    FHmtx[I].AdvanceWidth := ReadUInt16BE(LOff + I * 4);
    FHmtx[I].LeftSideBearing := ReadInt16BE(LOff + I * 4 + 2);
  end;

  // 超过 NumberOfHMetrics 的字形共享最后一个 advance width
  if FHhea.NumberOfHMetrics < FMaxp.NumGlyphs then
  begin
    for I := FHhea.NumberOfHMetrics to FMaxp.NumGlyphs - 1 do
    begin
      FHmtx[I].AdvanceWidth := FHmtx[FHhea.NumberOfHMetrics - 1].AdvanceWidth;
      FHmtx[I].LeftSideBearing := ReadInt16BE(
        LOff + FHhea.NumberOfHMetrics * 4 +
        (I - FHhea.NumberOfHMetrics) * 2);
    end;
  end;
end;

procedure TTFontFace.ParseOs2;
var
  LIdx, LOff, I: Int32;
begin
  LIdx := FindTable(TABLE_TAG_OS2);
  if LIdx < 0 then
    Exit; // OS/2 可选

  LOff := Int32(FTables[LIdx].Offset);
  if Int32(FTables[LIdx].Length) < 78 then
    Exit;

  FOs2.XAvgCharWidth := ReadInt16BE(LOff + 2);
  FOs2.UsWeightClass := ReadUInt16BE(LOff + 4);
  FOs2.UsWidthClass := ReadUInt16BE(LOff + 6);
  FOs2.FsSelection := ReadUInt16BE(LOff + 62);
  FOs2.STypoAscender := ReadInt16BE(LOff + 68);
  FOs2.STypoDescender := ReadInt16BE(LOff + 70);
  FOs2.STypoLineGap := ReadInt16BE(LOff + 72);

  { panose 在 offset 32，共 10 字节 }
  if Int32(FTables[LIdx].Length) >= 42 then
  begin
    for I := 0 to 9 do
      FOs2.Panose[I] := ReadUInt8(LOff + 32 + I);
  end;

  if Int32(FTables[LIdx].Length) >= 96 then
  begin
    FOs2.SxHeight := ReadInt16BE(LOff + 86);
    FOs2.SCapHeight := ReadInt16BE(LOff + 88);
  end;
end;

{ ========================================================================= }
{ GPOS / GSUB 解析（kern pairs + ligatures）                                 }
{ ========================================================================= }

procedure TTFontFace.ParseGpos;
var
  LTableIdx, LGposOff: Int32;
  LLookupListOff, LLookupCount, LI, LJ: Int32;
  LLookupOff, LLookupType, LSubtableCount: Int32;
  LSubOff, LSub, LPosFmt, LCovOff, LValFmt1, LValFmt2, LSubFmt: Int32;
  LEntrySize, LXAdvBit, LIdx: Int32;
  LSubtable: TFontPairPosSubtable;
  LSinglePos: TFontSinglePosSubtable;
  LMarkBase: TFontMarkToBaseSubtable;
  LMarkMark: TFontMarkToMarkSubtable;
  LCursive: TFontCursivePosSubtable;
  LFmt1: TFontPairPosFmt1Subtable;
  LMarkCovOff, LBaseCovOff, LClassCount: Int32;
  LMarkArrOff, LBaseArrOff: Int32;
  LFeatListOff, LFeatCount: Int32;
  procedure ParseValueFormat(ACurSub, AValFmtOffset: Int32;
    out AXAdvOffset, ARecSize: Int32);
  var
    LSize: Int32;
  begin
    AXAdvOffset := -1;
    ARecSize := 0;
    LValFmt1 := ReadUInt16BE(ACurSub + AValFmtOffset);
    if (LValFmt1 and $0001) <> 0 then Inc(ARecSize, 2);
    if (LValFmt1 and $0002) <> 0 then Inc(ARecSize, 2);
    if (LValFmt1 and $0004) <> 0 then begin AXAdvOffset := ARecSize; Inc(ARecSize, 2); end;
    if (LValFmt1 and $0008) <> 0 then Inc(ARecSize, 2);
  end;
begin
  LTableIdx := FindTable(TABLE_TAG_GPOS);
  if LTableIdx < 0 then
    Exit;
  LGposOff := FTables[LTableIdx].Offset;
  if FDataLength < LGposOff + 10 then
    Exit;
  LLookupListOff := LGposOff + ReadUInt16BE(LGposOff + 8);
  if FDataLength < LLookupListOff + 2 then
    Exit;
  LLookupCount := ReadUInt16BE(LLookupListOff);
  SetLength(FPairPosSubtables, 0);
  SetLength(FSinglePosSubtables, 0);
  SetLength(FMarkToBaseSubtables, 0);
  SetLength(FMarkToMarkSubtables, 0);

  for LI := 0 to LLookupCount - 1 do
  begin
    if FDataLength < LLookupListOff + 4 + LI * 2 then
      Continue;
    LLookupOff := LLookupListOff + ReadUInt16BE(LLookupListOff + 2 + LI * 2);
    if FDataLength < LLookupOff + 6 then
      Continue;
    LLookupType := ReadUInt16BE(LLookupOff);
    LSubtableCount := ReadUInt16BE(LLookupOff + 4);

    { GPOS Type 1: SinglePos }
    if LLookupType = GPOS_LOOKUP_SINGLE_ADJUSTMENT then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSinglePos.Format := ReadUInt16BE(LSubOff);
        LCovOff := ReadUInt16BE(LSubOff + 2);
        if (LSinglePos.Format < 1) or (LSinglePos.Format > 2) then
          Continue;
        ParseValueFormat(LSubOff, 4, LXAdvBit, LEntrySize);
        if LEntrySize <= 0 then
          Continue;
        LSinglePos.CoverageOffset := LSubOff + LCovOff;
        LSinglePos.XAdvanceOffset := LXAdvBit;
        LSinglePos.ValueRecordSize := LEntrySize;
        if LSinglePos.Format = 1 then
          LSinglePos.ValueOffset := LSubOff + 6
        else
          LSinglePos.ValueOffset := LSubOff + 8;
        LSinglePos.ValueFormat := ReadUInt16BE(LSubOff + 4);
        LIdx := Length(FSinglePosSubtables);
        SetLength(FSinglePosSubtables, LIdx + 1);
        FSinglePosSubtables[LIdx] := LSinglePos;
      end;
    end
    { GPOS Type 2: PairPos (existing Fmt2 + new Fmt1) }
    else if LLookupType = GPOS_LOOKUP_PAIR_ADJUSTMENT then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 8 then
          Continue;
        LPosFmt := ReadUInt16BE(LSub);
        LCovOff := ReadUInt16BE(LSub + 2);
        LValFmt1 := ReadUInt16BE(LSub + 4);
        LValFmt2 := ReadUInt16BE(LSub + 6);

        if LPosFmt = 2 then
        begin
          { Class-based PairPos (existing code) }
          if FDataLength < LSub + 16 then
            Continue;
          LXAdvBit := -1;
          LEntrySize := 0;
          if (LValFmt1 and $0001) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt1 and $0002) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt1 and $0004) <> 0 then begin LXAdvBit := LEntrySize; Inc(LEntrySize, 2); end;
          if (LValFmt1 and $0008) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0001) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0002) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0004) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0008) <> 0 then Inc(LEntrySize, 2);
          if (LEntrySize <= 0) or (LXAdvBit < 0) then
            Continue;
          LSubtable.BaseOffset := LSub;
          LSubtable.CoverageOffset := LSub + LCovOff;
          LSubtable.ClassDef1Offset := LSub + ReadUInt16BE(LSub + 8);
          LSubtable.ClassDef2Offset := LSub + ReadUInt16BE(LSub + 10);
          LSubtable.Class2Count := ReadUInt16BE(LSub + 14);
          LSubtable.ValueRecordSize := LEntrySize;
          LSubtable.XAdvanceOffset := LXAdvBit;
          LIdx := Length(FPairPosSubtables);
          SetLength(FPairPosSubtables, LIdx + 1);
          FPairPosSubtables[LIdx] := LSubtable;
        end
        else if LPosFmt = 1 then
        begin
          { Pair-based PairPos (Fmt1) }
          if FDataLength < LSub + 10 then
            Continue;
          ParseValueFormat(LSub, 4, LXAdvBit, LEntrySize);
          if LEntrySize <= 0 then
            Continue;
          LFmt1.CoverageOffset := LSub + LCovOff;
          LFmt1.ValueFormat1 := LValFmt1;
          LFmt1.ValueFormat2 := LValFmt2;
          LFmt1.PairSetCount := ReadUInt16BE(LSub + 8);
          LFmt1.PairSetOffsetsOffset := LSub; { PairSet offsets are relative to subtable start }
          LFmt1.XAdvance1Offset := LXAdvBit;
          LFmt1.ValueRecord1Size := LEntrySize;
          LIdx := Length(FPairPosFmt1Subtables);
          SetLength(FPairPosFmt1Subtables, LIdx + 1);
          FPairPosFmt1Subtables[LIdx] := LFmt1;
        end;
      end;
    end
    { GPOS Type 3: CursivePos }
    else if LLookupType = GPOS_LOOKUP_CURSIVE then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 6 then
          Continue;
        if ReadUInt16BE(LSubOff) <> 1 then
          Continue;
        LCovOff := ReadUInt16BE(LSubOff + 2);
        LCursive.CoverageOffset := LSubOff + LCovOff;
        LCursive.EntryExitCount := ReadUInt16BE(LSubOff + 4);
        LCursive.EntryExitArrayOffset := LSubOff + 6;
        LIdx := Length(FCursivePosSubtables);
        SetLength(FCursivePosSubtables, LIdx + 1);
        FCursivePosSubtables[LIdx] := LCursive;
      end;
    end
    { GPOS Type 4: MarkToBase }
    else if LLookupType = GPOS_LOOKUP_MARK_TO_BASE then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 12 then
          Continue;
        if ReadUInt16BE(LSubOff) <> 1 then
          Continue;
        LMarkCovOff := ReadUInt16BE(LSubOff + 2);
        LBaseCovOff := ReadUInt16BE(LSubOff + 4);
        LClassCount := ReadUInt16BE(LSubOff + 6);
        LMarkArrOff := ReadUInt16BE(LSubOff + 8);
        LBaseArrOff := ReadUInt16BE(LSubOff + 10);
        if (LClassCount <= 0) or (LClassCount > 256) then
          Continue;
        LMarkBase.MarkCoverageOffset := LSubOff + LMarkCovOff;
        LMarkBase.BaseCoverageOffset := LSubOff + LBaseCovOff;
        LMarkBase.ClassCount := LClassCount;
        LMarkBase.MarkArrayOffset := LSubOff + LMarkArrOff;
        LMarkBase.BaseArrayOffset := LSubOff + LBaseArrOff;
        LIdx := Length(FMarkToBaseSubtables);
        SetLength(FMarkToBaseSubtables, LIdx + 1);
        FMarkToBaseSubtables[LIdx] := LMarkBase;
      end;
    end
    { GPOS Type 6: MarkToMark }
    else if LLookupType = GPOS_LOOKUP_MARK_TO_MARK then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 12 then
          Continue;
        if ReadUInt16BE(LSubOff) <> 1 then
          Continue;
        LMarkCovOff := ReadUInt16BE(LSubOff + 2);
        LBaseCovOff := ReadUInt16BE(LSubOff + 4);
        LClassCount := ReadUInt16BE(LSubOff + 6);
        LMarkArrOff := ReadUInt16BE(LSubOff + 8);
        LBaseArrOff := ReadUInt16BE(LSubOff + 10);
        if (LClassCount <= 0) or (LClassCount > 256) then
          Continue;
        LMarkMark.Mark1CoverageOffset := LSubOff + LMarkCovOff;
        LMarkMark.Mark2CoverageOffset := LSubOff + LBaseCovOff;
        LMarkMark.ClassCount := LClassCount;
        LMarkMark.Mark1ArrayOffset := LSubOff + LMarkArrOff;
        LMarkMark.Mark2ArrayOffset := LSubOff + LBaseArrOff;
        LIdx := Length(FMarkToMarkSubtables);
        SetLength(FMarkToMarkSubtables, LIdx + 1);
        FMarkToMarkSubtables[LIdx] := LMarkMark;
      end;
    end
    { GPOS Type 5: MarkToLigature }
    else if LLookupType = GPOS_LOOKUP_MARK_TO_LIGATURE then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 12 then
          Continue;
        if ReadUInt16BE(LSubOff) <> 1 then
          Continue;
        LMarkCovOff := ReadUInt16BE(LSubOff + 2);
        LBaseCovOff := ReadUInt16BE(LSubOff + 4);
        LClassCount := ReadUInt16BE(LSubOff + 6);
        LMarkArrOff := ReadUInt16BE(LSubOff + 8);
        LBaseArrOff := ReadUInt16BE(LSubOff + 10);
        if (LClassCount <= 0) or (LClassCount > 256) then
          Continue;
        LIdx := Length(FMarkToLigatureSubtables);
        SetLength(FMarkToLigatureSubtables, LIdx + 1);
        FMarkToLigatureSubtables[LIdx].MarkCoverageOffset := LSubOff + LMarkCovOff;
        FMarkToLigatureSubtables[LIdx].LigatureCoverageOffset := LSubOff + LBaseCovOff;
        FMarkToLigatureSubtables[LIdx].ClassCount := LClassCount;
        FMarkToLigatureSubtables[LIdx].MarkArrayOffset := LSubOff + LMarkArrOff;
        FMarkToLigatureSubtables[LIdx].LigatureArrayOffset := LSubOff + LBaseArrOff;
      end;
    end
    { GPOS Type 7: ContextPos }
    else if LLookupType = GPOS_LOOKUP_CONTEXT_POS then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if (LSubFmt < 1) or (LSubFmt > 3) then
          Continue;
        ParseContextSubtable(LSubOff, LSubFmt, False, FContextPosSubtables);
      end;
    end
    { GPOS Type 8: ChainedContextPos }
    else if LLookupType = GPOS_LOOKUP_CHAINED_CONTEXT_POS then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if (LSubFmt < 1) or (LSubFmt > 3) then
          Continue;
        ParseContextSubtable(LSubOff, LSubFmt, True, FContextPosSubtables);
      end;
    end;
  end;

  { Parse FeatureList for feature tag queries. }
  if FDataLength < LGposOff + 10 then
    Exit;
  LFeatListOff := LGposOff + ReadUInt16BE(LGposOff + 6); { FeatureList offset at GPOS+6 }
  if (LFeatListOff > 0) and (FDataLength >= LFeatListOff + 2) then
  begin
    LFeatCount := ReadUInt16BE(LFeatListOff);
    for LI := 0 to LFeatCount - 1 do
    begin
      if FDataLength < LFeatListOff + 2 + LI * 6 + 4 then
        Continue;
      LIdx := Length(FFeatureTags);
      SetLength(FFeatureTags, LIdx + 1);
      FFeatureTags[LIdx] := ReadUInt32BE(LFeatListOff + 2 + LI * 6);
    end;
  end;
end;

procedure TTFontFace.ParseGsub;
var
  LTableIdx, LGsubOff: Int32;
  LLookupListOff, LLookupCount, LI, LJ: Int32;
  LLookupOff, LLookupType, LSubtableCount: Int32;
  LSubOff, LSub, LSubFmt, LCovOff, LLSCount, LIdx: Int32;
  LFeatListOff, LFeatCount: Int32;
  LSubtable: TFontLigatureSubtable;
  LSingleSubst: TFontSingleSubstSubtable;
begin
  LTableIdx := FindTable(TABLE_TAG_GSUB);
  if LTableIdx < 0 then
    Exit;
  LGsubOff := FTables[LTableIdx].Offset;
  if FDataLength < LGsubOff + 10 then
    Exit;
  LLookupListOff := LGsubOff + ReadUInt16BE(LGsubOff + 8);
  if FDataLength < LLookupListOff + 2 then
    Exit;
  LLookupCount := ReadUInt16BE(LLookupListOff);
  SetLength(FLigatureSubtables, 0);
  SetLength(FSingleSubstSubtables, 0);
  SetLength(FLookupEntries, LLookupCount);

  for LI := 0 to LLookupCount - 1 do
  begin
    if FDataLength < LLookupListOff + 4 + LI * 2 then
      Continue;
    LLookupOff := LLookupListOff + ReadUInt16BE(LLookupListOff + 2 + LI * 2);
    if FDataLength < LLookupOff + 6 then
      Continue;
    LLookupType := ReadUInt16BE(LLookupOff);
    LSubtableCount := ReadUInt16BE(LLookupOff + 4);

    { 记录 lookup 映射（供 ContextSubst 引用） }
    FLookupEntries[LI].LookupType := LLookupType;
    FLookupEntries[LI].FirstSubtableIndex := -1;
    FLookupEntries[LI].SubtableCount := 0;

    { GSUB Type 1: SingleSubst }
    if LLookupType = GSUB_LOOKUP_SINGLE_SUBST then
    begin
      FLookupEntries[LI].FirstSubtableIndex := Length(FSingleSubstSubtables);
      FLookupEntries[LI].SubtableCount := 0;
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        LCovOff := ReadUInt16BE(LSubOff + 2);
        if (LSubFmt < 1) or (LSubFmt > 2) then
          Continue;
        LSingleSubst.Format := LSubFmt;
        LSingleSubst.CoverageOffset := LSubOff + LCovOff;
        if LSubFmt = 1 then
        begin
          if FDataLength < LSubOff + 6 then
            Continue;
          LSingleSubst.DeltaGlyphID := ReadInt16BE(LSubOff + 4);
          LSingleSubst.GlyphCount := 0;
          LSingleSubst.GlyphArrayOffset := 0;
        end
        else
        begin
          if FDataLength < LSubOff + 6 then
            Continue;
          LSingleSubst.DeltaGlyphID := 0;
          LSingleSubst.GlyphCount := ReadUInt16BE(LSubOff + 4);
          LSingleSubst.GlyphArrayOffset := LSubOff + 6;
        end;
        LIdx := Length(FSingleSubstSubtables);
        SetLength(FSingleSubstSubtables, LIdx + 1);
        FSingleSubstSubtables[LIdx] := LSingleSubst;
        Inc(FLookupEntries[LI].SubtableCount);
      end;
    end
    { GSUB Type 2: MultipleSubst }
    else if LLookupType = GSUB_LOOKUP_MULTIPLE_SUBST then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if LSubFmt <> 1 then
          Continue;
        LIdx := Length(FMultipleSubstSubtables);
        SetLength(FMultipleSubstSubtables, LIdx + 1);
        FMultipleSubstSubtables[LIdx].BaseOffset := LSubOff;
        FMultipleSubstSubtables[LIdx].CoverageOffset := LSubOff + ReadUInt16BE(LSubOff + 2);
        FMultipleSubstSubtables[LIdx].SequenceCount := ReadUInt16BE(LSubOff + 4);
        FMultipleSubstSubtables[LIdx].SequenceOffsetsOffset := LSubOff + 6;
      end;
    end
    { GSUB Type 3: AlternateSubst }
    else if LLookupType = 3 then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if LSubFmt <> 1 then
          Continue;
        LIdx := Length(FAlternateSubstSubtables);
        SetLength(FAlternateSubstSubtables, LIdx + 1);
        FAlternateSubstSubtables[LIdx].BaseOffset := LSubOff;
        FAlternateSubstSubtables[LIdx].CoverageOffset := LSubOff + ReadUInt16BE(LSubOff + 2);
        FAlternateSubstSubtables[LIdx].AlternateSetCount := ReadUInt16BE(LSubOff + 4);
        FAlternateSubstSubtables[LIdx].AlternateSetOffsetsOffset := LSubOff + 6;
      end;
    end
    { GSUB Type 4: Ligature (existing code) }
    else if LLookupType = GSUB_LOOKUP_LIGATURE then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        LCovOff := ReadUInt16BE(LSub + 2);
        LLSCount := ReadUInt16BE(LSub + 4);
        if LSubFmt <> 1 then
          Continue;
        LSubtable.BaseOffset := LSub;
        LSubtable.CoverageOffset := LSub + LCovOff;
        LSubtable.LigatureSetCount := LLSCount;
        LIdx := Length(FLigatureSubtables);
        SetLength(FLigatureSubtables, LIdx + 1);
        FLigatureSubtables[LIdx] := LSubtable;
      end;
    end
    { GSUB Type 5: ContextSubst }
    else if LLookupType = GSUB_LOOKUP_CONTEXT_SUBST then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if (LSubFmt < 1) or (LSubFmt > 3) then
          Continue;
        ParseContextSubtable(LSubOff, LSubFmt, False, FContextSubstSubtables);
      end;
    end
    { GSUB Type 6: ChainedContextSubst }
    else if LLookupType = GSUB_LOOKUP_CHAINED_CONTEXT_SUBST then
    begin
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
        if FDataLength < LSubOff + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSubOff);
        if (LSubFmt < 1) or (LSubFmt > 3) then
          Continue;
        ParseContextSubtable(LSubOff, LSubFmt, True, FContextSubstSubtables);
      end;
    end
  end;

  { Parse GSUB FeatureList for feature tag queries. }
  if FDataLength < LGsubOff + 10 then
    Exit;
  LFeatListOff := LGsubOff + ReadUInt16BE(LGsubOff + 6); { FeatureList offset at GSUB+6 }
  if (LFeatListOff > 0) and (FDataLength >= LFeatListOff + 2) then
  begin
    LFeatCount := ReadUInt16BE(LFeatListOff);
    for LI := 0 to LFeatCount - 1 do
    begin
      if FDataLength < LFeatListOff + 2 + LI * 6 + 4 then
        Continue;
      LIdx := Length(FFeatureTags);
      SetLength(FFeatureTags, LIdx + 1);
      FFeatureTags[LIdx] := ReadUInt32BE(LFeatListOff + 2 + LI * 6);
    end;
  end;
end;

{ ========================================================================= }
{ fvar 表解析（Variable Font Axes + Named Instances）                       }
{ ========================================================================= }

procedure TTFontFace.ParseFvar;
var
  LIdx, LOff: Int32;
  LAxesOff, LAxisCount, LAxisSize, LInstCount, LInstSize: Int32;
  I, J, LAxisBase, LInstBase: Int32;
  LRaw: UInt32;
begin
  FFvarAxisCount := 0;
  FFvarInstanceCount := 0;
  SetLength(FFvarAxes, 0);
  SetLength(FFvarInstances, 0);

  LIdx := FindTable(TABLE_TAG_FVAR);
  if LIdx < 0 then
    Exit;

  LOff := Int32(FTables[LIdx].Offset);
  if FDataLength < LOff + 16 then
    Exit;

  { fvar header: MajorVersion(2) + MinorVersion(2) + AxesArrayOffset(2) + Reserved(2) +
    AxisCount(2) + AxisSize(2) + InstanceCount(2) + InstanceSize(2) }
  LAxesOff := LOff + ReadUInt16BE(LOff + 4);
  LAxisCount := ReadUInt16BE(LOff + 8);
  LAxisSize := ReadUInt16BE(LOff + 10);
  LInstCount := ReadUInt16BE(LOff + 12);
  LInstSize := ReadUInt16BE(LOff + 14);

  if (LAxisCount < 1) or (LAxisCount > 64) then
    Exit;
  if LAxisSize < 20 then
    Exit;

  { 解析 axes }
  FFvarAxisCount := LAxisCount;
  SetLength(FFvarAxes, LAxisCount);
  for I := 0 to LAxisCount - 1 do
  begin
    LAxisBase := LAxesOff + I * LAxisSize;
    if FDataLength < LAxisBase + 20 then
      Break;
    FFvarAxes[I].Tag := ReadUInt32BE(LAxisBase);
    { Fixed 16.16 → Single }
    LRaw := ReadUInt32BE(LAxisBase + 4);
    FFvarAxes[I].MinValue := SmallInt(LRaw shr 16) + (LRaw and $FFFF) / 65536.0;
    LRaw := ReadUInt32BE(LAxisBase + 8);
    FFvarAxes[I].DefaultValue := SmallInt(LRaw shr 16) + (LRaw and $FFFF) / 65536.0;
    LRaw := ReadUInt32BE(LAxisBase + 12);
    FFvarAxes[I].MaxValue := SmallInt(LRaw shr 16) + (LRaw and $FFFF) / 65536.0;
    FFvarAxes[I].AxisNameID := ReadUInt16BE(LAxisBase + 18);
  end;

  { 解析 named instances }
  if (LInstCount < 1) or (LInstSize < 4 + LAxisCount * 4) then
  begin
    FFvarInstanceCount := 0;
    Exit;
  end;

  FFvarInstanceCount := LInstCount;
  SetLength(FFvarInstances, LInstCount);
  LInstBase := LAxesOff + LAxisCount * LAxisSize;
  for I := 0 to LInstCount - 1 do
  begin
    LInstBase := LAxesOff + LAxisCount * LAxisSize + I * LInstSize;
    if FDataLength < LInstBase + 4 + LAxisCount * 4 then
      Break;
    FFvarInstances[I].NameID := ReadUInt16BE(LInstBase);
    { skip Flags (uint16) at offset 2 }
    SetLength(FFvarInstances[I].Coordinates, LAxisCount);
    for J := 0 to LAxisCount - 1 do
    begin
      LRaw := ReadUInt32BE(LInstBase + 4 + J * 4);
      FFvarInstances[I].Coordinates[J] := SmallInt(LRaw shr 16) + (LRaw and $FFFF) / 65536.0;
    end;
  end;
end;

{ ========================================================================= }
{ avar 表解析（Axis Variation Mapping）                                     }
{ ========================================================================= }

procedure TTFontFace.ParseAvar;
var
  LIdx, LOff: Int32;
  LVersion, LAxisCount, LSegMapOff: Int32;
  I, J, LPairCount, LSegBase: Int32;
begin
  FAvarAxisCount := 0;
  SetLength(FAvarSegmentMaps, 0);

  if FFvarAxisCount < 1 then
    Exit; { 需要先解析 fvar }

  LIdx := FindTable(TABLE_TAG_AVAR);
  if LIdx < 0 then
    Exit;

  LOff := Int32(FTables[LIdx].Offset);
  if FDataLength < LOff + 8 then
    Exit;

  LVersion := ReadUInt16BE(LOff);
  if LVersion <> 1 then
    Exit; { 只支持 version 1 }
  LAxisCount := ReadUInt16BE(LOff + 6);
  if LAxisCount <> FFvarAxisCount then
    Exit;

  FAvarAxisCount := LAxisCount;
  SetLength(FAvarSegmentMaps, LAxisCount);
  LSegMapOff := LOff + 8;

  for I := 0 to LAxisCount - 1 do
  begin
    if FDataLength < LSegMapOff + 2 then
      Break;
    LPairCount := ReadUInt16BE(LSegMapOff);
    SetLength(FAvarSegmentMaps[I], LPairCount);
    LSegBase := LSegMapOff + 2;
    for J := 0 to LPairCount - 1 do
    begin
      if FDataLength < LSegBase + 4 then
        Break;
      { avar segment map 使用 F2Dot14 格式（2 字节），值 = raw / 16384 }
      FAvarSegmentMaps[I][J].FromCoord := ReadInt16BE(LSegBase) / 16384.0;
      FAvarSegmentMaps[I][J].ToCoord := ReadInt16BE(LSegBase + 2) / 16384.0;
      Inc(LSegBase, 4);
    end;
    LSegMapOff := LSegBase;
  end;
end;

{ ========================================================================= }
{ name 表解析（Font Metadata）                                              }
{ ========================================================================= }

procedure TTFontFace.ParseName;
var
  LIdx, LOff: Int32;
  LFormat, LCount, LStringOffset: Int32;
  I, LNameOffset: Int32;
  LPlatformID, LEncodingID, LLanguageID, LNameID, LLength, LOffset: Int32;
  LNameBytes: array of Byte;
  LNameStr: string;
  J: Int32;

  function ReadNameString(AOffset, ALength: Int32; APlatformID, AEncodingID: Int32): string;
  var
    K: Int32;
    LChars: array of WideChar;
    LCharCount: Int32;
  begin
    Result := '';
    if (APlatformID = 3) and (AEncodingID = 1) then
    begin
      { Windows Unicode BMP: UTF-16BE }
      LCharCount := ALength div 2;
      SetLength(LChars, LCharCount);
      for K := 0 to LCharCount - 1 do
        LChars[K] := WideChar(ReadUInt16BE(AOffset + K * 2));
      Result := UTF8Encode(WideString(LChars));
    end
    else if (APlatformID = 1) and (AEncodingID = 0) then
    begin
      { Macintosh Roman: ASCII }
      SetLength(Result, ALength);
      for K := 0 to ALength - 1 do
        Result[K + 1] := Chr(ReadUInt8(AOffset + K));
    end
    else if APlatformID = 0 then
    begin
      { Unicode platform: UTF-16BE }
      LCharCount := ALength div 2;
      SetLength(LChars, LCharCount);
      for K := 0 to LCharCount - 1 do
        LChars[K] := WideChar(ReadUInt16BE(AOffset + K * 2));
      Result := UTF8Encode(WideString(LChars));
    end;
  end;

begin
  FFamilyName := '';
  FSubfamilyName := '';
  FFullName := '';
  FPostScriptName := '';

  LIdx := FindTable(TABLE_TAG_NAME);
  if LIdx < 0 then
    Exit;

  LOff := Int32(FTables[LIdx].Offset);
  if FDataLength < LOff + 6 then
    Exit;

  LFormat := ReadUInt16BE(LOff);
  LCount := ReadUInt16BE(LOff + 2);
  LStringOffset := ReadUInt16BE(LOff + 4);

  if (LCount < 1) or (LCount > 4096) then
    Exit;

  for I := 0 to LCount - 1 do
  begin
    LNameOffset := LOff + 6 + I * 12;
    if FDataLength < LNameOffset + 12 then
      Break;

    LPlatformID := ReadUInt16BE(LNameOffset);
    LEncodingID := ReadUInt16BE(LNameOffset + 2);
    LLanguageID := ReadUInt16BE(LNameOffset + 4);
    LNameID := ReadUInt16BE(LNameOffset + 6);
    LLength := ReadUInt16BE(LNameOffset + 8);
    LOffset := ReadUInt16BE(LNameOffset + 10);

    { 优先使用 Windows platform (3) + Unicode BMP (1)，语言 0x0409 (English US) }
    if (LPlatformID = 3) and (LEncodingID = 1) then
    begin
      LNameStr := ReadNameString(LOff + LStringOffset + LOffset, LLength, LPlatformID, LEncodingID);
      case LNameID of
        1: if (FFamilyName = '') or (LLanguageID = $0409) then FFamilyName := LNameStr;
        2: if (FSubfamilyName = '') or (LLanguageID = $0409) then FSubfamilyName := LNameStr;
        4: if (FFullName = '') or (LLanguageID = $0409) then FFullName := LNameStr;
        6: if (FPostScriptName = '') or (LLanguageID = $0409) then FPostScriptName := LNameStr;
      end;
    end
    { 回退到 Macintosh platform (1) + Roman (0) }
    else if (LPlatformID = 1) and (LEncodingID = 0) then
    begin
      LNameStr := ReadNameString(LOff + LStringOffset + LOffset, LLength, LPlatformID, LEncodingID);
      case LNameID of
        1: if FFamilyName = '' then FFamilyName := LNameStr;
        2: if FSubfamilyName = '' then FSubfamilyName := LNameStr;
        4: if FFullName = '' then FFullName := LNameStr;
        6: if FPostScriptName = '' then FPostScriptName := LNameStr;
      end;
    end;
  end;
end;

{ ========================================================================= }
{ post 表解析（PostScript Metadata）                                        }
{ ========================================================================= }

procedure TTFontFace.ParsePost;
var
  LIdx, LOff: Int32;
begin
  FHasPostTable := False;
  FIsFixedPitch := False;
  FUnderlinePosition := 0;
  FUnderlineThickness := 0;

  LIdx := FindTable(TABLE_TAG_POST);
  if LIdx < 0 then
    Exit;

  LOff := Int32(FTables[LIdx].Offset);
  if FDataLength < LOff + 32 then
    Exit;

  FHasPostTable := True;

  { post 表格式：
    Offset 0:  MajorVersion (Fixed 16.16)
    Offset 4:  MinorVersion (Fixed 16.16)
    Offset 8:  italicAngle (Fixed 16.16)
    Offset 12: underlinePosition (Int16)
    Offset 14: underlineThickness (Int16)
    Offset 16: isFixedPitch (UInt32)
    ... }
  FUnderlinePosition := ReadInt16BE(LOff + 12);
  FUnderlineThickness := ReadInt16BE(LOff + 14);
  FIsFixedPitch := ReadUInt32BE(LOff + 16) <> 0;
end;

function TTFontFace.LookupKern(ALeftGlyph, ARightGlyph: UInt16): Int16;
var
  LI: Int32;
  LSub: TFontPairPosSubtable;
  LClass1, LClass2: UInt16;

  function GetClass(ACdOffset, AGlyphId: Int32): UInt16;
  var
    LFmt, LSG, LGC, LRC, LRR, LESG, LESC: Int32;
  begin
    if FDataLength < ACdOffset + 4 then
      Exit(0);
    LFmt := ReadUInt16BE(ACdOffset);
    if LFmt = 1 then
    begin
      LSG := ReadUInt16BE(ACdOffset + 2);
      LGC := ReadUInt16BE(ACdOffset + 4);
      if (AGlyphId >= LSG) and (AGlyphId < LSG + LGC) then
        Result := ReadUInt16BE(ACdOffset + 6 + (AGlyphId - LSG) * 2)
      else
        Result := 0;
    end
    else if LFmt = 2 then
    begin
      LRC := ReadUInt16BE(ACdOffset + 2);
      for LRR := 0 to LRC - 1 do
      begin
        if FDataLength < ACdOffset + 4 + LRR * 6 + 6 then
          Break;
        LESG := ReadUInt16BE(ACdOffset + 4 + LRR * 6);
        LESC := ReadUInt16BE(ACdOffset + 4 + LRR * 6 + 2);
        if (AGlyphId >= LESG) and (AGlyphId <= LESC) then
          Exit(ReadUInt16BE(ACdOffset + 4 + LRR * 6 + 4));
      end;
      Result := 0;
    end
    else
      Result := 0;
  end;

begin
  Result := 0;
  for LI := 0 to High(FPairPosSubtables) do
  begin
    LSub := FPairPosSubtables[LI];
    // Use optimized CoverageIndex (binary search for Format 1).
    if CoverageIndex(LSub.CoverageOffset, ALeftGlyph) < 0 then
      Continue;
    // Get class1 and class2.
    LClass1 := GetClass(LSub.ClassDef1Offset, ALeftGlyph);
    LClass2 := GetClass(LSub.ClassDef2Offset, ARightGlyph);
    if (LClass1 * LSub.Class2Count + LClass2) < 0 then
      Continue;
    // Read kern value.
    if FDataLength < LSub.BaseOffset + 14 + (LClass1 * LSub.Class2Count + LClass2) * LSub.ValueRecordSize + LSub.XAdvanceOffset + 2 then
      Continue;
    Result := ReadInt16BE(LSub.BaseOffset + 14 +
      (LClass1 * LSub.Class2Count + LClass2) * LSub.ValueRecordSize +
      LSub.XAdvanceOffset);
    if Result <> 0 then
      Exit;
  end;
end;

function TTFontFace.LookupLigature(const AGlyphs: array of UInt16): UInt16;
var
  LI, LJ, LK, LM: Int32;
  LSub: TFontLigatureSubtable;
  LCovIdx: Int32;
  LLSOff, LLSCount, LLigOff, LCompCount: Int32;
  LMatch: Boolean;
begin
  Result := 0;
  if Length(AGlyphs) < 2 then
    Exit;

  for LI := 0 to High(FLigatureSubtables) do
  begin
    LSub := FLigatureSubtables[LI];
    // Use optimized CoverageIndex (binary search for Format 1).
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphs[0]);
    if LCovIdx < 0 then
      Continue;

    // Read LigatureSet[LCovIdx].
    if FDataLength < LSub.BaseOffset + 6 + LCovIdx * 2 + 2 then
      Continue;
    LLSOff := LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 6 + LCovIdx * 2);
    if FDataLength < LLSOff + 2 then
      Continue;
    LLSCount := ReadUInt16BE(LLSOff);

    // Try each Ligature in the set.
    for LJ := 0 to LLSCount - 1 do
    begin
      if FDataLength < LLSOff + 2 + LJ * 2 + 2 then
        Continue;
      LLigOff := LLSOff + ReadUInt16BE(LLSOff + 2 + LJ * 2);
      if FDataLength < LLigOff + 4 then
        Continue;
      LCompCount := ReadUInt16BE(LLigOff + 2);
      if LCompCount <> Length(AGlyphs) then
        Continue;
      // Match component glyphs (skip first, which is already matched by coverage).
      LMatch := True;
      for LK := 1 to LCompCount - 1 do
      begin
        LM := ReadUInt16BE(LLigOff + 4 + (LK - 1) * 2);
        if LM <> AGlyphs[LK] then
        begin
          LMatch := False;
          Break;
        end;
      end;
      if LMatch then
        Exit(ReadUInt16BE(LLigOff));
    end;
  end;
end;

function TTFontFace.LookupLigature(const AGlyphs: array of UInt16; ACount: Int32): UInt16;
var
  LI, LJ, LK, LM: Int32;
  LSub: TFontLigatureSubtable;
  LCovIdx: Int32;
  LLSOff, LLSCount, LLigOff, LCompCount: Int32;
  LMatch: Boolean;
begin
  Result := 0;
  if ACount < 2 then
    Exit;

  for LI := 0 to High(FLigatureSubtables) do
  begin
    LSub := FLigatureSubtables[LI];
    // Use optimized CoverageIndex (binary search for Format 1).
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphs[0]);
    if LCovIdx < 0 then
      Continue;

    // Read LigatureSet[LCovIdx].
    if FDataLength < LSub.BaseOffset + 6 + LCovIdx * 2 + 2 then
      Continue;
    LLSOff := LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 6 + LCovIdx * 2);
    if FDataLength < LLSOff + 2 then
      Continue;
    LLSCount := ReadUInt16BE(LLSOff);

    // Try each Ligature in the set.
    for LJ := 0 to LLSCount - 1 do
    begin
      if FDataLength < LLSOff + 2 + LJ * 2 + 2 then
        Continue;
      LLigOff := LLSOff + ReadUInt16BE(LLSOff + 2 + LJ * 2);
      if FDataLength < LLigOff + 4 then
        Continue;
      LCompCount := ReadUInt16BE(LLigOff + 2);
      if LCompCount <> ACount then
        Continue;
      // Match component glyphs (skip first, which is already matched by coverage).
      LMatch := True;
      for LK := 1 to LCompCount - 1 do
      begin
        LM := ReadUInt16BE(LLigOff + 4 + (LK - 1) * 2);
        if LM <> AGlyphs[LK] then
        begin
          LMatch := False;
          Break;
        end;
      end;
      if LMatch then
        Exit(ReadUInt16BE(LLigOff));
    end;
  end;
end;

function TTFontFace.HasKernPairs: Boolean;
begin
  Result := Length(FPairPosSubtables) > 0;
end;

function TTFontFace.HasLigatures: Boolean;
begin
  Result := Length(FLigatureSubtables) > 0;
end;

function TTFontFace.IsValid: Boolean;
begin
  Result := FValid;
end;

function TTFontFace.LastError: string;
begin
  Result := FLastError;
end;

function TTFontFace.Format: TFontFileFormat;
begin
  Result := FFormat;
end;

function TTFontFace.Metrics: TFontMetrics;
begin
  Result.UnitsPerEm := FHead.UnitsPerEm;
  Result.Ascender := FHhea.Ascender;
  Result.Descender := FHhea.Descender;
  Result.LineGap := FHhea.LineGap;
  Result.XMin := FHead.XMin;
  Result.YMin := FHead.YMin;
  Result.XMax := FHead.XMax;
  Result.YMax := FHead.YMax;
end;

function TTFontFace.GlyphCount: UInt32;
begin
  if FCff2GlyphCount > 0 then
    Result := FCff2GlyphCount
  else if FCffGlyphCount > 0 then
    Result := FCffGlyphCount
  else
    Result := FMaxp.NumGlyphs;
end;

function TTFontFace.LookupCodepoint(ACodepoint: UInt32): UInt32;
var
  J, LStart, LEnd, LMid: Int32;
  LStartCode, LEndCode: UInt16;
  LIdDelta, LIdRangeOff: UInt16;
  LOffset, LGlyphId: UInt32;
begin
  Result := 0; // .notdef

  // Format 12 优先（覆盖全 Unicode，包括 SMP）— binary search
  if FHasFmt12 then
  begin
    LStart := 0;
    LEnd := High(FCmapFmt12.Groups);
    while LStart <= LEnd do
    begin
      LMid := (LStart + LEnd) shr 1;
      if ACodepoint < FCmapFmt12.Groups[LMid].StartCharCode then
        LEnd := LMid - 1
      else if ACodepoint > FCmapFmt12.Groups[LMid].EndCharCode then
        LStart := LMid + 1
      else
      begin
        Result := FCmapFmt12.Groups[LMid].StartGlyphCode +
                  (ACodepoint - FCmapFmt12.Groups[LMid].StartCharCode);
        Exit;
      end;
    end;
  end;

  // Format 4（BMP）— binary search on segments
  if FHasFmt4 then
  begin
    LStart := 0;
    LEnd := FCmapFmt4.SegmentCount - 1;
    while LStart <= LEnd do
    begin
      LMid := (LStart + LEnd) shr 1;
      LStartCode := FCmapFmt4.StartCode[LMid];
      LEndCode := FCmapFmt4.EndCode[LMid];
      if LStartCode = $FFFF then
      begin
        // Sentinel segment — search left half
        LEnd := LMid - 1;
        Continue;
      end;
      if ACodepoint < LStartCode then
        LEnd := LMid - 1
      else if ACodepoint > LEndCode then
        LStart := LMid + 1
      else
      begin
        // Found segment containing ACodepoint
        LIdDelta := UInt16(FCmapFmt4.IdDelta[LMid]);
        LIdRangeOff := FCmapFmt4.IdRangeOffset[LMid];

        if LIdRangeOff = 0 then
        begin
          // 直接偏移
          LGlyphId := UInt16((ACodepoint + LIdDelta) and $FFFF);
          Result := LGlyphId;
          Exit;
        end
        else
        begin
          // 通过 IdRangeOffset 索引 GlyphIdArray
          // IdRangeOffset 是相对于自身位置的字节偏移
          // 具体公式：*(&IdRangeOffset[J] + (cp - startCode) + IdRangeOffset/2 - segCount)
{$PUSH}{$R-}  { 中间结果可能为负，UInt32 溢出是正常的 }
          LOffset := (ACodepoint - LStartCode) +
            (LIdRangeOff div 2) - (FCmapFmt4.SegmentCount - LMid);
{$POP}
          if LOffset < UInt32(Length(FCmapFmt4.GlyphIdArray)) then
          begin
            LGlyphId := FCmapFmt4.GlyphIdArray[LOffset];
            if LGlyphId <> 0 then
              LGlyphId := UInt16((LGlyphId + LIdDelta) and $FFFF);
            Result := LGlyphId;
          end;
          Exit;  // Found segment — exit regardless of offset bounds
        end;
      end;
    end;
  end;
end;

function TTFontFace.GlyphHorizontalMetric(AGlyphIndex: UInt32): TFontHorizontalMetric;
var
  LHvarDelta: Single;
begin
  if AGlyphIndex < UInt32(Length(FHmtx)) then
    Result := FHmtx[AGlyphIndex]
  else
  begin
    Result.AdvanceWidth := 0;
    Result.LeftSideBearing := 0;
  end;
  { 自动应用 HVAR delta（可变字体 advance width 调整） }
  if FHasVariationCoords and FHvarParsed then
  begin
    LHvarDelta := CalcHvarAdvanceDelta(AGlyphIndex, FVariationCoords);
    if LHvarDelta <> 0 then
      Result.AdvanceWidth := Result.AdvanceWidth + Round(LHvarDelta);
  end;
end;

function TTFontFace.GlyphMetrics(AGlyphIndex: UInt32): TFontGlyphMetrics;
var
  LOutline: TFontGlyphOutline;
  LHMetric: TFontHorizontalMetric;
begin
  Result.Width := 0;
  Result.Height := 0;
  Result.BearingX := 0;
  Result.BearingY := 0;
  Result.AdvanceWidth := 0;

  LHMetric := GlyphHorizontalMetric(AGlyphIndex);
  Result.AdvanceWidth := LHMetric.AdvanceWidth;
  Result.BearingX := LHMetric.LeftSideBearing;

  // 从轮廓中获取精确边界框
  LOutline := GlyphOutline(AGlyphIndex);
  if LOutline.ContourCount > 0 then
  begin
    Result.Width := LOutline.XMax - LOutline.XMin;
    Result.Height := LOutline.YMax - LOutline.YMin;
    Result.BearingX := LOutline.XMin;
    Result.BearingY := LOutline.YMax;
  end;
end;

{ ========================================================================= }
{ 字形轮廓提取                                                               }
{ ========================================================================= }

procedure TTFontFace.ParseGlyphOutlineSimple(AOffset, AEndPointCount: Int32;
  out AOutline: TFontGlyphOutline);
var
  LNumPoints, I, K: Int32;
  LFlags: array of Byte;
  LX, LY: Int16;
  LCursor: Int32;
  LInstrLen: UInt16;
  LRepeatCount: Byte;
begin
  // 读取轮廓终点索引
  SetLength(AOutline.ContourEnds, AEndPointCount);
  for I := 0 to AEndPointCount - 1 do
    AOutline.ContourEnds[I] := ReadUInt16BE(AOffset + I * 2);

  // 最后一个轮廓终点 + 1 = 总点数
  LNumPoints := 0;
  if AEndPointCount > 0 then
    LNumPoints := AOutline.ContourEnds[AEndPointCount - 1] + 1;

  if LNumPoints <= 0 then
  begin
    AOutline.ContourCount := 0;
    SetLength(AOutline.Points, 0);
    Exit;
  end;

  AOutline.ContourCount := AEndPointCount;
  SetLength(AOutline.Points, LNumPoints);

  // 读取指令长度并跳过指令
  LCursor := AOffset + AEndPointCount * 2;
  LInstrLen := ReadUInt16BE(LCursor);
  Inc(LCursor, 2 + LInstrLen);

  // 读取 flags（带重复标志展开）
  SetLength(LFlags, LNumPoints);
  I := 0;
  while I < LNumPoints do
  begin
    LFlags[I] := ReadUInt8(LCursor);
    Inc(LCursor);
    if (LFlags[I] and GLYF_FLAG_REPEAT) <> 0 then
    begin
      LRepeatCount := ReadUInt8(LCursor);
      Inc(LCursor);
      for K := 1 to LRepeatCount do
      begin
        if I + K < LNumPoints then
          LFlags[I + K] := LFlags[I];
      end;
      Inc(I, LRepeatCount);
    end;
    Inc(I);
  end;

  // 读取 X 坐标（delta 编码，短偏移或长偏移）
  LX := 0;
  for I := 0 to LNumPoints - 1 do
  begin
    if (LFlags[I] and GLYF_FLAG_X_SHORT) <> 0 then
    begin
      if (LFlags[I] and GLYF_FLAG_X_SAME) <> 0 then
        Inc(LX, ReadUInt8(LCursor))
      else
        Dec(LX, ReadUInt8(LCursor));
      Inc(LCursor);
    end
    else if (LFlags[I] and GLYF_FLAG_X_SAME) = 0 then
    begin
      Inc(LX, ReadInt16BE(LCursor));
      Inc(LCursor, 2);
    end;
    AOutline.Points[I].X := LX;
  end;

  // 读取 Y 坐标（同样 delta 编码）
  LY := 0;
  for I := 0 to LNumPoints - 1 do
  begin
    if (LFlags[I] and GLYF_FLAG_Y_SHORT) <> 0 then
    begin
      if (LFlags[I] and GLYF_FLAG_Y_SAME) <> 0 then
        Inc(LY, ReadUInt8(LCursor))
      else
        Dec(LY, ReadUInt8(LCursor));
      Inc(LCursor);
    end
    else if (LFlags[I] and GLYF_FLAG_Y_SAME) = 0 then
    begin
      Inc(LY, ReadInt16BE(LCursor));
      Inc(LCursor, 2);
    end;
    AOutline.Points[I].Y := LY;
  end;

  // 标记 on-curve 标志
  for I := 0 to LNumPoints - 1 do
    AOutline.Points[I].OnCurve := (LFlags[I] and GLYF_FLAG_ON_CURVE) <> 0;
end;

procedure TTFontFace.ParseCompoundComponents(AOffset: Int32;
  out AComponents: TFontCompoundComponentArray);
var
  LCursor: Int32;
  LFlags: UInt16;
  LCount: Int32;
begin
  SetLength(AComponents, 0);
  LCursor := AOffset;
  LCount := 0;

  repeat
    if LCount >= GLYF_COMPOUND_MAX_DEPTH then
      Break;

    SetLength(AComponents, LCount + 1);
    LFlags := ReadUInt16BE(LCursor);
    Inc(LCursor, 2);

    AComponents[LCount].GlyphIndex := ReadUInt16BE(LCursor);
    Inc(LCursor, 2);

    AComponents[LCount].ScaleX := 1.0;
    AComponents[LCount].ScaleY := 1.0;
    AComponents[LCount].ScaleXY := 0.0;
    AComponents[LCount].ScaleYX := 0.0;
    AComponents[LCount].UseMetrics := (LFlags and GLYF_COMPOUND_USE_METRICS) <> 0;

    // 读取偏移
    if (LFlags and GLYF_COMPOUND_ARGS_ARE_XY) <> 0 then
    begin
      if (LFlags and GLYF_COMPOUND_ARG_ARE_WORDS) <> 0 then
      begin
        AComponents[LCount].OffsetX := ReadInt16BE(LCursor);
        Inc(LCursor, 2);
        AComponents[LCount].OffsetY := ReadInt16BE(LCursor);
        Inc(LCursor, 2);
      end
      else
      begin
        AComponents[LCount].OffsetX := ShortInt(ReadUInt8(LCursor));
        Inc(LCursor);
        AComponents[LCount].OffsetY := ShortInt(ReadUInt8(LCursor));
        Inc(LCursor);
      end;
    end
    else
    begin
      // 点号索引模式（简化：不完整支持）
      if (LFlags and GLYF_COMPOUND_ARG_ARE_WORDS) <> 0 then
        Inc(LCursor, 4)
      else
        Inc(LCursor, 2);
      AComponents[LCount].OffsetX := 0;
      AComponents[LCount].OffsetY := 0;
    end;

    // 读取变换矩阵
    if (LFlags and GLYF_COMPOUND_HAVE_SCALE) <> 0
    then begin
      AComponents[LCount].ScaleX := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
      AComponents[LCount].ScaleY := AComponents[LCount].ScaleX;
    end
    else if (LFlags and GLYF_COMPOUND_HAVE_XY_SCALE) <> 0 then
    begin
      AComponents[LCount].ScaleX := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
      AComponents[LCount].ScaleY := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
    end
    else if (LFlags and GLYF_COMPOUND_HAVE_MATRIX) <> 0 then
    begin
      AComponents[LCount].ScaleX := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
      AComponents[LCount].ScaleXY := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
      AComponents[LCount].ScaleYX := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
      AComponents[LCount].ScaleY := ReadInt16BE(LCursor) / 16384.0;
      Inc(LCursor, 2);
    end;

    Inc(LCount);
  until (LFlags and GLYF_COMPOUND_MORE_COMPONENTS) = 0;

  SetLength(AComponents, LCount);
end;

function TTFontFace.ExpandCompoundOutline(
  const AComponents: TFontCompoundComponentArray): TFontGlyphOutline;
var
  LI, LJ: Int32;
  LPart: TFontGlyphOutline;
  LBasePointCount: Int32;
  LScaleX, LScaleY, LOffX, LOffY: Single;
begin
  Result := Default(TFontGlyphOutline);
  FontGlyphOutlineClear(Result);

  for LI := 0 to High(AComponents) do
  begin
    LPart := GlyphOutline(AComponents[LI].GlyphIndex);
    if LPart.ContourCount <= 0 then
      Continue;

    LBasePointCount := Length(Result.Points);
    SetLength(Result.Points, LBasePointCount + Length(LPart.Points));
    SetLength(Result.ContourEnds, Result.ContourCount + LPart.ContourCount);

    LScaleX := AComponents[LI].ScaleX;
    LScaleY := AComponents[LI].ScaleY;
    LOffX := AComponents[LI].OffsetX;
    LOffY := AComponents[LI].OffsetY;

    // 变换并追加点
    for LJ := 0 to High(LPart.Points) do
    begin
      Result.Points[LBasePointCount + LJ].X :=
        Round(LPart.Points[LJ].X * LScaleX + LPart.Points[LJ].Y *
          AComponents[LI].ScaleYX + LOffX);
      Result.Points[LBasePointCount + LJ].Y :=
        Round(LPart.Points[LJ].X * AComponents[LI].ScaleXY +
          LPart.Points[LJ].Y * LScaleY + LOffY);
      Result.Points[LBasePointCount + LJ].OnCurve := LPart.Points[LJ].OnCurve;
    end;

    // 追加轮廓终点
    for LJ := 0 to LPart.ContourCount - 1 do
      Result.ContourEnds[Result.ContourCount + LJ] :=
        LPart.ContourEnds[LJ] + LBasePointCount;

    Inc(Result.ContourCount, LPart.ContourCount);

    // 使用第一个成分的 metrics 作为复合字形边界框
    if AComponents[LI].UseMetrics then
    begin
      Result.XMin := LPart.XMin;
      Result.YMin := LPart.YMin;
      Result.XMax := LPart.XMax;
      Result.YMax := LPart.YMax;
    end;
  end;

  // 如果没有 UseMetrics，从所有点计算边界框
  if (Length(Result.Points) > 0) and
     (not AComponents[0].UseMetrics) then
  begin
    Result.XMin := High(Int16);
    Result.YMin := High(Int16);
    Result.XMax := Low(Int16);
    Result.YMax := Low(Int16);
    for LJ := 0 to High(Result.Points) do
    begin
      if Result.Points[LJ].X < Result.XMin then
        Result.XMin := Result.Points[LJ].X;
      if Result.Points[LJ].Y < Result.YMin then
        Result.YMin := Result.Points[LJ].Y;
      if Result.Points[LJ].X > Result.XMax then
        Result.XMax := Result.Points[LJ].X;
      if Result.Points[LJ].Y > Result.YMax then
        Result.YMax := Result.Points[LJ].Y;
    end;
  end;
end;

function TTFontFace.GlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;
var
  LGlyfIdx: Int32;
  LOffset, LNextOffset: Int32;
  LContours: Int16;
  LCompoundBuf: TFontCompoundComponentArray;
begin
  Result := Default(TFontGlyphOutline);
  FontGlyphOutlineClear(Result);

  { CFF2 outlines }
  if FCff2Parsed then
  begin
    Result := Cff2GlyphOutline(AGlyphIndex);
    Exit;
  end;

  { CFF outlines }
  if FCffParsed then
  begin
    Result := CffGlyphOutline(AGlyphIndex);
    Exit;
  end;

  if (Length(FLocaOffsets) = 0) or (AGlyphIndex >= UInt32(Length(FLocaOffsets) - 1)) then
    Exit;

  LGlyfIdx := FindTable(TABLE_TAG_GLYF);
  if LGlyfIdx < 0 then
    Exit;

  LOffset := Int32(FTables[LGlyfIdx].Offset) + Int32(FLocaOffsets[AGlyphIndex]);
  LNextOffset := Int32(FTables[LGlyfIdx].Offset) + Int32(FLocaOffsets[AGlyphIndex + 1]);

  // 零长度 = 空字形（空格等）
  if LNextOffset <= LOffset then
    Exit;

  LContours := ReadInt16BE(LOffset);
  Result.XMin := ReadInt16BE(LOffset + 2);
  Result.YMin := ReadInt16BE(LOffset + 4);
  Result.XMax := ReadInt16BE(LOffset + 6);
  Result.YMax := ReadInt16BE(LOffset + 8);

  if LContours > 0 then
    ParseGlyphOutlineSimple(LOffset + 10, LContours, Result)
  else if LContours < 0 then
  begin
    // 复合字形
    ParseCompoundComponents(LOffset + 10, LCompoundBuf);
    Result := ExpandCompoundOutline(LCompoundBuf);
  end;

  { 自动应用 gvar deltas（可变字体轮廓调整） }
  if FHasVariationCoords and FGvarParsed then
  begin
    ApplyGvarDeltas(AGlyphIndex, Result, FVariationCoords);
    RecalcOutlineBounds(Result);
  end;
end;

procedure TTFontFace.RecalcOutlineBounds(var AOutline: TFontGlyphOutline);
var
  LI: Int32;
  LX, LY: Int16;
begin
  if Length(AOutline.Points) = 0 then
  begin
    AOutline.XMin := 0;
    AOutline.YMin := 0;
    AOutline.XMax := 0;
    AOutline.YMax := 0;
    Exit;
  end;

  AOutline.XMin := AOutline.Points[0].X;
  AOutline.YMin := AOutline.Points[0].Y;
  AOutline.XMax := AOutline.Points[0].X;
  AOutline.YMax := AOutline.Points[0].Y;

  for LI := 1 to High(AOutline.Points) do
  begin
    LX := AOutline.Points[LI].X;
    LY := AOutline.Points[LI].Y;
    if LX < AOutline.XMin then AOutline.XMin := LX;
    if LY < AOutline.YMin then AOutline.YMin := LY;
    if LX > AOutline.XMax then AOutline.XMax := LX;
    if LY > AOutline.YMax then AOutline.YMax := LY;
  end;
end;

{ -- Context subtable parsing (GSUB type 5/6, GPOS type 7/8) -- }

procedure TTFontFace.ParseContextSubtable(AOffset, AFormat: Int32; AIsChained: Boolean;
  var ATarget: TFontContextSubtableArray);
var
  LSub: TFontContextSubtable;
  LBase, LI, LCount, LIdx: Int32;
begin
  LBase := AOffset;

  FillChar(LSub, SizeOf(LSub), 0);
  LSub.Format := AFormat;
  LSub.IsChained := AIsChained;

  if AFormat = 1 then
  begin
    { Format 1: glyph-based rule sets.
      ChainedContextSubstFormat1 has the SAME subtable header as non-chained:
      +0: format, +2: coverageOffset, +4: ruleSetCount, +6: ruleSetOffsets[].
      Offsets in the array are relative to the subtable start. }
    if FDataLength < LBase + 6 then Exit;
    LSub.CoverageOffset := LBase + ReadUInt16BE(LBase + 2);
    LSub.RuleSetCount := ReadUInt16BE(LBase + 4);
    LSub.RuleSetOffsetsOffset := LBase; { subtable base; array at +6 }
  end
  else if AFormat = 2 then
  begin
    { Format 2: class-based }
    if AIsChained then
    begin
      if FDataLength < LBase + 12 then Exit;
      LSub.CoverageOffset := LBase + ReadUInt16BE(LBase + 2);
      LSub.BacktrackGlyphCount := ReadUInt16BE(LBase + 4);
      LSub.BacktrackCoverageOffsetsOffset := LBase + 6;
      LI := 6 + LSub.BacktrackGlyphCount * 2;
      if FDataLength < LBase + LI + 6 then Exit;
      { Chained Fmt2: +LI=InputGlyphCount, +LI+2=InputClassDefOffset,
        +LI+4=LookaheadGlyphCount, +LI+6=LookaheadCovOffsets[laGC] }
      LSub.InputGlyphCount := ReadUInt16BE(LBase + LI);
      LSub.LookaheadGlyphCount := ReadUInt16BE(LBase + LI + 4);
      LSub.LookaheadCoverageOffsetsOffset := LBase + LI + 6;
      LI := LI + 6 + LSub.LookaheadGlyphCount * 2;
      if FDataLength < LBase + LI + 4 then Exit;
      LSub.ClassDefOffset := LBase + ReadUInt16BE(LBase + LI);
      LSub.ClassSetCount := ReadUInt16BE(LBase + LI + 2);
      LSub.ClassSetOffsetsOffset := LBase; { subtable base for chained }
    end
    else
    begin
      if FDataLength < LBase + 8 then Exit;
      LSub.CoverageOffset := LBase + ReadUInt16BE(LBase + 2);
      LSub.ClassDefOffset := LBase + ReadUInt16BE(LBase + 4);
      LSub.ClassSetCount := ReadUInt16BE(LBase + 6);
      LSub.ClassSetOffsetsOffset := LBase; { subtable base }
    end;
  end
  else if AFormat = 3 then
  begin
    { Format 3: coverage-based }
    if AIsChained then
    begin
      if FDataLength < LBase + 10 then Exit;
      LSub.BacktrackGlyphCount := ReadUInt16BE(LBase + 2);
      LSub.BacktrackCoverageOffsetsOffset := LBase + 4;
      LI := 4 + LSub.BacktrackGlyphCount * 2;
      if FDataLength < LBase + LI + 2 then Exit;
      LSub.GlyphCount := ReadUInt16BE(LBase + LI);
      LI := LI + 2;
      if LSub.GlyphCount > 0 then
        LSub.CoverageOffset := LBase + ReadUInt16BE(LBase + LI);
      LI := LI + LSub.GlyphCount * 2;
      if FDataLength < LBase + LI + 2 then Exit;
      LSub.LookaheadGlyphCount := ReadUInt16BE(LBase + LI);
      LI := LI + 2 + LSub.LookaheadGlyphCount * 2;
      if FDataLength < LBase + LI + 2 then Exit;
      LSub.LookupRecordCount := ReadUInt16BE(LBase + LI);
      LSub.LookupRecordsOffset := LBase + LI + 2;
    end
    else
    begin
      if FDataLength < LBase + 6 then Exit;
      LSub.GlyphCount := ReadUInt16BE(LBase + 2);
      LSub.LookupRecordCount := ReadUInt16BE(LBase + 4);
      if LSub.GlyphCount > 0 then
        LSub.CoverageOffset := LBase + ReadUInt16BE(LBase + 6);
      LSub.LookupRecordsOffset := LBase + 6 + LSub.GlyphCount * 2;
    end;
  end;

  { Determine which array to store in: GSUB ContextSubst vs GPOS ContextPos.
    We distinguish by checking if the lookup was found in GSUB or GPOS parse.
    Simple heuristic: store all in FContextSubstSubtables if coming from GSUB
    (called before ParseGpos), else in FContextPosSubtables.
    Since ParseGsub runs first, and both call ParseContextSubtable,
    we use a flag to distinguish. For simplicity, store all subtables in one
    array and the accessor methods check both arrays. }

  { Store: if coverage offset is valid, the subtable is usable }
  if LSub.CoverageOffset > 0 then
  begin
    LIdx := Length(ATarget);
    SetLength(ATarget, LIdx + 1);
    ATarget[LIdx] := LSub;
  end;
end;

{ -- Context subtable offset helpers -- }

{ Returns absolute offset of the RuleSetOffsets[] array within a Format 1 subtable.
  RuleSetOffsetsOffset stores the subtable base (LBase); array starts at +6. }
function TTFontFace.CtxRuleSetArrBase(const ASub: TFontContextSubtable): Int32;
begin
  Result := ASub.RuleSetOffsetsOffset + 6;
end;

{ Returns absolute offset of the ClassSetOffsets[] array within a Format 2 subtable. }
function TTFontFace.CtxClassSetArrBase(const ASub: TFontContextSubtable): Int32;
begin
  if ASub.IsChained then
    { ChainedFmt2: 6 + bk*2 + 2(input) + 2(la) + la*2 + 2(classDef) + 2(count) = bk*2 + la*2 + 16 }
    Result := ASub.ClassSetOffsetsOffset + ASub.BacktrackGlyphCount * 2 + ASub.LookaheadGlyphCount * 2 + 16
  else
    Result := ASub.ClassSetOffsetsOffset + 8;
end;

{ -- Coverage table lookup -- }

function TTFontFace.CoverageIndex(ACovOffset, AGlyphId: Int32): Int32;
var
  LFmt, LCount, LI, LStart, LEnd, LMid, LVal: Int32;
begin
  Result := -1;
  if FDataLength < ACovOffset + 4 then
    Exit;
  LFmt := ReadUInt16BE(ACovOffset);
  if LFmt = 1 then
  begin
    { Format 1: sorted glyph array — binary search }
    LCount := ReadUInt16BE(ACovOffset + 2);
    if (LCount <= 0) or (FDataLength < ACovOffset + 4 + LCount * 2) then
      Exit;
    LStart := 0;
    LEnd := LCount - 1;
    while LStart <= LEnd do
    begin
      LMid := (LStart + LEnd) shr 1;
      LVal := ReadUInt16BE(ACovOffset + 4 + LMid * 2);
      if LVal = AGlyphId then
      begin
        Result := LMid;
        Exit;
      end
      else if LVal < AGlyphId then
        LStart := LMid + 1
      else
        LEnd := LMid - 1;
    end;
  end
  else if LFmt = 2 then
  begin
    { Format 2: range records }
    LCount := ReadUInt16BE(ACovOffset + 2);
    for LI := 0 to LCount - 1 do
    begin
      if FDataLength < ACovOffset + 4 + LI * 6 + 6 then
        Exit;
      LStart := ReadUInt16BE(ACovOffset + 4 + LI * 6);
      if (AGlyphId >= LStart) and
         (AGlyphId <= ReadUInt16BE(ACovOffset + 4 + LI * 6 + 2)) then
      begin
        Result := ReadUInt16BE(ACovOffset + 4 + LI * 6 + 4) + (AGlyphId - LStart);
        Exit;
      end;
    end;
  end;
end;

function TTFontFace.ClassDefClassId(AClassDefOffset, AGlyphId: Int32): Int32;
var
  LFmt, LCount, LI, LStartGlyph, LGlyphCount: Int32;
begin
  Result := 0;
  if FDataLength < AClassDefOffset + 4 then
    Exit;
  LFmt := ReadUInt16BE(AClassDefOffset);
  if LFmt = 1 then
  begin
    { Format 1: ClassRangeRecord array }
    LStartGlyph := ReadUInt16BE(AClassDefOffset + 2);
    LGlyphCount := ReadUInt16BE(AClassDefOffset + 4);
    if AGlyphId < LStartGlyph then Exit;
    LI := AGlyphId - LStartGlyph;
    if LI >= LGlyphCount then Exit;
    if FDataLength < AClassDefOffset + 6 + LI * 2 + 2 then Exit;
    Result := ReadUInt16BE(AClassDefOffset + 6 + LI * 2);
  end
  else if LFmt = 2 then
  begin
    { Format 2: ClassRangeRecord array }
    LCount := ReadUInt16BE(AClassDefOffset + 2);
    for LI := 0 to LCount - 1 do
    begin
      if FDataLength < AClassDefOffset + 4 + LI * 6 + 6 then
        Exit;
      LStartGlyph := ReadUInt16BE(AClassDefOffset + 4 + LI * 6);
      if AGlyphId < LStartGlyph then
        Break;
      if AGlyphId <= ReadUInt16BE(AClassDefOffset + 4 + LI * 6 + 2) then
      begin
        Result := ReadUInt16BE(AClassDefOffset + 4 + LI * 6 + 4);
        Exit;
      end;
    end;
  end;
end;

function TTFontFace.ReadAnchor(AOffset: Int32): TFontAnchor;
var
  LFmt: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  if FDataLength < AOffset + 6 then
    Exit;
  LFmt := ReadUInt16BE(AOffset);
  if (LFmt >= 1) and (LFmt <= 3) then
  begin
    Result.X := ReadInt16BE(AOffset + 2);
    Result.Y := ReadInt16BE(AOffset + 4);
  end;
end;

{ -- GSUB SingleSubst -- }

function TTFontFace.HasSingleSubst: Boolean;
begin
  Result := Length(FSingleSubstSubtables) > 0;
end;

function TTFontFace.SingleSubstSubtableCount: Int32;
begin
  Result := Length(FSingleSubstSubtables);
end;

function TTFontFace.LookupSingleSubst(AGlyphId: UInt16): UInt16;
var
  LI, LCovIdx: Int32;
  LSub: TFontSingleSubstSubtable;
begin
  Result := 0;
  for LI := 0 to High(FSingleSubstSubtables) do
  begin
    LSub := FSingleSubstSubtables[LI];
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LSub.Format = 1 then
    begin
      Result := UInt16(Int32(AGlyphId) + LSub.DeltaGlyphID);
      Exit;
    end
    else if LSub.Format = 2 then
    begin
      if LCovIdx < LSub.GlyphCount then
      begin
        if FDataLength >= LSub.GlyphArrayOffset + LCovIdx * 2 + 2 then
        begin
          Result := ReadUInt16BE(LSub.GlyphArrayOffset + LCovIdx * 2);
          Exit;
        end;
      end;
    end;
  end;
end;

function TTFontFace.LookupSingleSubstAt(AIndex: Int32; AGlyphId: UInt16): UInt16;
var
  LCovIdx: Int32;
  LSub: TFontSingleSubstSubtable;
begin
  Result := 0;
  if (AIndex < 0) or (AIndex >= Length(FSingleSubstSubtables)) then
    Exit;
  LSub := FSingleSubstSubtables[AIndex];
  LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
  if LCovIdx < 0 then
    Exit;
  if LSub.Format = 1 then
    Result := UInt16(Int32(AGlyphId) + LSub.DeltaGlyphID)
  else if LSub.Format = 2 then
  begin
    if LCovIdx < LSub.GlyphCount then
    begin
      if FDataLength >= LSub.GlyphArrayOffset + LCovIdx * 2 + 2 then
        Result := ReadUInt16BE(LSub.GlyphArrayOffset + LCovIdx * 2);
    end;
  end;
end;

{ -- GPOS SinglePos -- }

function TTFontFace.HasSinglePos: Boolean;
begin
  Result := Length(FSinglePosSubtables) > 0;
end;

function TTFontFace.LookupSinglePosXAdvance(AGlyphId: UInt16): Int16;
var
  LI, LCovIdx: Int32;
  LSub: TFontSinglePosSubtable;
  LValOffset: Int32;
begin
  Result := 0;
  for LI := 0 to High(FSinglePosSubtables) do
  begin
    LSub := FSinglePosSubtables[LI];
    if LSub.XAdvanceOffset < 0 then
      Continue;
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LSub.Format = 1 then
      LValOffset := LSub.ValueOffset + LSub.XAdvanceOffset
    else
      LValOffset := LSub.ValueOffset + LCovIdx * LSub.ValueRecordSize + LSub.XAdvanceOffset;
    if FDataLength >= LValOffset + 2 then
    begin
      Result := ReadInt16BE(LValOffset);
      Exit;
    end;
  end;
end;

{ -- GPOS MarkToBase -- }

function TTFontFace.HasMarkToBase: Boolean;
begin
  Result := Length(FMarkToBaseSubtables) > 0;
end;

function TTFontFace.LookupMarkToBase(AMarkGlyph, ABaseGlyph: UInt16): TFontAnchor;
var
  LI, LMarkIdx, LBaseIdx: Int32;
  LSub: TFontMarkToBaseSubtable;
  LMarkClass, LMarkAnchorOff: Int32;
  LBaseAnchorOff: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToBaseSubtables) do
  begin
    LSub := FMarkToBaseSubtables[LI];
    LMarkIdx := CoverageIndex(LSub.MarkCoverageOffset, AMarkGlyph);
    if LMarkIdx < 0 then
      Continue;
    LBaseIdx := CoverageIndex(LSub.BaseCoverageOffset, ABaseGlyph);
    if LBaseIdx < 0 then
      Continue;
    { Read MarkRecord from MarkArray:
      MarkArray: uint16 MarkCount, then MarkRecord[MarkCount]
      MarkRecord: uint16 MarkClass, Offset16 MarkAnchor }
    if FDataLength < LSub.MarkArrayOffset + 2 + LMarkIdx * 4 + 4 then
      Continue;
    LMarkClass := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkIdx * 4);
    LMarkAnchorOff := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkIdx * 4 + 2);
    if LMarkClass >= LSub.ClassCount then
      Continue;
    { Read BaseRecord from BaseArray:
      BaseArray: uint16 BaseCount, then BaseRecord[BaseCount]
      BaseRecord: Offset16 BaseAnchor[ClassCount] }
    if FDataLength < LSub.BaseArrayOffset + 2 + LBaseIdx * LSub.ClassCount * 2 +
       LMarkClass * 2 + 2 then
      Continue;
    LBaseAnchorOff := ReadUInt16BE(
      LSub.BaseArrayOffset + 2 + LBaseIdx * LSub.ClassCount * 2 + LMarkClass * 2);
    if LBaseAnchorOff = 0 then
      Continue;
    { Mark anchor offset is relative to MarkArray. }
    Result := ReadAnchor(LSub.MarkArrayOffset + LMarkAnchorOff);
    Exit;
  end;
end;

{ -- GPOS MarkToMark -- }

function TTFontFace.HasMarkToMark: Boolean;
begin
  Result := Length(FMarkToMarkSubtables) > 0;
end;

function TTFontFace.LookupMarkToMark(AMarkGlyph, ABaseMarkGlyph: UInt16): TFontAnchor;
var
  LI, LMarkIdx, LBaseIdx: Int32;
  LSub: TFontMarkToMarkSubtable;
  LMarkClass, LMarkAnchorOff: Int32;
  LBaseAnchorOff: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToMarkSubtables) do
  begin
    LSub := FMarkToMarkSubtables[LI];
    LMarkIdx := CoverageIndex(LSub.Mark1CoverageOffset, AMarkGlyph);
    if LMarkIdx < 0 then
      Continue;
    LBaseIdx := CoverageIndex(LSub.Mark2CoverageOffset, ABaseMarkGlyph);
    if LBaseIdx < 0 then
      Continue;
    if FDataLength < LSub.Mark1ArrayOffset + 2 + LMarkIdx * 4 + 4 then
      Continue;
    LMarkClass := ReadUInt16BE(LSub.Mark1ArrayOffset + 2 + LMarkIdx * 4);
    LMarkAnchorOff := ReadUInt16BE(LSub.Mark1ArrayOffset + 2 + LMarkIdx * 4 + 2);
    if LMarkClass >= LSub.ClassCount then
      Continue;
    if FDataLength < LSub.Mark2ArrayOffset + 2 + LBaseIdx * LSub.ClassCount * 2 +
       LMarkClass * 2 + 2 then
      Continue;
    LBaseAnchorOff := ReadUInt16BE(
      LSub.Mark2ArrayOffset + 2 + LBaseIdx * LSub.ClassCount * 2 + LMarkClass * 2);
    if LBaseAnchorOff = 0 then
      Continue;
    Result := ReadAnchor(LSub.Mark1ArrayOffset + LMarkAnchorOff);
    Exit;
  end;
end;

{ -- GPOS CursivePos -- }

function TTFontFace.HasCursivePos: Boolean;
begin
  Result := Length(FCursivePosSubtables) > 0;
end;

function TTFontFace.LookupCursivePosEntryAnchor(AGlyph: UInt16): TFontAnchor;
var
  LI, LCovIdx, LRecOff, LAnchorOff: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FCursivePosSubtables) do
  begin
    LCovIdx := CoverageIndex(FCursivePosSubtables[LI].CoverageOffset, AGlyph);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= FCursivePosSubtables[LI].EntryExitCount then
      Continue;
    { EntryExitRecord: EntryAnchorOffset(uint16) + ExitAnchorOffset(uint16) }
    LRecOff := FCursivePosSubtables[LI].EntryExitArrayOffset + LCovIdx * 4;
    if FDataLength < LRecOff + 4 then
      Continue;
    LAnchorOff := ReadUInt16BE(LRecOff);
    if LAnchorOff = 0 then
      Continue;
    LAnchorOff := LRecOff + LAnchorOff;
    { Anchor Format 1: format(uint16) + X(int16) + Y(int16) }
    if FDataLength < LAnchorOff + 6 then
      Continue;
    Result.X := Int16(ReadUInt16BE(LAnchorOff + 2));
    Result.Y := Int16(ReadUInt16BE(LAnchorOff + 4));
    Exit;
  end;
end;

function TTFontFace.LookupCursivePosExitAnchor(AGlyph: UInt16): TFontAnchor;
var
  LI, LCovIdx, LRecOff, LAnchorOff: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FCursivePosSubtables) do
  begin
    LCovIdx := CoverageIndex(FCursivePosSubtables[LI].CoverageOffset, AGlyph);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= FCursivePosSubtables[LI].EntryExitCount then
      Continue;
    { EntryExitRecord: EntryAnchorOffset(uint16) + ExitAnchorOffset(uint16) }
    LRecOff := FCursivePosSubtables[LI].EntryExitArrayOffset + LCovIdx * 4;
    if FDataLength < LRecOff + 4 then
      Continue;
    LAnchorOff := ReadUInt16BE(LRecOff + 2);
    if LAnchorOff = 0 then
      Continue;
    LAnchorOff := LRecOff + LAnchorOff;
    { Anchor Format 1: format(uint16) + X(int16) + Y(int16) }
    if FDataLength < LAnchorOff + 6 then
      Continue;
    Result.X := Int16(ReadUInt16BE(LAnchorOff + 2));
    Result.Y := Int16(ReadUInt16BE(LAnchorOff + 4));
    Exit;
  end;
end;

{ -- GSUB MultipleSubst -- }

function TTFontFace.HasMultipleSubst: Boolean;
begin
  Result := Length(FMultipleSubstSubtables) > 0;
end;

function TTFontFace.LookupMultipleSubst(AGlyphId: UInt16): TFontGlyphIdArray;
var
  LI, LCovIdx, LSeqOff, LGlyphCount, LJ: Int32;
begin
  Result := nil;
  SetLength(Result, 0);
  for LI := 0 to High(FMultipleSubstSubtables) do
  begin
    LCovIdx := CoverageIndex(FMultipleSubstSubtables[LI].CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= FMultipleSubstSubtables[LI].SequenceCount then
      Continue;
    { Read Sequence offset from the offsets array }
    LSeqOff := FMultipleSubstSubtables[LI].BaseOffset +
      ReadUInt16BE(FMultipleSubstSubtables[LI].SequenceOffsetsOffset + LCovIdx * 2);
    { Sequence table: GlyphCount (2 bytes) + SubstituteGlyphID[GlyphCount] }
    if FDataLength < LSeqOff + 2 then
      Continue;
    LGlyphCount := ReadUInt16BE(LSeqOff);
    if (LGlyphCount < 1) or (FDataLength < LSeqOff + 2 + LGlyphCount * 2) then
      Continue;
    SetLength(Result, LGlyphCount);
    for LJ := 0 to LGlyphCount - 1 do
      Result[LJ] := ReadUInt16BE(LSeqOff + 2 + LJ * 2);
    Exit;
  end;
end;

{ -- GSUB AlternateSubst -- }

function TTFontFace.HasAlternateSubst: Boolean;
begin
  Result := Length(FAlternateSubstSubtables) > 0;
end;

function TTFontFace.LookupAlternateSubst(AGlyphId: UInt16): TFontGlyphIdArray;
var
  LI, LCovIdx, LSetOff, LAltCount, LJ: Int32;
begin
  Result := nil;
  SetLength(Result, 0);
  for LI := 0 to High(FAlternateSubstSubtables) do
  begin
    LCovIdx := CoverageIndex(FAlternateSubstSubtables[LI].CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= FAlternateSubstSubtables[LI].AlternateSetCount then
      Continue;
    { Read AlternateSet offset from the offsets array }
    LSetOff := FAlternateSubstSubtables[LI].BaseOffset +
      ReadUInt16BE(FAlternateSubstSubtables[LI].AlternateSetOffsetsOffset + LCovIdx * 2);
    { AlternateSet table: GlyphCount (2) + AlternateGlyphID[Count] }
    if FDataLength < LSetOff + 2 then
      Continue;
    LAltCount := ReadUInt16BE(LSetOff);
    if (LAltCount < 1) or (FDataLength < LSetOff + 2 + LAltCount * 2) then
      Continue;
    SetLength(Result, LAltCount);
    for LJ := 0 to LAltCount - 1 do
      Result[LJ] := ReadUInt16BE(LSetOff + 2 + LJ * 2);
    Exit;
  end;
end;

{ -- GPOS MarkToLig -- }

function TTFontFace.HasMarkToLig: Boolean;
begin
  Result := Length(FMarkToLigatureSubtables) > 0;
end;

function TTFontFace.LookupMarkToLig(AMarkGlyph, ALigatureGlyph, AComponentIndex: UInt16): TFontAnchor;
var
  LI, LMarkCovIdx, LLigCovIdx: Int32;
  LSub: TFontMarkToLigatureSubtable;
  LClassCount, LMarkClassOff, LMarkAnchorOff: Int32;
  LLigAttachOff, LCompCount, LCompIdx: Int32;
begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToLigatureSubtables) do
  begin
    LSub := FMarkToLigatureSubtables[LI];
    LMarkCovIdx := CoverageIndex(LSub.MarkCoverageOffset, AMarkGlyph);
    if LMarkCovIdx < 0 then Continue;
    LLigCovIdx := CoverageIndex(LSub.LigatureCoverageOffset, ALigatureGlyph);
    if LLigCovIdx < 0 then Continue;

    { MarkArray: MarkRecord[markCovIdx] = uint16 markClass + uint16 markAnchorOffset }
    if FDataLength < LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 4 then Continue;
    LClassCount := LSub.ClassCount;
    LMarkClassOff := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4);
    LMarkAnchorOff := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 2);

    { LigatureArray: LigatureAttach offset table at +0, then LigatureAttach records }
    if FDataLength < LSub.LigatureArrayOffset + 2 + LLigCovIdx * 2 + 2 then Continue;
    LLigAttachOff := LSub.LigatureArrayOffset + ReadUInt16BE(LSub.LigatureArrayOffset + 2 + LLigCovIdx * 2);
    if FDataLength < LLigAttachOff + 2 then Continue;
    LCompCount := ReadUInt16BE(LLigAttachOff); { component count }
    LCompIdx := AComponentIndex;
    if LCompIdx >= LCompCount then
      LCompIdx := LCompCount - 1;
    { ComponentRecord[compIdx] has ClassCount anchor offsets }
    if LCompIdx < 0 then Continue;
    if FDataLength < LLigAttachOff + 2 + LCompIdx * LClassCount * 2 + LMarkClassOff * 2 + 2 then Continue;
    LMarkAnchorOff := ReadUInt16BE(LLigAttachOff + 2 + LCompIdx * LClassCount * 2 + LMarkClassOff * 2);
    if LMarkAnchorOff = 0 then Continue;
    Result := ReadAnchor(LSub.LigatureArrayOffset + LMarkAnchorOff);
    { Subtract the mark's own anchor }
    if FDataLength >= LSub.MarkArrayOffset + LMarkAnchorOff + 6 then
    begin
      Result.X := Result.X - ReadInt16BE(LSub.MarkArrayOffset + LMarkAnchorOff);
      Result.Y := Result.Y - ReadInt16BE(LSub.MarkArrayOffset + LMarkAnchorOff + 2);
    end;
    Exit;
  end;
end;

{ -- ContextSubst/ContextPos -- }

function TTFontFace.HasContextSubst: Boolean;
begin
  Result := Length(FContextSubstSubtables) > 0;
end;

function TTFontFace.ContextSubstCount: Int32;
begin
  Result := Length(FContextSubstSubtables);
end;

function TTFontFace.GetContextSubstFmt(AIndex: Int32): Int32;
begin
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit(0);
  Result := FContextSubstSubtables[AIndex].Format;
end;

function TTFontFace.GetContextSubstRuleSetCount(AIndex: Int32): Int32;
begin
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit(0);
  if FContextSubstSubtables[AIndex].Format = 1 then
    Result := FContextSubstSubtables[AIndex].RuleSetCount
  else if FContextSubstSubtables[AIndex].Format = 2 then
    Result := FContextSubstSubtables[AIndex].ClassSetCount
  else
    Result := 0;
end;

function TTFontFace.GetContextSubstForGlyph(AIndex: Int32; AGlyphId: UInt16): TFontContextLookupRecordArray;
var
  LSub: TFontContextSubtable;
  LCovIdx, LRuleOff, LRuleCount, LSubstCount, LI, LJ: Int32;
  LRSOff, LRuleSetCount: Int32;
  LClassId, LClassSetOff: Int32;
  LGlyphCount: Int32;
begin
  Result := nil;
  SetLength(Result, 0);
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  LSub := FContextSubstSubtables[AIndex];

  if LSub.Format = 1 then
  begin
    { Format 1: glyph-based rule sets }
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then Exit;
    if (LSub.RuleSetCount <= 0) or (LCovIdx >= LSub.RuleSetCount) then Exit;
    LJ := CtxRuleSetArrBase(LSub);
    if FDataLength < LJ + LCovIdx * 2 + 2 then Exit;
    LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LJ + LCovIdx * 2);
    if (LRSOff = LSub.RuleSetOffsetsOffset) or (FDataLength < LRSOff + 2) then Exit;
    LRuleCount := ReadUInt16BE(LRSOff);
    if LRuleCount <= 0 then Exit;
    { Use first rule }
    if FDataLength < LRSOff + 4 then Exit;
    LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    if LSub.IsChained then
    begin
      { ChainedSubRule: uint16 backtrackGC, uint16 inputGC, uint16 lookaheadGC,
        GlyphID backtrack[bkGC], input[inputGC-1], lookahead[laGC],
        uint16 seqLookupCount, SeqLookupRecord[seqLookupCount] }
      if FDataLength < LRuleOff + 6 then Exit;
      LI := ReadUInt16BE(LRuleOff);     { rule's backtrackGC }
      LGlyphCount := ReadUInt16BE(LRuleOff + 2); { rule's inputGC }
      LJ := ReadUInt16BE(LRuleOff + 4); { rule's lookaheadGC }
      LI := 6 + LI * 2 + (LGlyphCount - 1) * 2 + LJ * 2;
      LSubstCount := ReadUInt16BE(LRuleOff + LI);
      Inc(LI, 2);
      SetLength(Result, LSubstCount);
      for LJ := 0 to LSubstCount - 1 do
      begin
        if FDataLength < LRuleOff + LI + LJ * 4 + 4 then Break;
        Result[LJ].SequenceIndex := ReadUInt16BE(LRuleOff + LI + LJ * 4);
        Result[LJ].LookupIndex := ReadUInt16BE(LRuleOff + LI + LJ * 4 + 2);
      end;
    end
    else
    begin
      { SubRule: uint16 glyphCount, uint16 substCount,
        GlyphID input[glyphCount-1], SubstLookupRecord[substCount] }
      LGlyphCount := ReadUInt16BE(LRuleOff);
      LSubstCount := ReadUInt16BE(LRuleOff + 2);
      LI := 2 + LGlyphCount * 2; { skip glyphCount + input[glyphCount-1] }
      SetLength(Result, LSubstCount);
      for LJ := 0 to LSubstCount - 1 do
      begin
        if FDataLength < LRuleOff + LI + LJ * 4 + 4 then Break;
        Result[LJ].SequenceIndex := ReadUInt16BE(LRuleOff + LI + LJ * 4);
        Result[LJ].LookupIndex := ReadUInt16BE(LRuleOff + LI + LJ * 4 + 2);
      end;
    end;
  end
  else if LSub.Format = 2 then
  begin
    { Format 2: class-based }
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then Exit;
    { Look up class ID for this glyph }
    LClassId := 0; { Default class if ClassDef lookup fails }
    if LSub.ClassDefOffset > 0 then
      LClassId := ClassDefClassId(LSub.ClassDefOffset, AGlyphId);
    if (LSub.ClassSetCount <= 0) or (LClassId >= LSub.ClassSetCount) then Exit;
    LJ := CtxClassSetArrBase(LSub);
    if FDataLength < LJ + LClassId * 2 + 2 then Exit;
    LClassSetOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LJ + LClassId * 2);
    if (LClassSetOff = LSub.ClassSetOffsetsOffset) or (FDataLength < LClassSetOff + 2) then Exit;
    LRuleCount := ReadUInt16BE(LClassSetOff);
    if LRuleCount <= 0 then Exit;
    if FDataLength < LClassSetOff + 4 then Exit;
    LRuleOff := LClassSetOff + ReadUInt16BE(LClassSetOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    LSubstCount := ReadUInt16BE(LRuleOff + 2);
    SetLength(Result, LSubstCount);
    for LI := 0 to LSubstCount - 1 do
    begin
      if FDataLength < LRuleOff + 4 + LI * 4 + 4 then Break;
      Result[LI].SequenceIndex := ReadUInt16BE(LRuleOff + 4 + LI * 4);
      Result[LI].LookupIndex := ReadUInt16BE(LRuleOff + 4 + LI * 4 + 2);
    end;
  end
  else if LSub.Format = 3 then
  begin
    { Format 3: coverage-based — check if glyph is in first coverage }
    if LSub.GlyphCount <= 0 then Exit;
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then Exit;
    SetLength(Result, LSub.LookupRecordCount);
    for LI := 0 to LSub.LookupRecordCount - 1 do
    begin
      if FDataLength < LSub.LookupRecordsOffset + LI * 4 + 4 then Break;
      Result[LI].SequenceIndex := ReadUInt16BE(LSub.LookupRecordsOffset + LI * 4);
      Result[LI].LookupIndex := ReadUInt16BE(LSub.LookupRecordsOffset + LI * 4 + 2);
    end;
  end;
end;

function TTFontFace.MatchContextSubst(AIndex: Int32;
  const AGlyphs: array of UInt16; APosition: Int32): TFontContextLookupRecordArray;
var
  LSub: TFontContextSubtable;
  LCovIdx, LRuleOff, LRuleCount, LSubstCount, LI, LJ, LK: Int32;
  LRSOff, LRuleSetCount: Int32;
  LClassId, LClassSetOff, LGlyphCount: Int32;
  LInputGlyphCount, LBkCount, LLaCount: Int32;
  LMatch: Boolean;
  LGlyphArr: array of UInt16;
begin
  Result := nil;
  SetLength(Result, 0);
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  if (APosition < 0) or (APosition >= Length(AGlyphs)) then
    Exit;
  LSub := FContextSubstSubtables[AIndex];

  if LSub.Format = 1 then
  begin
    { Format 1: glyph-based rule sets — 逐规则做完整输入序列匹配 }
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphs[APosition]);
    if LCovIdx < 0 then Exit;
    if (LSub.RuleSetCount <= 0) or (LCovIdx >= LSub.RuleSetCount) then Exit;
    LJ := CtxRuleSetArrBase(LSub);
    if FDataLength < LJ + LCovIdx * 2 + 2 then Exit;
    LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LJ + LCovIdx * 2);
    if (LRSOff = LSub.RuleSetOffsetsOffset) or (FDataLength < LRSOff + 2) then Exit;
    LRuleCount := ReadUInt16BE(LRSOff);
    if LRuleCount <= 0 then Exit;
    for LI := 0 to LRuleCount - 1 do
    begin
      if FDataLength < LRSOff + 2 + LI * 2 + 2 then Break;
      LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2 + LI * 2);
      if FDataLength < LRuleOff + 4 then Continue;
      if LSub.IsChained then
      begin
        { ChainedSubRule: backtrackGC, inputGC, lookaheadGC,
          backtrack[bkGC], input[inputGC-1], lookahead[laGC],
          seqLookupCount, SeqLookupRecord[] }
        if FDataLength < LRuleOff + 6 then Continue;
        LBkCount := ReadUInt16BE(LRuleOff);
        LInputGlyphCount := ReadUInt16BE(LRuleOff + 2);
        LLaCount := ReadUInt16BE(LRuleOff + 4);
        { 检查输入序列匹配（不含首个 glyph，首个已在 coverage 中匹配） }
        if APosition + LInputGlyphCount > Length(AGlyphs) then Continue;
        LMatch := True;
        for LJ := 1 to LInputGlyphCount - 1 do
        begin
          LK := ReadUInt16BE(LRuleOff + 6 + (LBkCount + LJ - 1) * 2);
          if AGlyphs[APosition + LJ] <> LK then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if not LMatch then Continue;
        { 检查 backtrack（APosition-1, APosition-2, ...） }
        if APosition < LBkCount then Continue;
        for LJ := 0 to LBkCount - 1 do
        begin
          LK := ReadUInt16BE(LRuleOff + 6 + LJ * 2);
          if AGlyphs[APosition - 1 - LJ] <> LK then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if not LMatch then Continue;
        { 检查 lookahead }
        LK := APosition + LInputGlyphCount;
        if LK + LLaCount > Length(AGlyphs) then Continue;
        for LJ := 0 to LLaCount - 1 do
        begin
          if AGlyphs[LK + LJ] <> ReadUInt16BE(LRuleOff + 6 + (LBkCount + LInputGlyphCount - 1 + LJ) * 2) then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if not LMatch then Continue;
        { 匹配成功 — 提取 lookup records }
        LJ := 6 + (LBkCount + LInputGlyphCount - 1 + LLaCount) * 2;
        LSubstCount := ReadUInt16BE(LRuleOff + LJ);
        Inc(LJ, 2);
        SetLength(Result, LSubstCount);
        for LK := 0 to LSubstCount - 1 do
        begin
          if FDataLength < LRuleOff + LJ + LK * 4 + 4 then Break;
          Result[LK].SequenceIndex := ReadUInt16BE(LRuleOff + LJ + LK * 4);
          Result[LK].LookupIndex := ReadUInt16BE(LRuleOff + LJ + LK * 4 + 2);
        end;
        Exit;
      end
      else
      begin
        { SubRule: inputGC, substCount, input[inputGC-1], SubstLookupRecord[] }
        LInputGlyphCount := ReadUInt16BE(LRuleOff);
        LSubstCount := ReadUInt16BE(LRuleOff + 2);
        if APosition + LInputGlyphCount > Length(AGlyphs) then Continue;
        { 匹配输入序列（不含首个 glyph） }
        LMatch := True;
        for LJ := 1 to LInputGlyphCount - 1 do
        begin
          LK := ReadUInt16BE(LRuleOff + 4 + (LJ - 1) * 2);
          if AGlyphs[APosition + LJ] <> LK then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if not LMatch then Continue;
        { 匹配成功 — 提取 lookup records }
        LJ := 2 + LInputGlyphCount * 2;
        SetLength(Result, LSubstCount);
        for LK := 0 to LSubstCount - 1 do
        begin
          if FDataLength < LRuleOff + LJ + LK * 4 + 4 then Break;
          Result[LK].SequenceIndex := ReadUInt16BE(LRuleOff + LJ + LK * 4);
          Result[LK].LookupIndex := ReadUInt16BE(LRuleOff + LJ + LK * 4 + 2);
        end;
        Exit;
      end;
    end;
  end
  else if LSub.Format = 2 then
  begin
    { Format 2: class-based — 逐 ClassRule 做完整 class 序列匹配 }
    LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphs[APosition]);
    if LCovIdx < 0 then Exit;
    LClassId := 0;
    if LSub.ClassDefOffset > 0 then
      LClassId := ClassDefClassId(LSub.ClassDefOffset, AGlyphs[APosition]);
    if (LSub.ClassSetCount <= 0) or (LClassId >= LSub.ClassSetCount) then Exit;
    LJ := CtxClassSetArrBase(LSub);
    if FDataLength < LJ + LClassId * 2 + 2 then Exit;
    LClassSetOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LJ + LClassId * 2);
    if (LClassSetOff = LSub.ClassSetOffsetsOffset) or (FDataLength < LClassSetOff + 2) then Exit;
    LRuleCount := ReadUInt16BE(LClassSetOff);
    if LRuleCount <= 0 then Exit;
    for LI := 0 to LRuleCount - 1 do
    begin
      if FDataLength < LClassSetOff + 2 + LI * 2 + 2 then Break;
      LRuleOff := LClassSetOff + ReadUInt16BE(LClassSetOff + 2 + LI * 2);
      if FDataLength < LRuleOff + 4 then Continue;
      LInputGlyphCount := ReadUInt16BE(LRuleOff);
      LSubstCount := ReadUInt16BE(LRuleOff + 2);
      if APosition + LInputGlyphCount > Length(AGlyphs) then Continue;
      { 匹配 class 序列（首个 glyph 的 class 已隐式匹配） }
      LMatch := True;
      for LJ := 1 to LInputGlyphCount - 1 do
      begin
        LK := ReadUInt16BE(LRuleOff + 4 + (LJ - 1) * 2);
        if LSub.ClassDefOffset > 0 then
        begin
          if ClassDefClassId(LSub.ClassDefOffset, AGlyphs[APosition + LJ]) <> LK then
          begin
            LMatch := False;
            Break;
          end;
        end
        else if LK <> 0 then
        begin
          LMatch := False;
          Break;
        end;
      end;
      if not LMatch then Continue;
      { 匹配成功 — 提取 lookup records }
      LJ := 2 + LInputGlyphCount * 2;
      SetLength(Result, LSubstCount);
      for LK := 0 to LSubstCount - 1 do
      begin
        if FDataLength < LRuleOff + 4 + LJ + LK * 4 + 4 then Break;
        Result[LK].SequenceIndex := ReadUInt16BE(LRuleOff + 4 + LJ + LK * 4);
        Result[LK].LookupIndex := ReadUInt16BE(LRuleOff + 4 + LJ + LK * 4 + 2);
      end;
      Exit;
    end;
  end
  else if LSub.Format = 3 then
  begin
    { Format 3: coverage-based — 每个 glyph 必须在对应 coverage 中 }
    if LSub.GlyphCount <= 0 then Exit;
    if APosition + LSub.GlyphCount > Length(AGlyphs) then Exit;
    { 第一个 coverage 已在调用方或外部检查，但这里再做完整匹配 }
    for LI := 0 to LSub.GlyphCount - 1 do
    begin
      LJ := LSub.CoverageOffset; { 第一个 coverage }
      { 读取 coverage offset 数组（多个 coverage） }
      if LI = 0 then
      begin
        if CoverageIndex(LSub.CoverageOffset, AGlyphs[APosition]) < 0 then Exit;
      end
      else
      begin
        { 后续 coverage offsets 在 LookupRecordsOffset 之前的 offset 数组中 }
        if FDataLength < LSub.LookupRecordsOffset - (LSub.GlyphCount - 1 - LI) * 4 then Exit;
        LJ := ReadUInt16BE(LSub.LookupRecordsOffset - (LSub.GlyphCount - LI) * 4);
        if LJ = 0 then Exit;
        if CoverageIndex(LJ, AGlyphs[APosition + LI]) < 0 then Exit;
      end;
    end;
    { 全部匹配 — 返回 lookup records }
    SetLength(Result, LSub.LookupRecordCount);
    for LI := 0 to LSub.LookupRecordCount - 1 do
    begin
      if FDataLength < LSub.LookupRecordsOffset + LI * 4 + 4 then Break;
      Result[LI].SequenceIndex := ReadUInt16BE(LSub.LookupRecordsOffset + LI * 4);
      Result[LI].LookupIndex := ReadUInt16BE(LSub.LookupRecordsOffset + LI * 4 + 2);
    end;
  end;
end;

function TTFontFace.ApplyContextSubstLookup(ALookupIndex: Int32; AGlyphId: UInt16): UInt16;
var
  LType, LFirstIdx, LCount, LI, LCovIdx: Int32;
  LSub: TFontSingleSubstSubtable;
begin
  Result := AGlyphId;
  if (ALookupIndex < 0) or (ALookupIndex >= Length(FLookupEntries)) then
    Exit;
  LType := FLookupEntries[ALookupIndex].LookupType;
  LFirstIdx := FLookupEntries[ALookupIndex].FirstSubtableIndex;
  LCount := FLookupEntries[ALookupIndex].SubtableCount;
  { GSUB Type 1: SingleSubst — 最常见的 context-referenced lookup }
  if (LType = GSUB_LOOKUP_SINGLE_SUBST) and (LFirstIdx >= 0) and (LCount > 0) then
  begin
    for LI := LFirstIdx to LFirstIdx + LCount - 1 do
    begin
      if LI > High(FSingleSubstSubtables) then Break;
      LSub := FSingleSubstSubtables[LI];
      LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
      if LCovIdx < 0 then Continue;
      if LSub.Format = 1 then
        Exit(UInt16(Int32(AGlyphId) + LSub.DeltaGlyphID))
      else if LSub.Format = 2 then
      begin
        if LCovIdx < LSub.GlyphCount then
        begin
          if FDataLength >= LSub.GlyphArrayOffset + LCovIdx * 2 + 2 then
            Exit(ReadUInt16BE(LSub.GlyphArrayOffset + LCovIdx * 2));
        end;
      end;
    end;
  end;
  { 其他 lookup type 暂不支持（Ligature 需要多 glyph 上下文） }
end;

function TTFontFace.ApplyContextSubstLookupMulti(ALookupIndex: Int32;
  AGlyphId: UInt16): TFontGlyphIdArray;
var
  LType, LFirstIdx, LCount, LI, LCovIdx: Int32;
  LSub: TFontSingleSubstSubtable;
  LMulSub: TFontMultipleSubstSubtable;
  LSeqOff, LSeqCount, LJ: Int32;
  LNewGid: UInt16;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := AGlyphId;
  if (ALookupIndex < 0) or (ALookupIndex >= Length(FLookupEntries)) then
    Exit;
  LType := FLookupEntries[ALookupIndex].LookupType;
  LFirstIdx := FLookupEntries[ALookupIndex].FirstSubtableIndex;
  LCount := FLookupEntries[ALookupIndex].SubtableCount;

  { GSUB Type 1: SingleSubst }
  if (LType = GSUB_LOOKUP_SINGLE_SUBST) and (LFirstIdx >= 0) and (LCount > 0) then
  begin
    for LI := LFirstIdx to LFirstIdx + LCount - 1 do
    begin
      if LI > High(FSingleSubstSubtables) then Break;
      LSub := FSingleSubstSubtables[LI];
      LCovIdx := CoverageIndex(LSub.CoverageOffset, AGlyphId);
      if LCovIdx < 0 then Continue;
      if LSub.Format = 1 then
      begin
        LNewGid := UInt16(Int32(AGlyphId) + LSub.DeltaGlyphID);
        Result[0] := LNewGid;
        Exit;
      end
      else if LSub.Format = 2 then
      begin
        if LCovIdx < LSub.GlyphCount then
        begin
          if FDataLength >= LSub.GlyphArrayOffset + LCovIdx * 2 + 2 then
            Result[0] := ReadUInt16BE(LSub.GlyphArrayOffset + LCovIdx * 2);
          Exit;
        end;
      end;
    end;
  end;

  { GSUB Type 2: MultipleSubst (1 → N expansion) }
  if (LType = GSUB_LOOKUP_MULTIPLE_SUBST) and (LFirstIdx >= 0) and (LCount > 0) then
  begin
    for LI := LFirstIdx to LFirstIdx + LCount - 1 do
    begin
      if LI > High(FMultipleSubstSubtables) then Break;
      LMulSub := FMultipleSubstSubtables[LI];
      LCovIdx := CoverageIndex(LMulSub.CoverageOffset, AGlyphId);
      if LCovIdx < 0 then Continue;
      if LCovIdx >= LMulSub.SequenceCount then Continue;
      LSeqOff := LMulSub.SequenceOffsetsOffset + LCovIdx * 2;
      if FDataLength < LSeqOff + 2 then Continue;
      LSeqOff := LMulSub.BaseOffset + Int32(ReadUInt16BE(LSeqOff));
      if FDataLength < LSeqOff + 2 then Continue;
      LSeqCount := ReadUInt16BE(LSeqOff);
      SetLength(Result, LSeqCount);
      for LJ := 0 to LSeqCount - 1 do
      begin
        if FDataLength >= LSeqOff + 2 + LJ * 2 + 2 then
          Result[LJ] := ReadUInt16BE(LSeqOff + 2 + LJ * 2)
        else
          Result[LJ] := AGlyphId;
      end;
      Exit;
    end;
  end;
end;

procedure TTFontFace.GetContextSubstInfo(AIndex: Int32;
  out AInputGlyphCount, ASubstCount: Int32);
var
  LSub: TFontContextSubtable;
  LRuleOff, LRSOff: Int32;
begin
  AInputGlyphCount := 0;
  ASubstCount := 0;
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  LSub := FContextSubstSubtables[AIndex];

  if LSub.Format = 3 then
  begin
    AInputGlyphCount := LSub.GlyphCount;
    ASubstCount := LSub.LookupRecordCount;
  end
  else if (LSub.Format = 1) and (LSub.RuleSetCount > 0) then
  begin
    { Get first rule from first rule set }
    LRuleOff := CtxRuleSetArrBase(LSub);
    if FDataLength >= LRuleOff + 2 then
    begin
      LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LRuleOff);
      if (LRSOff <> LSub.RuleSetOffsetsOffset) and (FDataLength >= LRSOff + 4) then
      begin
        LRSOff := LRSOff + ReadUInt16BE(LRSOff + 2);
        if FDataLength >= LRSOff + 4 then
        begin
          AInputGlyphCount := ReadUInt16BE(LRSOff);
          ASubstCount := ReadUInt16BE(LRSOff + 2);
        end;
      end;
    end;
  end
  else if (LSub.Format = 2) and (LSub.ClassSetCount > 0) then
  begin
    { Get first rule from first non-null class set }
    LRuleOff := CtxClassSetArrBase(LSub);
    if FDataLength >= LRuleOff + 2 then
    begin
      LRSOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LRuleOff);
      if (LRSOff <> LSub.ClassSetOffsetsOffset) and (FDataLength >= LRSOff + 4) then
      begin
        LRSOff := LRSOff + ReadUInt16BE(LRSOff + 2);
        if FDataLength >= LRSOff + 4 then
        begin
          AInputGlyphCount := ReadUInt16BE(LRSOff);
          ASubstCount := ReadUInt16BE(LRSOff + 2);
        end;
      end;
    end;
  end;
end;

function TTFontFace.GetContextSubstLookup(AIndex, ASubIndex: Int32;
  out ASeqIdx, ALookupIdx: UInt16): Boolean;
var
  LSub: TFontContextSubtable;
  LRSOff, LRuleOff, LSubstCount: Int32;
begin
  Result := False;
  ASeqIdx := 0;
  ALookupIdx := 0;
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  LSub := FContextSubstSubtables[AIndex];

  if LSub.Format = 3 then
  begin
    if (ASubIndex < 0) or (ASubIndex >= LSub.LookupRecordCount) then Exit;
    if FDataLength < LSub.LookupRecordsOffset + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LSub.LookupRecordsOffset + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LSub.LookupRecordsOffset + ASubIndex * 4 + 2);
    Result := True;
  end
  else if LSub.Format = 1 then
  begin
    if LSub.RuleSetCount <= 0 then Exit;
    LRuleOff := CtxRuleSetArrBase(LSub);
    if FDataLength < LRuleOff + 2 then Exit;
    LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LRuleOff);
    if (LRSOff = LSub.RuleSetOffsetsOffset) or (FDataLength < LRSOff + 4) then Exit;
    LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    LSubstCount := ReadUInt16BE(LRuleOff + 2);
    if (ASubIndex < 0) or (ASubIndex >= LSubstCount) then Exit;
    if FDataLength < LRuleOff + 4 + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4 + 2);
    Result := True;
  end
  else if LSub.Format = 2 then
  begin
    if LSub.ClassSetCount <= 0 then Exit;
    LRuleOff := CtxClassSetArrBase(LSub);
    if FDataLength < LRuleOff + 2 then Exit;
    LRSOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LRuleOff);
    if (LRSOff = LSub.ClassSetOffsetsOffset) or (FDataLength < LRSOff + 4) then Exit;
    LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    LSubstCount := ReadUInt16BE(LRuleOff + 2);
    if (ASubIndex < 0) or (ASubIndex >= LSubstCount) then Exit;
    if FDataLength < LRuleOff + 4 + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4 + 2);
    Result := True;
  end;
end;

function TTFontFace.GetContextSubstInputCoverage(AIndex, ASubIndex: Int32): Int32;
begin
  Result := -1;
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  Result := FContextSubstSubtables[AIndex].CoverageOffset;
end;

function TTFontFace.HasContextPos: Boolean;
begin
  Result := Length(FContextPosSubtables) > 0;
end;

function TTFontFace.ContextPosCount: Int32;
begin
  Result := Length(FContextPosSubtables);
end;

procedure TTFontFace.GetContextPosInfo(AIndex: Int32;
  out AInputGlyphCount, APosCount: Int32);
var
  LSub: TFontContextSubtable;
  LRuleOff, LRSOff: Int32;
begin
  AInputGlyphCount := 0;
  APosCount := 0;
  if (AIndex < 0) or (AIndex >= Length(FContextPosSubtables)) then
    Exit;
  LSub := FContextPosSubtables[AIndex];

  if LSub.Format = 3 then
  begin
    AInputGlyphCount := LSub.GlyphCount;
    APosCount := LSub.LookupRecordCount;
  end
  else if (LSub.Format = 1) and (LSub.RuleSetCount > 0) then
  begin
    LRuleOff := CtxRuleSetArrBase(LSub);
    if FDataLength >= LRuleOff + 2 then
    begin
      LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LRuleOff);
      if (LRSOff <> LSub.RuleSetOffsetsOffset) and (FDataLength >= LRSOff + 4) then
      begin
        LRSOff := LRSOff + ReadUInt16BE(LRSOff + 2);
        if FDataLength >= LRSOff + 4 then
        begin
          AInputGlyphCount := ReadUInt16BE(LRSOff);
          APosCount := ReadUInt16BE(LRSOff + 2);
        end;
      end;
    end;
  end
  else if (LSub.Format = 2) and (LSub.ClassSetCount > 0) then
  begin
    LRuleOff := CtxClassSetArrBase(LSub);
    if FDataLength >= LRuleOff + 2 then
    begin
      LRSOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LRuleOff);
      if (LRSOff <> LSub.ClassSetOffsetsOffset) and (FDataLength >= LRSOff + 4) then
      begin
        LRSOff := LRSOff + ReadUInt16BE(LRSOff + 2);
        if FDataLength >= LRSOff + 4 then
        begin
          AInputGlyphCount := ReadUInt16BE(LRSOff);
          APosCount := ReadUInt16BE(LRSOff + 2);
        end;
      end;
    end;
  end;
end;

function TTFontFace.GetContextPosLookup(AIndex, ASubIndex: Int32;
  out ASeqIdx, ALookupIdx: UInt16): Boolean;
var
  LSub: TFontContextSubtable;
  LRSOff, LRuleOff, LSubstCount: Int32;
begin
  Result := False;
  ASeqIdx := 0;
  ALookupIdx := 0;
  if (AIndex < 0) or (AIndex >= Length(FContextPosSubtables)) then
    Exit;
  LSub := FContextPosSubtables[AIndex];

  if LSub.Format = 3 then
  begin
    if (ASubIndex < 0) or (ASubIndex >= LSub.LookupRecordCount) then Exit;
    if FDataLength < LSub.LookupRecordsOffset + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LSub.LookupRecordsOffset + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LSub.LookupRecordsOffset + ASubIndex * 4 + 2);
    Result := True;
  end
  else if LSub.Format = 1 then
  begin
    if LSub.RuleSetCount <= 0 then Exit;
    LRuleOff := CtxRuleSetArrBase(LSub);
    if FDataLength < LRuleOff + 2 then Exit;
    LRSOff := LSub.RuleSetOffsetsOffset + ReadUInt16BE(LRuleOff);
    if (LRSOff = LSub.RuleSetOffsetsOffset) or (FDataLength < LRSOff + 4) then Exit;
    LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    LSubstCount := ReadUInt16BE(LRuleOff + 2);
    if (ASubIndex < 0) or (ASubIndex >= LSubstCount) then Exit;
    if FDataLength < LRuleOff + 4 + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4 + 2);
    Result := True;
  end
  else if LSub.Format = 2 then
  begin
    if LSub.ClassSetCount <= 0 then Exit;
    LRuleOff := CtxClassSetArrBase(LSub);
    if FDataLength < LRuleOff + 2 then Exit;
    LRSOff := LSub.ClassSetOffsetsOffset + ReadUInt16BE(LRuleOff);
    if (LRSOff = LSub.ClassSetOffsetsOffset) or (FDataLength < LRSOff + 4) then Exit;
    LRuleOff := LRSOff + ReadUInt16BE(LRSOff + 2);
    if FDataLength < LRuleOff + 4 then Exit;
    LSubstCount := ReadUInt16BE(LRuleOff + 2);
    if (ASubIndex < 0) or (ASubIndex >= LSubstCount) then Exit;
    if FDataLength < LRuleOff + 4 + ASubIndex * 4 + 4 then Exit;
    ASeqIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4);
    ALookupIdx := ReadUInt16BE(LRuleOff + 4 + ASubIndex * 4 + 2);
    Result := True;
  end;
end;

function TTFontFace.GetContextPosInputCoverage(AIndex, ASubIndex: Int32): Int32;
begin
  Result := -1;
  if (AIndex < 0) or (AIndex >= Length(FContextPosSubtables)) then
    Exit;
  Result := FContextPosSubtables[AIndex].CoverageOffset;
end;

{ -- GPOS PairPos Fmt1 -- }

function TTFontFace.HasKernFmt1Pairs: Boolean;
begin
  Result := Length(FPairPosFmt1Subtables) > 0;
end;

function TTFontFace.LookupKernFmt1(ALeftGlyph, ARightGlyph: UInt16): Int16;
var
  LI, LCovIdx, LJ, LPairCount, LPairOff: Int32;
  LSub: TFontPairPosFmt1Subtable;
  LSecondGlyph: UInt16;
  LXAdv1Off, LPairSize: Int32;
begin
  Result := 0;
  for LI := 0 to High(FPairPosFmt1Subtables) do
  begin
    LSub := FPairPosFmt1Subtables[LI];
    LCovIdx := CoverageIndex(LSub.CoverageOffset, ALeftGlyph);
    if LCovIdx < 0 then
      Continue;
    if FDataLength < LSub.PairSetOffsetsOffset + 10 + LCovIdx * 2 + 2 then
      Continue;
    LPairOff := LSub.PairSetOffsetsOffset + ReadUInt16BE(LSub.PairSetOffsetsOffset + 10 + LCovIdx * 2);
    if FDataLength < LPairOff + 2 then
      Continue;
    LPairCount := ReadUInt16BE(LPairOff);
    { PairSet: uint16 PairValueCount, then PairValueRecord[PairValueCount]
      PairValueRecord: uint16 SecondGlyph, ValueRecord1, ValueRecord2 }
    LPairSize := 2 + LSub.ValueRecord1Size;
    for LJ := 0 to LPairCount - 1 do
    begin
      if FDataLength < LPairOff + 2 + LJ * LPairSize + 2 then
        Break;
      LSecondGlyph := ReadUInt16BE(LPairOff + 2 + LJ * LPairSize);
      if LSecondGlyph = ARightGlyph then
      begin
        if LSub.XAdvance1Offset >= 0 then
        begin
          LXAdv1Off := LPairOff + 2 + LJ * LPairSize + 2 + LSub.XAdvance1Offset;
          if FDataLength >= LXAdv1Off + 2 then
          begin
            Result := ReadInt16BE(LXAdv1Off);
            Exit;
          end;
        end;
        Exit;
      end;
      if LSecondGlyph > ARightGlyph then
        Break;
    end;
  end;
end;

{ -- Feature tag queries -- }

function TTFontFace.HasFeatureTag(ATag: UInt32): Boolean;
var
  LI: Int32;
begin
  Result := False;
  for LI := 0 to High(FFeatureTags) do
    if FFeatureTags[LI] = ATag then
    begin
      Result := True;
      Exit;
    end;
end;

function TTFontFace.HasFeatureKern: Boolean;
begin
  Result := HasFeatureTag($6B65726E); { 'kern' }
end;

function TTFontFace.HasFeatureMark: Boolean;
begin
  Result := HasFeatureTag($6D61726B); { 'mark' }
end;

function TTFontFace.HasFeatureMkmk: Boolean;
begin
  Result := HasFeatureTag($6D6B6D6B); { 'mkmk' }
end;

{ -- COLR/CPAL: Color glyph support -- }

function TTFontFace.HasColorLayers: Boolean;
begin
  Result := Length(FColorLayerRecords) > 0;
end;

function TTFontFace.GetColorLayers(AGlyphId: UInt16): TFontColorLayerArray;
var
  LI: Int32;
begin
  Result := nil;
  SetLength(Result, 0);
  for LI := 0 to High(FColorLayerRecords) do
  begin
    if FColorLayerRecords[LI].BaseGlyphId = AGlyphId then
    begin
      Result := FColorLayerRecords[LI].Layers;
      Exit;
    end;
  end;
end;

function TTFontFace.HasPalette: Boolean;
begin
  Result := (FPaletteCount > 0) and (FColorsPerPalette > 0);
end;

function TTFontFace.ColorsPerPalette: Int32;
begin
  Result := FColorsPerPalette;
end;

function TTFontFace.GetPaletteColor(APaletteIndex, AColorIndex: Int32): TFontPaletteColor;
begin
  Result.Blue := 0;
  Result.Green := 0;
  Result.Red := 0;
  Result.Alpha := 0;
  if (AColorIndex < 0) or (AColorIndex >= FColorsPerPalette) then
    Exit;
  if (APaletteIndex < 0) or (APaletteIndex >= FPaletteCount) then
    Exit;
  { 当前只解析了第一个调色板；多调色板需要偏移计算 }
  if APaletteIndex = 0 then
    Result := FPaletteColors[AColorIndex];
end;

{ -- cmap Format 14 (IVS) -- }

function TTFontFace.HasFmt14: Boolean;
begin
  Result := FHasFmt14;
end;

function TTFontFace.LookupIVS(ABaseCodepoint, AVariationSelector: UInt32): UInt32;
var
  LI, LJ, LNumRanges, LNumMappings: Int32;
  LStart, LEnd, LAdditional: UInt32;
  LNonDefOff: Int32;
begin
  Result := 0;
  if not FHasFmt14 then Exit;

  for LI := 0 to High(FFmt14Records) do
  begin
    if FFmt14Records[LI].VarSelector <> AVariationSelector then
      Continue;

    { Check NonDefaultUVS first (specific glyph override) }
    LNonDefOff := FFmt14Records[LI].NonDefaultUVSOffset;
    if (LNonDefOff > 0) and (LNonDefOff + 4 <= FDataLength) then
    begin
      LNumMappings := Int32(ReadUInt32BE(LNonDefOff));
      for LJ := 0 to LNumMappings - 1 do
      begin
        { NonDefaultUVS: uint24 unicodeValue + uint16 glyphID = 5 bytes/entry }
        if LNonDefOff + 4 + LJ * 5 + 5 > FDataLength then Break;
        LStart := (UInt32(ReadUInt8(LNonDefOff + 4 + LJ * 5)) shl 16) or
                  (UInt32(ReadUInt8(LNonDefOff + 4 + LJ * 5 + 1)) shl 8) or
                  UInt32(ReadUInt8(LNonDefOff + 4 + LJ * 5 + 2));
        if LStart = ABaseCodepoint then
        begin
          Result := ReadUInt16BE(LNonDefOff + 4 + LJ * 5 + 3);
          Exit;
        end;
        if LStart > ABaseCodepoint then
          Break; { sorted }
      end;
    end;

    { Check DefaultUVS (default glyph mapping) }
    if FFmt14Records[LI].DefaultUVSOffset > 0 then
    begin
      if FFmt14Records[LI].DefaultUVSOffset + 4 > FDataLength then Break;
      LNumRanges := Int32(ReadUInt32BE(FFmt14Records[LI].DefaultUVSOffset));
      for LJ := 0 to LNumRanges - 1 do
      begin
        if FFmt14Records[LI].DefaultUVSOffset + 4 + LJ * 5 + 4 > FDataLength then Break;
        LStart := (UInt32(ReadUInt8(FFmt14Records[LI].DefaultUVSOffset + 4 + LJ * 5)) shl 16) or
                  (UInt32(ReadUInt8(FFmt14Records[LI].DefaultUVSOffset + 4 + LJ * 5 + 1)) shl 8) or
                  UInt32(ReadUInt8(FFmt14Records[LI].DefaultUVSOffset + 4 + LJ * 5 + 2));
        LAdditional := ReadUInt8(FFmt14Records[LI].DefaultUVSOffset + 4 + LJ * 5 + 3);
        LEnd := LStart + LAdditional;
        if (ABaseCodepoint >= LStart) and (ABaseCodepoint <= LEnd) then
        begin
          { Default UVS means use the default glyph (0 = "use default") }
          Result := 0; { Return 0 to indicate default mapping }
          Exit;
        end;
      end;
    end;

    Break; { Found the VS record, no match }
  end;
end;

{ -- name table -- }

function TTFontFace.FamilyName: string;
begin
  Result := FFamilyName;
end;

function TTFontFace.SubfamilyName: string;
begin
  Result := FSubfamilyName;
end;

function TTFontFace.FullName: string;
begin
  Result := FFullName;
end;

function TTFontFace.PostScriptName: string;
begin
  Result := FPostScriptName;
end;

{ -- post table -- }

function TTFontFace.HasPostTable: Boolean;
begin
  Result := FHasPostTable;
end;

function TTFontFace.IsFixedPitch: Boolean;
begin
  { 优先使用 post 表的 isFixedPitch，如果为 0 则检查 OS/2 panose[3] = 9 (monospaced) }
  Result := FIsFixedPitch or (FOs2.Panose[3] = 9);
end;

function TTFontFace.UnderlinePosition: Int16;
begin
  Result := FUnderlinePosition;
end;

function TTFontFace.UnderlineThickness: Int16;
begin
  Result := FUnderlineThickness;
end;

{ -- fvar table -- }

function TTFontFace.HasFvar: Boolean;
begin
  Result := FFvarAxisCount > 0;
end;

function TTFontFace.HasCff2: Boolean;
begin
  Result := FCff2Parsed;
end;

function TTFontFace.FvarAxisCount: Int32;
begin
  Result := FFvarAxisCount;
end;

function TTFontFace.VariationAxisCount: Int32;
begin
  Result := FvarAxisCount;
end;

function TTFontFace.GetFvarAxis(AIndex: Int32): TFontVariationAxis;
begin
  if (AIndex >= 0) and (AIndex < FFvarAxisCount) then
    Result := FFvarAxes[AIndex]
  else
  begin
    Result.Tag := 0;
    Result.MinValue := 0;
    Result.DefaultValue := 0;
    Result.MaxValue := 0;
    Result.AxisNameID := 0;
  end;
end;

function TTFontFace.FindFvarAxisByTag(ATag: UInt32): Int32;
var
  I: Int32;
begin
  for I := 0 to FFvarAxisCount - 1 do
    if FFvarAxes[I].Tag = ATag then
      Exit(I);
  Result := -1;
end;

{ -- Variation store -- }

function TTFontFace.HasVariationStore: Boolean;
begin
  Result := FCff2VStoreParsed;
end;

function TTFontFace.VariationRegionCount: Int32;
begin
  Result := FCff2RegionCount;
end;

function TTFontFace.CalcRegionScalar(ARegionIndex: Int32;
  const ACoords: array of Single): Single;
{ ACoords 传入原始 F2DOT14 值 (范围 -16384..16384)，region 也是原始值 }
var
  I, LAxisCount: Int32;
  LAS, LStartF, LPeakF, LEndF, LCoordF: Single;
begin
  Result := 1.0;
  if (not FCff2VStoreParsed) or (ARegionIndex < 0) or
     (ARegionIndex >= FCff2RegionCount) then
    Exit;
  LAxisCount := FCff2AxisCount;
  if LAxisCount > Length(ACoords) then
    LAxisCount := Length(ACoords);
  for I := 0 to LAxisCount - 1 do
  begin
    LStartF := FCff2Regions[ARegionIndex].Axes[I].Start;
    LPeakF  := FCff2Regions[ARegionIndex].Axes[I].Peak;
    LEndF   := FCff2Regions[ARegionIndex].Axes[I].EndCoord;
    LCoordF := ACoords[I];
    { 无效 region 定义或 peak=0 → 该轴不影响 }
    if (LStartF > LPeakF) or (LPeakF > LEndF) then
      LAS := 1.0
    else if (LStartF = LPeakF) and (LPeakF = LEndF) then
      LAS := 1.0 { 退化轴: start=peak=end, scalar=1.0 }
    else if (LStartF < 0) and (LEndF > 0) and (LPeakF <> 0) then
      LAS := 1.0
    else if LPeakF = 0 then
      LAS := 1.0
    else if (LCoordF < LStartF) or (LCoordF > LEndF) then
      LAS := 0.0
    else if LCoordF = LPeakF then
      LAS := 1.0
    else if LCoordF < LPeakF then
      LAS := (LCoordF - LStartF) / (LPeakF - LStartF)
    else
      LAS := (LEndF - LCoordF) / (LEndF - LPeakF);
    Result := Result * LAS;
  end;
end;

{ -- avar table -- }

function TTFontFace.HasAvar: Boolean;
begin
  Result := FAvarAxisCount > 0;
end;

function TTFontFace.NormalizeAxisValue(AAxisIndex: Int32; AUserValue: Single): Single;
var
  LAxis: TFontVariationAxis;
  LNormBefore: Single;
  LSegCount: Int32;
  I: Int32;
  LT, LFrom, LFromNext, LTo, LToNext: Single;
begin
  if (AAxisIndex < 0) or (AAxisIndex >= FFvarAxisCount) then
  begin
    Result := AUserValue;
    Exit;
  end;

  LAxis := FFvarAxes[AAxisIndex];

  { 步骤 1: 将用户值归一化到 [-1, 0, +1] 范围 }
  if AUserValue < LAxis.DefaultValue then
    LNormBefore := (AUserValue - LAxis.DefaultValue) / (LAxis.DefaultValue - LAxis.MinValue)
  else if AUserValue > LAxis.DefaultValue then
    LNormBefore := (AUserValue - LAxis.DefaultValue) / (LAxis.MaxValue - LAxis.DefaultValue)
  else
    LNormBefore := 0;

  { 步骤 2: 应用 avar segment map（如果存在） }
  if (AAxisIndex < FAvarAxisCount) and (Length(FAvarSegmentMaps) > AAxisIndex) then
  begin
    LSegCount := Length(FAvarSegmentMaps[AAxisIndex]);
    if LSegCount >= 2 then
    begin
      { 找到包含 LNormBefore 的 segment 并线性插值 }
      for I := 0 to LSegCount - 2 do
      begin
        LFrom := FAvarSegmentMaps[AAxisIndex][I].FromCoord;
        LFromNext := FAvarSegmentMaps[AAxisIndex][I + 1].FromCoord;
        if (LNormBefore >= LFrom) and (LNormBefore <= LFromNext) then
        begin
          if LFromNext <> LFrom then
          begin
            LTo := FAvarSegmentMaps[AAxisIndex][I].ToCoord;
            LToNext := FAvarSegmentMaps[AAxisIndex][I + 1].ToCoord;
            LT := (LNormBefore - LFrom) / (LFromNext - LFrom);
            Result := LTo + LT * (LToNext - LTo);
            Exit;
          end;
        end;
      end;
      { 如果没有命中任何 segment（边界情况），使用最后一个 segment 的 ToCoord }
      if LNormBefore >= FAvarSegmentMaps[AAxisIndex][LSegCount - 1].FromCoord then
        Result := FAvarSegmentMaps[AAxisIndex][LSegCount - 1].ToCoord
      else
        Result := LNormBefore; { 低于第一个 segment 的值，保持不变 }
    end
    else
      Result := LNormBefore;
  end
  else
    Result := LNormBefore;
end;

{ -- fvar instances -- }

function TTFontFace.FvarInstanceCount: Int32;
begin
  Result := FFvarInstanceCount;
end;

function TTFontFace.GetFvarInstance(AIndex: Int32): TFontNamedInstance;
begin
  if (AIndex >= 0) and (AIndex < FFvarInstanceCount) then
    Result := FFvarInstances[AIndex]
  else
  begin
    Result.NameID := 0;
    SetLength(Result.Coordinates, FFvarAxisCount);
    FillChar(Result.Coordinates[0], FFvarAxisCount * SizeOf(Single), 0);
  end;
end;

{ -- Variable font deltas -- }

function TTFontFace.HasGvar: Boolean;
begin
  Result := FGvarParsed;
end;

function TTFontFace.HasHvar: Boolean;
begin
  Result := FHvarParsed;
end;

procedure TTFontFace.ParseHvar;
{**
 * HVAR table layout:
 *   +0:  uint32 version (0x00010000)
 *   +4:  uint32 itemVariationStoreOffset
 *   +8:  uint32 advanceWidthMappingOffset (0 = not present)
 *   +12: uint32 lsbMappingOffset (0 = not present)
 *   +16: uint32 rsbMappingOffset (0 = not present)
 *
 * ItemVariationStore:
 *   +0:  uint16 format (1)
 *   +2:  uint32 variationRegionListOffset (from IVS start)
 *   +6:  uint16 itemVariationDataCount
 *   +8:  uint32 itemVariationDataOffsets[itemVariationDataCount]
 *
 * VariationRegionList:
 *   +0:  uint16 axisCount
 *   +2:  uint16 regionCount
 *   +4:  VariationRegion[regionCount] (each: axisCount * 3 * F2.14)
 *
 * ItemVariationData:
 *   +0:  uint16 itemCount
 *   +2:  uint16 wordDeltaCount (bit 15 = LONG_WORDS, bits 14:0 = count)
 *   +4:  uint16 regionIndexCount
 *   +6:  uint16 regionIndices[regionIndexCount]
 *   +6 + regionIndexCount*2: delta array
 *
 * DeltaSetIndexMap:
 *   +0:  uint16 format (0=entryFormat at +2, 1=innerIndex uses 32-bit)
 *   +2:  uint8 entryFormat (bits 1:0=innerIndexBitCount, 7:2=mapCount-1... wait)
 *   Actually: format byte, then entryFormat, then mapCount, then entries
 *}
var
  LHvarIdx, LHvarBase, LHvarLen: Int32;
  LIVSOff, LMapOff: Int32;
  LIVSBase, LRegionListOff, LRegionCount, LAxisCount, LI, LJ: Int32;
  LDataCount, LDataOff, LDataBase, LMapBase: Int32;
  LItemCount, LWordDeltaCount, LRegionIdxCount: Int32;
  LLongWords, LDeltaOffset, LDelta: Int32;
  LMapFormat, LEntryFormat, LMapCount: Int32;
  LInnerBits, LEntrySize, LOuter, LInner: UInt32;
begin
  FHvarParsed := False;
  LHvarIdx := FindTable(TABLE_TAG_HVAR);
  if LHvarIdx < 0 then
    Exit;
  LHvarBase := FTables[LHvarIdx].Offset;
  LHvarLen := FTables[LHvarIdx].Length;
  if FDataLength < LHvarBase + 12 then
    Exit;

  { Read HVAR header }
  LIVSOff := ReadUInt32BE(LHvarBase + 4);
  LMapOff := ReadUInt32BE(LHvarBase + 8);
  if (LIVSOff = 0) or (LHvarBase + LIVSOff + 8 > FDataLength) then
    Exit;

  { Parse ItemVariationStore }
  LIVSBase := LHvarBase + LIVSOff;
  LRegionListOff := ReadUInt32BE(LIVSBase + 2);
  LDataCount := ReadUInt16BE(LIVSBase + 6);
  if (LDataCount <= 0) or (LDataCount > 256) then
    Exit;

  { Parse VariationRegionList }
  if LIVSBase + LRegionListOff + 4 > FDataLength then Exit;
  LAxisCount := ReadUInt16BE(LIVSBase + LRegionListOff);
  LRegionCount := ReadUInt16BE(LIVSBase + LRegionListOff + 2);
  FHvarAxisCount := LAxisCount;
  SetLength(FHvarRegions, LRegionCount);
  for LI := 0 to LRegionCount - 1 do
  begin
    SetLength(FHvarRegions[LI], LAxisCount * 3);
    for LJ := 0 to LAxisCount * 3 - 1 do
    begin
      if LIVSBase + LRegionListOff + 4 + (LI * LAxisCount * 3 + LJ) * 2 + 2 > FDataLength then
        Break;
      FHvarRegions[LI][LJ] := ReadInt16BE(LIVSBase + LRegionListOff + 4 +
        (LI * LAxisCount * 3 + LJ) * 2);
    end;
  end;

  { Parse ItemVariationData and build delta table }
  SetLength(FHvarDeltas, LDataCount);
  FHvarItemCount := 0;
  FHvarDeltaBits := 0;

  for LI := 0 to LDataCount - 1 do
  begin
    if LIVSBase + 8 + LI * 4 + 4 > FDataLength then Break;
    LDataOff := ReadUInt32BE(LIVSBase + 8 + LI * 4);
    LDataBase := LIVSBase + LDataOff;
    if LDataBase + 6 > FDataLength then Continue;
    LItemCount := ReadUInt16BE(LDataBase);
    LWordDeltaCount := ReadUInt16BE(LDataBase + 2);
    LRegionIdxCount := ReadUInt16BE(LDataBase + 4);
    if LItemCount > FHvarItemCount then
      FHvarItemCount := LItemCount;

    LLongWords := (LWordDeltaCount and $8000) shr 15;
    LWordDeltaCount := LWordDeltaCount and $7FFF;
    if LLongWords <> 0 then
      FHvarDeltaBits := 1;

    { Delta array: first LWordDeltaCount items are 32-bit if LLongWords, else 16-bit;
      remaining items are 16-bit if LLongWords, else 8-bit }
    SetLength(FHvarDeltas[LI], LItemCount * LRegionIdxCount);
    LDeltaOffset := LDataBase + 6 + LRegionIdxCount * 2;
    for LJ := 0 to LItemCount * LRegionIdxCount - 1 do
    begin
      if LJ div LRegionIdxCount < LWordDeltaCount then
      begin
        { Word delta }
        if LLongWords <> 0 then
        begin
          if LDeltaOffset + 4 > FDataLength then Break;
          FHvarDeltas[LI][LJ] := ReadInt16BE(LDeltaOffset); { truncate to 16-bit for simplicity }
          Inc(LDeltaOffset, 4);
        end
        else
        begin
          if LDeltaOffset + 2 > FDataLength then Break;
          FHvarDeltas[LI][LJ] := ReadInt16BE(LDeltaOffset);
          Inc(LDeltaOffset, 2);
        end;
      end
      else
      begin
        { Byte delta }
        if LLongWords <> 0 then
        begin
          if LDeltaOffset + 2 > FDataLength then Break;
          FHvarDeltas[LI][LJ] := ReadInt16BE(LDeltaOffset);
          Inc(LDeltaOffset, 2);
        end
        else
        begin
          if LDeltaOffset + 1 > FDataLength then Break;
          FHvarDeltas[LI][LJ] := ShortInt(ReadUInt8(LDeltaOffset));
          Inc(LDeltaOffset, 1);
        end;
      end;
    end;
  end;

  { Parse DeltaSetIndexMap (advance width mapping) }
  if LMapOff <> 0 then
  begin
    LMapBase := LHvarBase + LMapOff;
    if LMapBase + 4 > FDataLength then
    begin
      FHvarParsed := FHvarItemCount > 0;
      Exit;
    end;
    FHvarIndexFormat := ReadUInt16BE(LMapBase);
    LEntryFormat := ReadUInt8(LMapBase + 2);
    LMapCount := ReadUInt32BE(LMapBase + 3) and $00FFFFFF; { 24-bit count }
    LInnerBits := (LEntryFormat and $0F) + 1;
    LEntrySize := ((LEntryFormat shr 4) and $03) + 1; { bytes per entry: 1-4 }
    SetLength(FHvarIndexMap, LMapCount);
    for LI := 0 to LMapCount - 1 do
    begin
      LOuter := 0;
      LInner := 0;
      if LMapBase + 6 + LI * LEntrySize + LEntrySize > FDataLength then Break;
      case LEntrySize of
        1: begin
          LOuter := 0;
          LInner := ReadUInt8(LMapBase + 6 + LI * LEntrySize);
        end;
        2: begin
          LOuter := ReadUInt8(LMapBase + 6 + LI * LEntrySize) shr (8 - LInnerBits);
          LInner := ReadUInt16BE(LMapBase + 6 + LI * LEntrySize) and ((1 shl LInnerBits) - 1);
        end;
        3: begin
          LOuter := ReadUInt16BE(LMapBase + 6 + LI * LEntrySize) shr (16 - LInnerBits);
          LInner := (ReadUInt16BE(LMapBase + 6 + LI * LEntrySize + 1)) and ((1 shl LInnerBits) - 1);
        end;
        4: begin
          LOuter := ReadUInt32BE(LMapBase + 6 + LI * LEntrySize) shr (32 - LInnerBits);
          LInner := ReadUInt32BE(LMapBase + 6 + LI * LEntrySize) and ((1 shl LInnerBits) - 1);
        end;
      end;
      FHvarIndexMap[LI] := (LOuter shl 16) or LInner;
    end;
  end;

  FHvarParsed := FHvarItemCount > 0;
end;

{ -- CPAL: Color Palette Table -- }

procedure TTFontFace.ParseCpal;
var
  LTableIdx, LBase: Int32;
  LVersion, LNumPaletteEntries, LNumPalettes, LColorOff: Int32;
  LI: Int32;
begin
  LTableIdx := FindTable(TABLE_TAG_CPAL);
  if LTableIdx < 0 then
    Exit;
  LBase := FTables[LTableIdx].Offset;
  if FDataLength < LBase + 12 then
    Exit;
  LVersion := ReadUInt16BE(LBase);
  LNumPaletteEntries := ReadUInt16BE(LBase + 2);
  LNumPalettes := ReadUInt16BE(LBase + 4);
  if (LNumPaletteEntries <= 0) or (LNumPalettes <= 0) then
    Exit;
  { colorRecordArrayOffset (uint32 at offset 8) }
  if FDataLength < LBase + 12 then
    Exit;
  LColorOff := LBase + Int32(ReadUInt32BE(LBase + 8));
  { 读取第一个调色板的所有颜色（BGRA 格式，每色 4 字节） }
  if FDataLength < LColorOff + LNumPaletteEntries * 4 then
    Exit;
  FPaletteCount := LNumPalettes;
  FColorsPerPalette := LNumPaletteEntries;
  SetLength(FPaletteColors, LNumPaletteEntries);
  for LI := 0 to LNumPaletteEntries - 1 do
  begin
    FPaletteColors[LI].Blue := FData[LColorOff + LI * 4];
    FPaletteColors[LI].Green := FData[LColorOff + LI * 4 + 1];
    FPaletteColors[LI].Red := FData[LColorOff + LI * 4 + 2];
    FPaletteColors[LI].Alpha := FData[LColorOff + LI * 4 + 3];
  end;
end;

{ -- COLR: Color Table -- }

procedure TTFontFace.ParseColr;
var
  LTableIdx, LBase: Int32;
  LVersion, LBaseGlyphRecordCount, LBaseGlyphRecordArrayOff: Int32;
  LLayerArrayOff, LLayerCount: Int32;
  LI, LJ, LBaseGid, LFirstLayerIdx, LNumLayers: Int32;
begin
  LTableIdx := FindTable(TABLE_TAG_COLR);
  if LTableIdx < 0 then
    Exit;
  LBase := FTables[LTableIdx].Offset;
  if FDataLength < LBase + 14 then
    Exit;
  LVersion := ReadUInt16BE(LBase);
  if LVersion > 1 then
    Exit; { 只支持 COLR v0/v1 }
  LBaseGlyphRecordCount := ReadUInt16BE(LBase + 2);
  LBaseGlyphRecordArrayOff := LBase + Int32(ReadUInt32BE(LBase + 4));
  LLayerArrayOff := LBase + Int32(ReadUInt32BE(LBase + 8));
  LLayerCount := ReadUInt16BE(LBase + 12);
  if (LBaseGlyphRecordCount <= 0) or (LLayerCount <= 0) then
    Exit;
  { 解析 base glyph records: 每条 6 字节 (uint16 gid, uint16 firstLayerIdx, uint16 numLayers) }
  if FDataLength < LBaseGlyphRecordArrayOff + LBaseGlyphRecordCount * 6 then
    Exit;
  SetLength(FColorLayerRecords, LBaseGlyphRecordCount);
  for LI := 0 to LBaseGlyphRecordCount - 1 do
  begin
    LBaseGid := ReadUInt16BE(LBaseGlyphRecordArrayOff + LI * 6);
    LFirstLayerIdx := ReadUInt16BE(LBaseGlyphRecordArrayOff + LI * 6 + 2);
    LNumLayers := ReadUInt16BE(LBaseGlyphRecordArrayOff + LI * 6 + 4);
    FColorLayerRecords[LI].BaseGlyphId := LBaseGid;
    SetLength(FColorLayerRecords[LI].Layers, LNumLayers);
    { 解析 layer records: 每条 4 字节 (uint16 gid, uint16 paletteIndex) }
    for LJ := 0 to LNumLayers - 1 do
    begin
      if FDataLength < LLayerArrayOff + (LFirstLayerIdx + LJ) * 4 + 4 then
      begin
        SetLength(FColorLayerRecords[LI].Layers, LJ);
        Break;
      end;
      FColorLayerRecords[LI].Layers[LJ].GlyphId :=
        ReadUInt16BE(LLayerArrayOff + (LFirstLayerIdx + LJ) * 4);
      FColorLayerRecords[LI].Layers[LJ].PaletteIndex :=
        ReadUInt16BE(LLayerArrayOff + (LFirstLayerIdx + LJ) * 4 + 2);
    end;
  end;
end;

{ -- CBDT/CBLC: Color Bitmap Data Table -- }

procedure TTFontFace.ParseCbdt;
var
  LCblcIdx, LCbdtIdx: Int32;
  LCblcBase, LCbdtBase: Int32;
  LVersion, LNumSizes: UInt32;
  LBitmapSizeOff: Int32;
  LIndexSubTableArrayOff, LNumberOfIndexSubTables: UInt32;
  LStartGlyph, LEndGlyph: UInt16;
  LPpemX, LPpemY: UInt8;
  LI, LJ: Int32;
  LArrOff, LSubOff: Int32;
  LFirstGlyph, LLastGlyph: UInt16;
  LAdditionalOffset: UInt32;
  LIndexFormat, LImageFormat: UInt16;
  LImageDataOffset: UInt32;
  LNumGlyphs, LNumOffsets: Int32;
begin
  LCblcIdx := FindTable(TABLE_TAG_CBLC);
  LCbdtIdx := FindTable(TABLE_TAG_CBDT);
  if (LCblcIdx < 0) or (LCbdtIdx < 0) then
    Exit;
  LCblcBase := FTables[LCblcIdx].Offset;
  LCbdtBase := FTables[LCbdtIdx].Offset;
  if FDataLength < LCblcBase + 8 then
    Exit;
  { CBLC header: version(uint16 major.minor) + numSizes(uint32) }
  LVersion := ReadUInt16BE(LCblcBase);
  if LVersion > 3 then
    Exit;
  LNumSizes := ReadUInt32BE(LCblcBase + 4);
  if LNumSizes = 0 then
    Exit;
  { 只解析第一个 strike（最大的那个，通常是唯一的） }
  LBitmapSizeOff := LCblcBase + 8;
  if FDataLength < LBitmapSizeOff + 48 then
    Exit;
  { bitmapSize record: 48 bytes }
  LIndexSubTableArrayOff := ReadUInt32BE(LBitmapSizeOff);
  LNumberOfIndexSubTables := ReadUInt32BE(LBitmapSizeOff + 8);
  { hori SbitLineMetrics at +16 (12 bytes), skip }
  { vert SbitLineMetrics at +28 (12 bytes), skip }
  LStartGlyph := ReadUInt16BE(LBitmapSizeOff + 40);
  LEndGlyph := ReadUInt16BE(LBitmapSizeOff + 42);
  LPpemX := ReadUInt8(LBitmapSizeOff + 44);
  LPpemY := ReadUInt8(LBitmapSizeOff + 45);
  if (LStartGlyph > LEndGlyph) or (LNumberOfIndexSubTables = 0) then
    Exit;
  FHasBitmapStrikes := True;
  FBitmapStrikePpem := LPpemX;
  FBitmapStrikeStartGlyph := LStartGlyph;
  FBitmapStrikeEndGlyph := LEndGlyph;
  SetLength(FBitmapIndexSubTables, LNumberOfIndexSubTables);
  { 解析 index sub-table array }
  for LI := 0 to LNumberOfIndexSubTables - 1 do
  begin
    LArrOff := LCblcBase + LIndexSubTableArrayOff + LI * 8;
    if FDataLength < LArrOff + 8 then
    begin
      SetLength(FBitmapIndexSubTables, LI);
      Break;
    end;
    LFirstGlyph := ReadUInt16BE(LArrOff);
    LLastGlyph := ReadUInt16BE(LArrOff + 2);
    LAdditionalOffset := ReadUInt32BE(LArrOff + 4);
    { index sub-table 在 array 起始 + additionalOffset 处 }
    LSubOff := LCblcBase + LIndexSubTableArrayOff + LAdditionalOffset;
    if FDataLength < LSubOff + 8 then
      Continue;
    LIndexFormat := ReadUInt16BE(LSubOff);
    LImageFormat := ReadUInt16BE(LSubOff + 2);
    LImageDataOffset := ReadUInt32BE(LSubOff + 4);
    FBitmapIndexSubTables[LI].FirstGlyph := LFirstGlyph;
    FBitmapIndexSubTables[LI].LastGlyph := LLastGlyph;
    FBitmapIndexSubTables[LI].IndexFormat := LIndexFormat;
    FBitmapIndexSubTables[LI].ImageFormat := LImageFormat;
    FBitmapIndexSubTables[LI].ImageDataOffset := LImageDataOffset;
    { indexFormat 1: 偏移数组 (uint32 per glyph + 1 end) }
    if LIndexFormat = 1 then
    begin
      LNumGlyphs := LLastGlyph - LFirstGlyph + 1;
      LNumOffsets := LNumGlyphs + 1;
      SetLength(FBitmapIndexSubTables[LI].Offsets, LNumOffsets);
      for LJ := 0 to LNumOffsets - 1 do
      begin
        if FDataLength < LSubOff + 8 + (LJ + 1) * 4 then
        begin
          SetLength(FBitmapIndexSubTables[LI].Offsets, LJ);
          Break;
        end;
        FBitmapIndexSubTables[LI].Offsets[LJ] :=
          ReadUInt32BE(LSubOff + 8 + LJ * 4);
      end;
    end
    { indexFormat 2: 所有字形等大小，不需要偏移数组 }
    else if LIndexFormat = 2 then
    begin
      { 标记为 format 2，Offsets 为空，通过 ImageDataOffset + glyphIdx * size 计算 }
      SetLength(FBitmapIndexSubTables[LI].Offsets, 0);
    end;
  end;
end;

function TTFontFace.HasBitmapStrikes: Boolean;
begin
  Result := FHasBitmapStrikes;
end;

function TTFontFace.GetBitmapGlyph(AGlyphId: UInt16): TFontBitmapGlyph;
var
  LI, LGlyphIdx: Int32;
  LGlyphDataOff, LGlyphDataSize: Int32;
  LPngStart, LPngSize: Int32;
  LJ: Int32;
  LImageFormat: UInt16;
begin
  Result.Width := 0;
  Result.Height := 0;
  Result.BearingX := 0;
  Result.BearingY := 0;
  Result.Advance := 0;
  SetLength(Result.PngData, 0);
  Result.PngDataLength := 0;
  if not FHasBitmapStrikes then
    Exit;
  { 查找包含 AGlyphId 的 sub-table }
  for LI := 0 to High(FBitmapIndexSubTables) do
  begin
    if (AGlyphId < FBitmapIndexSubTables[LI].FirstGlyph) or
       (AGlyphId > FBitmapIndexSubTables[LI].LastGlyph) then
      Continue;
    LGlyphIdx := AGlyphId - FBitmapIndexSubTables[LI].FirstGlyph;
    LImageFormat := FBitmapIndexSubTables[LI].ImageFormat;
    { indexFormat 1: 偏移数组 }
    if FBitmapIndexSubTables[LI].IndexFormat = 1 then
    begin
      if LGlyphIdx + 1 > High(FBitmapIndexSubTables[LI].Offsets) then
        Exit;
      LGlyphDataOff := FTables[FindTable(TABLE_TAG_CBDT)].Offset +
        FBitmapIndexSubTables[LI].ImageDataOffset +
        FBitmapIndexSubTables[LI].Offsets[LGlyphIdx];
      LGlyphDataSize := FBitmapIndexSubTables[LI].Offsets[LGlyphIdx + 1] -
        FBitmapIndexSubTables[LI].Offsets[LGlyphIdx];
    end
    { indexFormat 2: 等大小 }
    else if FBitmapIndexSubTables[LI].IndexFormat = 2 then
    begin
      { indexFormat 2 后跟 4 字节 imageSize }
      if FDataLength < FTables[FindTable(TABLE_TAG_CBLC)].Offset +
        FBitmapIndexSubTables[LI].ImageDataOffset + 8 + 4 then
        Exit;
      LGlyphDataSize := ReadUInt32BE(
        FTables[FindTable(TABLE_TAG_CBLC)].Offset +
        FBitmapIndexSubTables[LI].ImageDataOffset + 8);
      LGlyphDataOff := FTables[FindTable(TABLE_TAG_CBDT)].Offset +
        LGlyphIdx * LGlyphDataSize;
    end
    else
      Exit;
    if (LGlyphDataSize < 9) or (FDataLength < LGlyphDataOff + LGlyphDataSize) then
      Exit;
    { 解析 smallGlyphMetrics (8 bytes) }
    Result.Height := FData[LGlyphDataOff];
    Result.Width := FData[LGlyphDataOff + 1];
    Result.BearingX := Int8(FData[LGlyphDataOff + 2]);
    Result.BearingY := Int8(FData[LGlyphDataOff + 3]);
    Result.Advance := FData[LGlyphDataOff + 4];
    { 搜索 PNG 签名 (89 50 4E 47 0D 0A 1A 0A) }
    LPngStart := -1;
    for LJ := 8 to LGlyphDataSize - 8 do
    begin
      if (FData[LGlyphDataOff + LJ] = $89) and
         (FData[LGlyphDataOff + LJ + 1] = $50) and
         (FData[LGlyphDataOff + LJ + 2] = $4E) and
         (FData[LGlyphDataOff + LJ + 3] = $47) then
      begin
        LPngStart := LJ;
        Break;
      end;
    end;
    if LPngStart < 0 then
      Exit;
    LPngSize := LGlyphDataSize - LPngStart;
    SetLength(Result.PngData, LPngSize);
    Move(FData[LGlyphDataOff + LPngStart], Result.PngData[0], LPngSize);
    Result.PngDataLength := LPngSize;
    Exit;
  end;
end;

{ -- CFF Type 1/2 outline parsing -- }

procedure TTFontFace.ParseCff;

  { Read a CFF INDEX at ABase, return item count and per-item offsets }
  procedure ReadCffIndex(ABase: Int32; out ACount: Int32;
    out AOffsets: array of UInt32; out ADataStart: Int32);
  var
    LOffSize, I, J: Int32;
    LOff: UInt32;
  begin
    ACount := 0;
    ADataStart := ABase + 2;
    if FDataLength < ABase + 2 then Exit;
    ACount := ReadUInt16BE(ABase);
    if ACount = 0 then
    begin
      ADataStart := ABase + 2;
      Exit;
    end;
    if FDataLength < ABase + 3 then begin ACount := 0; Exit; end;
    LOffSize := ReadUInt8(ABase + 2);
    if (LOffSize < 1) or (LOffSize > 4) then begin ACount := 0; Exit; end;
    if FDataLength < ABase + 3 + (ACount + 1) * LOffSize then
    begin
      ACount := 0;
      Exit;
    end;
    { Read offsets }
    for I := 0 to ACount do
    begin
      LOff := 0;
      for J := 0 to LOffSize - 1 do
        LOff := (LOff shl 8) or ReadUInt8(ABase + 3 + I * LOffSize + J);
      AOffsets[I] := LOff;
    end;
    ADataStart := ABase + 3 + (ACount + 1) * LOffSize;
  end;

  { Parse CFF DICT data, extract key operators }
  procedure ParseCffDict(ADictBase, ADictSize, ACffDataStart: Int32;
    out ACharStringsOff, APrivateSize, APrivateOff, ASubrsOff: Int32);
  var
    LI, LOp: Int32;
    LOperands: array of Int32;
    LNumOps: Int32;
    LB: Byte;
    LVal: Int32;
  begin
    ACharStringsOff := -1;
    APrivateSize := 0;
    APrivateOff := -1;
    ASubrsOff := -1;
    SetLength(LOperands, 48);
    LNumOps := 0;
    LI := ADictBase;
    while LI < ADictBase + ADictSize do
    begin
      LB := ReadUInt8(LI);
      if LB <= 21 then
      begin
        { Operator }
        if LB = 12 then
        begin
          if LI + 1 >= ADictBase + ADictSize then Break;
          LOp := (LB shl 8) or ReadUInt8(LI + 1);
          Inc(LI, 2);
        end
        else
        begin
          LOp := LB;
          Inc(LI);
        end;
        case LOp of
          $11: { CharStrings }
            if LNumOps >= 1 then
              ACharStringsOff := LOperands[LNumOps - 1];
          $12: { Private: size + offset }
            if LNumOps >= 2 then
            begin
              APrivateSize := LOperands[LNumOps - 2];
              APrivateOff := LOperands[LNumOps - 1];
            end;
        end;
        LNumOps := 0;
      end
      else if LB = 28 then
      begin
        { shortint }
        LVal := SmallInt((ReadUInt8(LI + 1) shl 8) or ReadUInt8(LI + 2));
        if LNumOps < Length(LOperands) then
        begin
          LOperands[LNumOps] := LVal;
          Inc(LNumOps);
        end;
        Inc(LI, 3);
      end
      else if LB = 29 then
      begin
        { longint }
        LVal := Int32((ReadUInt8(LI + 1) shl 24) or (ReadUInt8(LI + 2) shl 16) or
          (ReadUInt8(LI + 3) shl 8) or ReadUInt8(LI + 4));
        if LNumOps < Length(LOperands) then
        begin
          LOperands[LNumOps] := LVal;
          Inc(LNumOps);
        end;
        Inc(LI, 5);
      end
      else if (LB >= 32) and (LB <= 246) then
      begin
        if LNumOps < Length(LOperands) then
        begin
          LOperands[LNumOps] := LB - 139;
          Inc(LNumOps);
        end;
        Inc(LI);
      end
      else if (LB >= 247) and (LB <= 250) then
      begin
        LVal := (LB - 247) * 256 + ReadUInt8(LI + 1) + 108;
        if LNumOps < Length(LOperands) then
        begin
          LOperands[LNumOps] := LVal;
          Inc(LNumOps);
        end;
        Inc(LI, 2);
      end
      else if (LB >= 251) and (LB <= 254) then
      begin
        LVal := -((LB - 251) * 256) - ReadUInt8(LI + 1) - 108;
        if LNumOps < Length(LOperands) then
        begin
          LOperands[LNumOps] := LVal;
          Inc(LNumOps);
        end;
        Inc(LI, 2);
      end
      else
        Inc(LI);
    end;
    { Parse Private DICT for Subrs offset (offset is CFF-relative, add base) }
    if (APrivateOff >= 0) and (APrivateSize > 0) then
    begin
      LI := APrivateOff + ACffDataStart;
      LNumOps := 0;
      while LI < APrivateOff + ACffDataStart + APrivateSize do
      begin
        LB := ReadUInt8(LI);
        if LB <= 21 then
        begin
          if LB = 12 then
          begin
            if LI + 1 >= APrivateOff + ACffDataStart + APrivateSize then Break;
            LOp := (LB shl 8) or ReadUInt8(LI + 1);
            Inc(LI, 2);
          end
          else
          begin
            LOp := LB;
            Inc(LI);
          end;
          case LOp of
            $13: { Subrs }
              if LNumOps >= 1 then
                ASubrsOff := LOperands[LNumOps - 1];
            $14: { defaultWidthX }
              if LNumOps >= 1 then
                FCffDefaultWidthX := LOperands[LNumOps - 1];
            $15: { nominalWidthX }
              if LNumOps >= 1 then
                FCffNominalWidthX := LOperands[LNumOps - 1];
          end;
          LNumOps := 0;
        end
        else if LB = 28 then
        begin
          LVal := SmallInt((ReadUInt8(LI + 1) shl 8) or ReadUInt8(LI + 2));
          if LNumOps < Length(LOperands) then
          begin
            LOperands[LNumOps] := LVal;
            Inc(LNumOps);
          end;
          Inc(LI, 3);
        end
        else if LB = 29 then
        begin
          LVal := Int32((ReadUInt8(LI + 1) shl 24) or (ReadUInt8(LI + 2) shl 16) or
            (ReadUInt8(LI + 3) shl 8) or ReadUInt8(LI + 4));
          if LNumOps < Length(LOperands) then
          begin
            LOperands[LNumOps] := LVal;
            Inc(LNumOps);
          end;
          Inc(LI, 5);
        end
        else if (LB >= 32) and (LB <= 246) then
        begin
          if LNumOps < Length(LOperands) then
          begin
            LOperands[LNumOps] := LB - 139;
            Inc(LNumOps);
          end;
          Inc(LI);
        end
        else if (LB >= 247) and (LB <= 250) then
        begin
          LVal := (LB - 247) * 256 + ReadUInt8(LI + 1) + 108;
          if LNumOps < Length(LOperands) then
          begin
            LOperands[LNumOps] := LVal;
            Inc(LNumOps);
          end;
          Inc(LI, 2);
        end
        else if (LB >= 251) and (LB <= 254) then
        begin
          LVal := -((LB - 251) * 256) - ReadUInt8(LI + 1) - 108;
          if LNumOps < Length(LOperands) then
          begin
            LOperands[LNumOps] := LVal;
            Inc(LNumOps);
          end;
          Inc(LI, 2);
        end
        else
          Inc(LI);
      end;
    end;
  end;

var
  LCffIdx, LCffBase, LCffDataStart: Int32;
  LHdrSize, LOffSize: Int32;
  LNameCount, LTopCount, LStrCount: Int32;
  LNameDataStart, LTopDataStart, LStrDataStart, LGsubrDataStart: Int32;
  LCharStringsOff, LPrivateSize, LPrivateOff, LSubrsOff: Int32;
  LTopDictBase, LTopDictSize: Int32;
  LI, LJ: Int32;
  LItemBase: Int32;
  LArr: array of UInt32;
begin
  FCffParsed := False;
  FCffGlyphCount := 0;
  FCffDefaultWidthX := 0;
  FCffNominalWidthX := 0;

  LCffIdx := FindTable(TABLE_TAG_CFF);
  if LCffIdx < 0 then Exit;
  LCffBase := Int32(FTables[LCffIdx].Offset);
  LCffDataStart := LCffBase; { Save CFF table start for absolute offset calculations }

  if FDataLength < LCffBase + 4 then Exit;
  { CFF header: major(1) minor(1) hdrSize(1) offSize(1) }
  LHdrSize := ReadUInt8(LCffBase + 2);

  { Name INDEX }
  SetLength(LArr, 2048);
  ReadCffIndex(LCffBase + LHdrSize, LNameCount, LArr, LNameDataStart);
  if LNameCount = 0 then Exit;

  { Top DICT INDEX - compute data start from name INDEX }
  { name data end = LNameDataStart + (last offset - 1) }
  LItemBase := LNameDataStart + Int32(LArr[LNameCount]) - 1;
  ReadCffIndex(LItemBase, LTopCount, LArr, LTopDataStart);
  if LTopCount = 0 then Exit;

  { Top DICT data: first item, size = offsets[1] - 1 }
  LTopDictBase := LTopDataStart;
  LTopDictSize := Int32(LArr[1]) - 1;
  ParseCffDict(LTopDictBase, LTopDictSize, LCffDataStart,
    LCharStringsOff, LPrivateSize, LPrivateOff, LSubrsOff);
  if LCharStringsOff < 0 then Exit;
  { Convert offsets from CFF-relative to absolute FData offsets }
  LCharStringsOff := LCharStringsOff + LCffDataStart;
  if LPrivateOff >= 0 then
    LPrivateOff := LPrivateOff + LCffDataStart;

  { Skip String INDEX to find Global Subrs }
  LItemBase := LTopDataStart + Int32(LArr[LTopCount]) - 1;
  ReadCffIndex(LItemBase, LStrCount, LArr, LStrDataStart);
  LItemBase := LStrDataStart;
  if LStrCount > 0 then
    LItemBase := LStrDataStart + Int32(LArr[LStrCount]) - 1;

  { Global Subrs INDEX }
  SetLength(LArr, 65536);
  ReadCffIndex(LItemBase, LI, LArr, LGsubrDataStart);
  SetLength(FCffGlobalSubrs, LI);
  for LJ := 0 to LI - 1 do
  begin
    FCffGlobalSubrs[LJ].Data := Copy(FData,
      LGsubrDataStart + Int32(LArr[LJ]) - 1,
      Int32(LArr[LJ + 1]) - Int32(LArr[LJ]));
  end;

  { CharStrings INDEX }
  ReadCffIndex(LCharStringsOff, FCffGlyphCount, LArr, LItemBase);
  if FCffGlyphCount <= 0 then begin FCffGlyphCount := 0; Exit; end;
  SetLength(FCffCharStringOffsets, FCffGlyphCount + 1);
  for LI := 0 to FCffGlyphCount do
    FCffCharStringOffsets[LI] := UInt32(LItemBase) + LArr[LI] - 1;
  FCffCharStringsBase := LItemBase;

  { Local Subrs from Private DICT }
  SetLength(FCffLocalSubrs, 0);
  if (LPrivateOff >= 0) and (LSubrsOff >= 0) then
  begin
    LItemBase := LPrivateOff + LSubrsOff;
    ReadCffIndex(LItemBase, LI, LArr, LJ);
    SetLength(FCffLocalSubrs, LI);
    for LStrCount := 0 to LI - 1 do
    begin
      FCffLocalSubrs[LStrCount].Data := Copy(FData,
        LJ + Int32(LArr[LStrCount]) - 1,
        Int32(LArr[LStrCount + 1]) - Int32(LArr[LStrCount]));
    end;
  end;

  FCffParsed := True;
end;

function TTFontFace.CffGlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;
{ Type 2 charstring interpreter → outline }
const
  MAX_STACK = 48;
  MAX_CALL_DEPTH = 32;
var
  LCharStrBase, LCharStrLen: Int32;
  { Stack }
  LStack: array[0..MAX_STACK - 1] of Int32;
  LStackTop: Int32;
  { Call stack for subroutines }
  LCallStack: array[0..MAX_CALL_DEPTH - 1] of record
    Data: PByte;
    Len: Int32;
    Pos: Int32;
    Watermark: Int32;
  end;
  LCallDepth: Int32;
  LData: PByte;
  LLen, LPos: Int32;
  { Path state }
  LX, LY: Int32;
  LPoints: TFontContourPointArray;
  LContours: array of UInt16;
  LPointCount, LContourCount: Int32;
  LHasMove: Boolean;
  LWidthParsed: Boolean;
  LWidth: Int32;
  LStackWatermark: Int32; { stack height at subroutine entry; hints only consume above this }

  procedure Push(AVal: Int32);
  begin
    if LStackTop < MAX_STACK then
    begin
      LStack[LStackTop] := AVal;
      Inc(LStackTop);
    end;
  end;

  function Pop: Int32;
  begin
    if LStackTop > 0 then
    begin
      Dec(LStackTop);
      Result := LStack[LStackTop];
    end
    else
      Result := 0;
  end;

  procedure AddPoint(AX, AY: Int32; AOnCurve: Boolean);
  begin
    if LPointCount >= Length(LPoints) then
      SetLength(LPoints, LPointCount + 256);
    LPoints[LPointCount].X := AX;
    LPoints[LPointCount].Y := AY;
    LPoints[LPointCount].OnCurve := AOnCurve;
    Inc(LPointCount);
  end;

  procedure CloseContour;
  begin
    if LPointCount > 0 then
    begin
      if LContourCount >= Length(LContours) then
        SetLength(LContours, LContourCount + 16);
      LContours[LContourCount] := LPointCount - 1;
      Inc(LContourCount);
    end;
  end;

  function ReadNextByte: Byte;
  begin
    if LPos < LLen then
    begin
      Result := LData[LPos];
      Inc(LPos);
    end
    else
      Result := 14; { endchar }
  end;

  function SubrBias(ACount: Int32): Int32;
  begin
    if ACount < 1240 then
      Result := 107
    else if ACount < 33900 then
      Result := 1131
    else
      Result := 32768;
  end;

  procedure CallSubr(AIndex: Int32; AIsGlobal: Boolean);
  var
    LBias, LSubrIdx, LSubrCount: Int32;
  begin
    if LCallDepth >= MAX_CALL_DEPTH then Exit;
    if AIsGlobal then
      LSubrCount := Length(FCffGlobalSubrs)
    else
      LSubrCount := Length(FCffLocalSubrs);
    if LSubrCount = 0 then Exit;
    LBias := SubrBias(LSubrCount);
    LSubrIdx := AIndex + LBias;
    if (LSubrIdx < 0) or (LSubrIdx >= LSubrCount) then Exit;
    if AIsGlobal then
    begin
      if Length(FCffGlobalSubrs[LSubrIdx].Data) = 0 then Exit;
      LCallStack[LCallDepth].Data := LData;
      LCallStack[LCallDepth].Len := LLen;
      LCallStack[LCallDepth].Pos := LPos;
      LCallStack[LCallDepth].Watermark := LStackWatermark;
      Inc(LCallDepth);
      LData := @FCffGlobalSubrs[LSubrIdx].Data[0];
      LLen := Length(FCffGlobalSubrs[LSubrIdx].Data);
    end
    else
    begin
      if Length(FCffLocalSubrs[LSubrIdx].Data) = 0 then Exit;
      LCallStack[LCallDepth].Data := LData;
      LCallStack[LCallDepth].Len := LLen;
      LCallStack[LCallDepth].Pos := LPos;
      LCallStack[LCallDepth].Watermark := LStackWatermark;
      Inc(LCallDepth);
      LData := @FCffLocalSubrs[LSubrIdx].Data[0];
      LLen := Length(FCffLocalSubrs[LSubrIdx].Data);
    end;
    LStackWatermark := LStackTop;
    LPos := 0;
  end;

  procedure DoReturn;
  begin
    if LCallDepth > 0 then
    begin
      Dec(LCallDepth);
      LData := LCallStack[LCallDepth].Data;
      LLen := LCallStack[LCallDepth].Len;
      LPos := LCallStack[LCallDepth].Pos;
      LStackWatermark := LCallStack[LCallDepth].Watermark;
    end
    else
      LPos := LLen; { terminate }
  end;

  procedure HandleWidth;
  { If stack has odd number of values before first hint/moveto, first value is width }
  begin
    if LWidthParsed then Exit;
    LWidthParsed := True;
    if (LStackTop > 0) and ((LStackTop and 1) = 1) then
    begin
      LWidth := LStack[0] + FCffNominalWidthX;
      { Shift stack down }
      Move(LStack[1], LStack[0], (LStackTop - 1) * SizeOf(Int32));
      Dec(LStackTop);
    end
    else if (LStackTop > 0) and ((LStackTop and 1) = 0) then
    begin
      LWidth := FCffDefaultWidthX;
    end;
  end;

  procedure InterpretCharstring;
  var
    LB, LB2: Byte;
    LI, LVal: Int32;
    LArgs: array[0..MAX_STACK - 1] of Int32;
    LArgCount: Int32;
  begin
    while LPos <= LLen do
    begin
      LB := ReadNextByte;
      case LB of
        $0E: begin { endchar }
          CloseContour;
          LPos := LLen;
        end;
        { Hint operators — consume hint pairs above watermark only }
        $01: begin { hstem }
          HandleWidth;
          LStackTop := LStackWatermark;
        end;
        $03: begin { vstem }
          HandleWidth;
          LStackTop := LStackWatermark;
        end;
        $12: begin { hstemhm }
          HandleWidth;
          LStackTop := LStackWatermark;
        end;
        $17: begin { vstemhm }
          HandleWidth;
          LStackTop := LStackWatermark;
        end;
        $13: begin { hintmask }
          HandleWidth;
          { Skip hint mask bytes: ceil(hint_count / 8) }
          LI := LStackTop - LStackWatermark;
          if LI >= 2 then
          begin
            LI := ((LI div 2) + 7) div 8;
            while LI > 0 do begin ReadNextByte; Dec(LI); end;
          end;
          LStackTop := LStackWatermark;
        end;
        $14: begin { cntrmask }
          HandleWidth;
          LI := LStackTop - LStackWatermark;
          if LI >= 2 then
          begin
            LI := ((LI div 2) + 7) div 8;
            while LI > 0 do begin ReadNextByte; Dec(LI); end;
          end;
          LStackTop := LStackWatermark;
        end;
        $15: begin { rmoveto }
          HandleWidth;
          CloseContour;
          if LStackTop >= 2 then
          begin
            LX := LX + LStack[LStackTop - 2];
            LY := LY + LStack[LStackTop - 1];
            AddPoint(LX, LY, True);
            LHasMove := True;
          end;
          LStackTop := 0;
        end;
        $16: begin { hmoveto }
          HandleWidth;
          CloseContour;
          if LStackTop >= 1 then
          begin
            LX := LX + LStack[LStackTop - 1];
            AddPoint(LX, LY, True);
            LHasMove := True;
          end;
          LStackTop := 0;
        end;
        $04: begin { vmoveto }
          HandleWidth;
          CloseContour;
          if LStackTop >= 1 then
          begin
            LY := LY + LStack[LStackTop - 1];
            AddPoint(LX, LY, True);
            LHasMove := True;
          end;
          LStackTop := 0;
        end;
        $05: begin { rlineto }
          for LI := 0 to LStackTop - 1 do
          begin
            if LI and 1 = 0 then
              LX := LX + LStack[LI]
            else
            begin
              LY := LY + LStack[LI];
              AddPoint(LX, LY, True);
            end;
          end;
          LStackTop := 0;
        end;
        $06: begin { hlineto }
          for LI := 0 to LStackTop - 1 do
          begin
            if LI and 1 = 0 then
              LX := LX + LStack[LI]
            else
              LY := LY + LStack[LI];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $07: begin { vlineto }
          for LI := 0 to LStackTop - 1 do
          begin
            if LI and 1 = 0 then
              LY := LY + LStack[LI]
            else
              LX := LX + LStack[LI];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $08: begin { rrcurveto }
          { 6 args per curve: dx1 dy1 dx2 dy2 dx3 dy3 }
          for LI := 0 to (LStackTop div 6) - 1 do
          begin
            AddPoint(LX + LStack[LI * 6], LY + LStack[LI * 6 + 1], False);
            AddPoint(LX + LStack[LI * 6] + LStack[LI * 6 + 2],
                     LY + LStack[LI * 6 + 1] + LStack[LI * 6 + 3], False);
            LX := LX + LStack[LI * 6] + LStack[LI * 6 + 2] + LStack[LI * 6 + 4];
            LY := LY + LStack[LI * 6 + 1] + LStack[LI * 6 + 3] + LStack[LI * 6 + 5];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $1B: begin { hhcurveto }
          { Horizontal-horizontal curves.
            If odd arg count, first arg is dy1 for first curve only,
            followed by groups of 4: (dx2, dy2, dx3, dy).
            First curve: (0, dy1, dx2, dy2, dx3, dy) = 5 args from odd case + 4 from first group }
          LI := 0;
          if (LStackTop > 0) and ((LStackTop and 1) = 1) then
          begin
            { First curve has special dy1. Combined with first group of 4:
              (0, LStack[0], LStack[1], LStack[2], LStack[3], LStack[4]) }
            if LStackTop >= 6 then
            begin
              AddPoint(LX, LY + LStack[0], False);
              AddPoint(LX + LStack[1], LY + LStack[0] + LStack[2], False);
              LX := LX + LStack[1] + LStack[3];
              LY := LY + LStack[0] + LStack[2] + LStack[4];
              AddPoint(LX, LY, True);
            end;
            LI := 5;
          end;
          while LI + 3 < LStackTop do
          begin
            AddPoint(LX + LStack[LI], LY, False);
            AddPoint(LX + LStack[LI] + LStack[LI + 1], LY + LStack[LI + 2], False);
            LX := LX + LStack[LI] + LStack[LI + 1] + LStack[LI + 3];
            LY := LY + LStack[LI + 2];
            AddPoint(LX, LY, True);
            Inc(LI, 4);
          end;
          LStackTop := 0;
        end;
        $1A: begin { vvcurveto }
          { Vertical-vertical curves.
            If odd arg count, first arg is dx1 for first curve only. }
          LI := 0;
          if (LStackTop > 0) and ((LStackTop and 1) = 1) then
          begin
            if LStackTop >= 4 then
            begin
              AddPoint(LX + LStack[LI], LY, False);
              AddPoint(LX + LStack[LI] + LStack[LI + 1], LY + LStack[LI + 2], False);
              LX := LX + LStack[LI] + LStack[LI + 1];
              LY := LY + LStack[LI + 2] + LStack[LI + 3];
              AddPoint(LX, LY, True);
            end;
            LI := 4;
          end;
          while LI + 3 < LStackTop do
          begin
            AddPoint(LX, LY + LStack[LI], False);
            AddPoint(LX + LStack[LI + 1], LY + LStack[LI] + LStack[LI + 2], False);
            LX := LX + LStack[LI + 1];
            LY := LY + LStack[LI] + LStack[LI + 2] + LStack[LI + 3];
            AddPoint(LX, LY, True);
            Inc(LI, 4);
          end;
          LStackTop := 0;
        end;
        $18: begin { rcurveline }
          { N-1 curves (6 args each) + 1 line (2 args) }
          LI := 0;
          while LI + 6 <= LStackTop do
          begin
            AddPoint(LX + LStack[LI], LY + LStack[LI + 1], False);
            AddPoint(LX + LStack[LI] + LStack[LI + 2], LY + LStack[LI + 1] + LStack[LI + 3], False);
            LX := LX + LStack[LI] + LStack[LI + 2] + LStack[LI + 4];
            LY := LY + LStack[LI + 1] + LStack[LI + 3] + LStack[LI + 5];
            AddPoint(LX, LY, True);
            Inc(LI, 6);
          end;
          { Last 2 args: line }
          if LI + 2 <= LStackTop then
          begin
            LX := LX + LStack[LI];
            LY := LY + LStack[LI + 1];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $19: begin { rlinecurve }
          { N-1 lines (2 args each) + 1 curve (6 args) }
          LI := 0;
          while LI + 6 <= LStackTop do
          begin
            LX := LX + LStack[LI];
            LY := LY + LStack[LI + 1];
            AddPoint(LX, LY, True);
            Inc(LI, 2);
          end;
          { Last 6 args: curve }
          if LI + 6 <= LStackTop then
          begin
            AddPoint(LX + LStack[LI], LY + LStack[LI + 1], False);
            AddPoint(LX + LStack[LI] + LStack[LI + 2], LY + LStack[LI + 1] + LStack[LI + 3], False);
            LX := LX + LStack[LI] + LStack[LI + 2] + LStack[LI + 4];
            LY := LY + LStack[LI + 1] + LStack[LI + 3] + LStack[LI + 5];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $1E: begin { hvcurveto }
          { Alternating horizontal/vertical curves }
          LI := 0;
          while LI + 4 <= LStackTop do
          begin
            if (LStackTop - LI) >= 6 then
            begin
              { Horizontal: dx1 dx2 dy2 dy3 [dx3] }
              AddPoint(LX + LStack[LI], LY, False);
              AddPoint(LX + LStack[LI] + LStack[LI + 1], LY + LStack[LI + 2], False);
              LX := LX + LStack[LI] + LStack[LI + 1] + LStack[LI + 4];
              LY := LY + LStack[LI + 2] + LStack[LI + 3];
              AddPoint(LX, LY, True);
              Inc(LI, 5);
              if (LStackTop - LI) >= 5 then
              begin
                { Vertical: dy1 dx2 dy2 dx3 dx4 }
                AddPoint(LX, LY + LStack[LI], False);
                AddPoint(LX + LStack[LI + 1], LY + LStack[LI] + LStack[LI + 2], False);
                LX := LX + LStack[LI + 1] + LStack[LI + 3];
                LY := LY + LStack[LI] + LStack[LI + 2] + LStack[LI + 4];
                AddPoint(LX, LY, True);
                Inc(LI, 5);
              end;
            end
            else
              Break;
          end;
          LStackTop := 0;
        end;
        $1F: begin { vhcurveto }
          LI := 0;
          while LI + 4 <= LStackTop do
          begin
            if (LStackTop - LI) >= 6 then
            begin
              AddPoint(LX, LY + LStack[LI], False);
              AddPoint(LX + LStack[LI + 1], LY + LStack[LI] + LStack[LI + 2], False);
              LX := LX + LStack[LI + 1] + LStack[LI + 3];
              LY := LY + LStack[LI] + LStack[LI + 2] + LStack[LI + 4];
              AddPoint(LX, LY, True);
              Inc(LI, 5);
              if (LStackTop - LI) >= 5 then
              begin
                AddPoint(LX + LStack[LI], LY, False);
                AddPoint(LX + LStack[LI] + LStack[LI + 1], LY + LStack[LI + 2], False);
                LX := LX + LStack[LI] + LStack[LI + 1] + LStack[LI + 4];
                LY := LY + LStack[LI + 2] + LStack[LI + 3];
                AddPoint(LX, LY, True);
                Inc(LI, 5);
              end;
            end
            else
              Break;
          end;
          LStackTop := 0;
        end;
        $0A: begin { callsubr }
          if LStackTop > 0 then
          begin
            Dec(LStackTop);
            CallSubr(LStack[LStackTop], False);
          end;
        end;
        $1D: begin { callgsubr }
          if LStackTop > 0 then
          begin
            Dec(LStackTop);
            CallSubr(LStack[LStackTop], True);
          end;
        end;
        $0B: begin { return }
          DoReturn;
        end;
        $0C: begin { two-byte operator }
          LB2 := ReadNextByte;
          case LB2 of
            $22: begin { hflex }
              if LStackTop >= 7 then
              begin
                AddPoint(LX + LStack[0], LY, False);
                AddPoint(LX + LStack[0] + LStack[1], LY + LStack[2], False);
                LX := LX + LStack[0] + LStack[1]; LY := LY + LStack[2] + LStack[3];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[4], LY, False);
                AddPoint(LX + LStack[4] + LStack[5], LY + LStack[6], False);
                LX := LX + LStack[4] + LStack[5]; { dy=0 for last }
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $23: begin { flex }
              if LStackTop >= 13 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2] + LStack[4];
                LY := LY + LStack[1] + LStack[3] + LStack[5];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[6], LY + LStack[7], False);
                AddPoint(LX + LStack[6] + LStack[8], LY + LStack[7] + LStack[9], False);
                LX := LX + LStack[6] + LStack[8] + LStack[10];
                LY := LY + LStack[7] + LStack[9] + LStack[11];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $24: begin { hflex1 }
              if LStackTop >= 9 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2]; LY := LY + LStack[1] + LStack[3] + LStack[4];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[5], LY, False);
                AddPoint(LX + LStack[5] + LStack[6], LY + LStack[7], False);
                LX := LX + LStack[5] + LStack[6]; LY := LY + LStack[7] + LStack[8];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $25: begin { flex1 }
              if LStackTop >= 11 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2] + LStack[4];
                LY := LY + LStack[1] + LStack[3] + LStack[5];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[6], LY + LStack[7], False);
                AddPoint(LX + LStack[6] + LStack[8], LY + LStack[7] + LStack[9], False);
                LX := LX + LStack[6] + LStack[8] + LStack[10];
                LY := LY + LStack[7] + LStack[9];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
          else
            LStackTop := 0; { unknown 2-byte op, clear stack }
          end;
        end;
        $1C: begin { shortint }
          LVal := SmallInt((ReadNextByte shl 8) or ReadNextByte);
          Push(LVal);
        end;
        $FF: begin { fixed (4-byte signed) }
          LVal := Int32((ReadNextByte shl 24) or (ReadNextByte shl 16) or
            (ReadNextByte shl 8) or ReadNextByte);
          Push(LVal);
        end;
      else
        begin
          { Number encoding }
          if (LB >= 32) and (LB <= 246) then
            Push(LB - 139)
          else if (LB >= 247) and (LB <= 250) then
            Push((LB - 247) * 256 + ReadNextByte + 108)
          else if (LB >= 251) and (LB <= 254) then
            Push(-((LB - 251) * 256) - ReadNextByte - 108)
          else if LB = 28 then
            Push(SmallInt((ReadNextByte shl 8) or ReadNextByte))
          else if LB = 29 then
            Push(Int32((ReadNextByte shl 24) or (ReadNextByte shl 16) or
              (ReadNextByte shl 8) or ReadNextByte));
        end;
      end;
      if LPos >= LLen then
      begin
        if LCallDepth > 0 then
          DoReturn
        else
          Break;
      end;
    end;
  end;

var
  LI: Int32;
begin
  Result := Default(TFontGlyphOutline);
  FontGlyphOutlineClear(Result);
  if (not FCffParsed) or (AGlyphIndex >= UInt32(FCffGlyphCount)) then
    Exit;

  LCharStrBase := Int32(FCffCharStringOffsets[AGlyphIndex]);
  LCharStrLen := Int32(FCffCharStringOffsets[AGlyphIndex + 1]) - LCharStrBase;
  if LCharStrLen <= 0 then Exit;

  { Initialize interpreter state }
  LStackTop := 0;
  LCallDepth := 0;
  LData := @FData[LCharStrBase];
  LLen := LCharStrLen;
  LPos := 0;
  LX := 0; LY := 0;
  LPointCount := 0;
  LContourCount := 0;
  LHasMove := False;
  LWidthParsed := False;
  LStackWatermark := 0;
  LWidth := FCffDefaultWidthX;
  SetLength(LPoints, 0);
  SetLength(LContours, 0);

  InterpretCharstring;
  CloseContour;

  { Build result }
  if LPointCount > 0 then
  begin
    SetLength(Result.Points, LPointCount);
    for LI := 0 to LPointCount - 1 do
      Result.Points[LI] := LPoints[LI];

    SetLength(Result.ContourEnds, LContourCount);
    for LI := 0 to LContourCount - 1 do
      Result.ContourEnds[LI] := LContours[LI];

    Result.ContourCount := LContourCount;

    { Compute bounding box }
    Result.XMin := High(Int16);
    Result.YMin := High(Int16);
    Result.XMax := Low(Int16);
    Result.YMax := Low(Int16);
    for LI := 0 to LPointCount - 1 do
    begin
      if Result.Points[LI].X < Result.XMin then
        Result.XMin := Result.Points[LI].X;
      if Result.Points[LI].Y < Result.YMin then
        Result.YMin := Result.Points[LI].Y;
      if Result.Points[LI].X > Result.XMax then
        Result.XMax := Result.Points[LI].X;
      if Result.Points[LI].Y > Result.YMax then
        Result.YMax := Result.Points[LI].Y;
    end;
  end;
end;

{ -- CFF2 parsing -- }

procedure TTFontFace.ParseCff2;

  procedure ReadCff2Index(ABase: Int32; out ACount: Int32;
    out AOffsets: array of UInt32; out ADataStart: Int32);
  var
    LOffSize, I, J: Int32;
    LOff: UInt32;
  begin
    ACount := 0;
    ADataStart := ABase + 4;
    if FDataLength < ABase + 4 then Exit;
    ACount := Int32(ReadUInt32BE(ABase));
    if ACount = 0 then
    begin
      ADataStart := ABase + 4;
      Exit;
    end;
    if FDataLength < ABase + 5 then begin ACount := 0; Exit; end;
    LOffSize := ReadUInt8(ABase + 4);
    if (LOffSize < 1) or (LOffSize > 4) then begin ACount := 0; Exit; end;
    if FDataLength < ABase + 5 + (ACount + 1) * LOffSize then
    begin
      ACount := 0;
      Exit;
    end;
    for I := 0 to ACount do
    begin
      LOff := 0;
      for J := 0 to LOffSize - 1 do
        LOff := (LOff shl 8) or ReadUInt8(ABase + 5 + I * LOffSize + J);
      AOffsets[I] := LOff;
    end;
    ADataStart := ABase + 5 + (ACount + 1) * LOffSize;
  end;

var
  LIdx, LBase, LTopDictSize, LHdrSize: Int32;
  LI, LJ: Int32;
  LItemBase: Int32;
  LCharStringsOff, LFontDictOff, LFDSelectOff, LVStoreOff: Int32;
  LPrivateSize, LPrivateOff, LSubrsOff: Int32;
  LArr: array of UInt32;
  LFDCount, LFDIdx: Int32;
  LTopI, LTopOp: Int32;
  LTopStack: array of Int32;
  LTopNumOps: Int32;
  LB: Byte;
  LVal: Int32;
  LPrivateArr: array of Int32;
  LPrivNumOps: Int32;
  LDataCount, LDataOff, LDataBase: Int32;
  LItemCount, LWordDeltaCount, LRegionIdxCount: Int32;
  LLongWords, LDeltaOffset: Int32;
begin
  FCff2Parsed := False;
  FCff2GlyphCount := 0;
  SetLength(FCff2CharStringOffsets, 0);
  SetLength(FCff2GlobalSubrs, 0);
  SetLength(FCff2LocalSubrs, 0);
  FCff2FDCount := 0;
  FCff2VStoreParsed := False;
  FCff2AxisCount := 0;
  FCff2RegionCount := 0;
  SetLength(FCff2Regions, 0);

  LIdx := FindTable(TABLE_TAG_CFF2);
  if LIdx < 0 then Exit;
  LBase := Int32(FTables[LIdx].Offset);
  if Int32(FTables[LIdx].Length) < 5 then Exit;
  if FDataLength < LBase + 5 then Exit;

  FCff2TableBase := LBase;
  LHdrSize := ReadUInt8(LBase + 2);
  LTopDictSize := ReadUInt16BE(LBase + 3);
  if LHdrSize <> 5 then Exit;
  if Int32(FTables[LIdx].Length) < LHdrSize + LTopDictSize then Exit;

  SetLength(LArr, 65536);
  SetLength(LTopStack, 48);
  LCharStringsOff := -1;
  LFontDictOff := -1;
  LFDSelectOff := -1;
  LVStoreOff := -1;
  LTopNumOps := 0;

  { Parse Top DICT }
  LTopI := LBase + LHdrSize;
  while LTopI < LBase + LHdrSize + LTopDictSize do
  begin
    LB := ReadUInt8(LTopI);
    if LB <= 27 then
    begin
      if LB = 12 then
      begin
        if LTopI + 1 >= LBase + LHdrSize + LTopDictSize then Break;
        LTopOp := (LB shl 8) or ReadUInt8(LTopI + 1);
        Inc(LTopI, 2);
      end
      else
      begin
        LTopOp := LB;
        Inc(LTopI);
      end;
      case LTopOp of
        $11: { CharStrings }
          if LTopNumOps >= 1 then
            LCharStringsOff := LTopStack[LTopNumOps - 1];
        $18: { vstore }
          if LTopNumOps >= 1 then
            LVStoreOff := LTopStack[LTopNumOps - 1];
        $0C24: { FontDICT INDEX }
          if LTopNumOps >= 1 then
            LFontDictOff := LTopStack[LTopNumOps - 1];
        $0C25: { FDSelect }
          if LTopNumOps >= 1 then
            LFDSelectOff := LTopStack[LTopNumOps - 1];
      end;
      LTopNumOps := 0;
    end
    else if LB = 28 then
    begin
      LVal := SmallInt((ReadUInt8(LTopI + 1) shl 8) or ReadUInt8(LTopI + 2));
      if LTopNumOps < Length(LTopStack) then
      begin
        LTopStack[LTopNumOps] := LVal;
        Inc(LTopNumOps);
      end;
      Inc(LTopI, 3);
    end
    else if LB = 29 then
    begin
      LVal := Int32((ReadUInt8(LTopI + 1) shl 24) or (ReadUInt8(LTopI + 2) shl 16) or
        (ReadUInt8(LTopI + 3) shl 8) or ReadUInt8(LTopI + 4));
      if LTopNumOps < Length(LTopStack) then
      begin
        LTopStack[LTopNumOps] := LVal;
        Inc(LTopNumOps);
      end;
      Inc(LTopI, 5);
    end
    else if (LB >= 32) and (LB <= 246) then
    begin
      if LTopNumOps < Length(LTopStack) then
      begin
        LTopStack[LTopNumOps] := LB - 139;
        Inc(LTopNumOps);
      end;
      Inc(LTopI);
    end
    else if (LB >= 247) and (LB <= 250) then
    begin
      LVal := (LB - 247) * 256 + ReadUInt8(LTopI + 1) + 108;
      if LTopNumOps < Length(LTopStack) then
      begin
        LTopStack[LTopNumOps] := LVal;
        Inc(LTopNumOps);
      end;
      Inc(LTopI, 2);
    end
    else if (LB >= 251) and (LB <= 254) then
    begin
      LVal := -((LB - 251) * 256) - ReadUInt8(LTopI + 1) - 108;
      if LTopNumOps < Length(LTopStack) then
      begin
        LTopStack[LTopNumOps] := LVal;
        Inc(LTopNumOps);
      end;
      Inc(LTopI, 2);
    end
    else
      Inc(LTopI);
  end;

  if LCharStringsOff < 0 then Exit;

  { CharStrings INDEX (CFF2: 4-byte count) }
  LCharStringsOff := LCharStringsOff + LBase;
  ReadCff2Index(LCharStringsOff, FCff2GlyphCount, LArr, LItemBase);
  if FCff2GlyphCount <= 0 then begin FCff2GlyphCount := 0; Exit; end;
  SetLength(FCff2CharStringOffsets, FCff2GlyphCount + 1);
  for LI := 0 to FCff2GlyphCount do
    FCff2CharStringOffsets[LI] := UInt32(LItemBase) + LArr[LI] - 1;
  FCff2CharStringsBase := LItemBase;

  { Global Subrs INDEX (right after Top DICT) }
  LItemBase := LBase + LHdrSize + LTopDictSize;
  ReadCff2Index(LItemBase, LI, LArr, LJ);
  SetLength(FCff2GlobalSubrs, LI);
  for LIdx := 0 to LI - 1 do
    FCff2GlobalSubrs[LIdx].Data := Copy(FData,
      LJ + Int32(LArr[LIdx]) - 1,
      Int32(LArr[LIdx + 1]) - Int32(LArr[LIdx]));

  { FontDICT INDEX → Private DICT → Local Subrs }
  SetLength(FCff2LocalSubrs, 0);
  if LFontDictOff >= 0 then
  begin
    LFontDictOff := LFontDictOff + LBase;
    ReadCff2Index(LFontDictOff, LFDCount, LArr, LItemBase);
    FCff2FDCount := LFDCount;
    { 只解析第一个 Font DICT (index 0) 的 Private DICT }
    if LFDCount > 0 then
    begin
      LPrivateSize := 0;
      LPrivateOff := -1;
      LSubrsOff := -1;
      { Parse Font DICT for Private DICT operator }
      LJ := LItemBase + Int32(LArr[0]) - 1;
      LPrivNumOps := 0;
      SetLength(LPrivateArr, 16);
      while LJ < LItemBase + Int32(LArr[1]) - 1 do
      begin
        LB := ReadUInt8(LJ);
        if LB <= 27 then
        begin
          if LB = 12 then
          begin
            Inc(LJ);
            if LJ >= LItemBase + Int32(LArr[1]) - 1 then Break;
            Inc(LJ);
          end
          else
          begin
            if LB = $12 then { Private DICT: size + offset }
              if LPrivNumOps >= 2 then
              begin
                LPrivateSize := LPrivateArr[LPrivNumOps - 2];
                LPrivateOff := LPrivateArr[LPrivNumOps - 1];
              end;
            Inc(LJ);
          end;
          LPrivNumOps := 0;
        end
        else if LB = 28 then
        begin
          LVal := SmallInt((ReadUInt8(LJ + 1) shl 8) or ReadUInt8(LJ + 2));
          if LPrivNumOps < Length(LPrivateArr) then
          begin
            LPrivateArr[LPrivNumOps] := LVal;
            Inc(LPrivNumOps);
          end;
          Inc(LJ, 3);
        end
        else if (LB >= 32) and (LB <= 246) then
        begin
          if LPrivNumOps < Length(LPrivateArr) then
          begin
            LPrivateArr[LPrivNumOps] := LB - 139;
            Inc(LPrivNumOps);
          end;
          Inc(LJ);
        end
        else if (LB >= 247) and (LB <= 250) then
        begin
          LVal := (LB - 247) * 256 + ReadUInt8(LJ + 1) + 108;
          if LPrivNumOps < Length(LPrivateArr) then
          begin
            LPrivateArr[LPrivNumOps] := LVal;
            Inc(LPrivNumOps);
          end;
          Inc(LJ, 2);
        end
        else if (LB >= 251) and (LB <= 254) then
        begin
          LVal := -((LB - 251) * 256) - ReadUInt8(LJ + 1) - 108;
          if LPrivNumOps < Length(LPrivateArr) then
          begin
            LPrivateArr[LPrivNumOps] := LVal;
            Inc(LPrivNumOps);
          end;
          Inc(LJ, 2);
        end
        else
          Inc(LJ);
      end;
      { Parse Private DICT for Subrs offset }
      if (LPrivateOff >= 0) and (LPrivateSize > 0) then
      begin
        LPrivateOff := LPrivateOff + LBase;
        LJ := LPrivateOff;
        LPrivNumOps := 0;
        while LJ < LPrivateOff + LPrivateSize do
        begin
          LB := ReadUInt8(LJ);
          if LB <= 27 then
          begin
            if LB = 12 then
            begin
              if LJ + 1 >= LPrivateOff + LPrivateSize then Break;
              Inc(LJ, 2);
            end
            else
            begin
              if LB = $13 then { Subrs }
                if LPrivNumOps >= 1 then
                  LSubrsOff := LPrivateArr[LPrivNumOps - 1];
              Inc(LJ);
            end;
            LPrivNumOps := 0;
          end
          else if LB = 28 then
          begin
            LVal := SmallInt((ReadUInt8(LJ + 1) shl 8) or ReadUInt8(LJ + 2));
            if LPrivNumOps < Length(LPrivateArr) then
            begin
              LPrivateArr[LPrivNumOps] := LVal;
              Inc(LPrivNumOps);
            end;
            Inc(LJ, 3);
          end
          else if (LB >= 32) and (LB <= 246) then
          begin
            if LPrivNumOps < Length(LPrivateArr) then
            begin
              LPrivateArr[LPrivNumOps] := LB - 139;
              Inc(LPrivNumOps);
            end;
            Inc(LJ);
          end
          else if (LB >= 247) and (LB <= 250) then
          begin
            LVal := (LB - 247) * 256 + ReadUInt8(LJ + 1) + 108;
            if LPrivNumOps < Length(LPrivateArr) then
            begin
              LPrivateArr[LPrivNumOps] := LVal;
              Inc(LPrivNumOps);
            end;
            Inc(LJ, 2);
          end
          else if (LB >= 251) and (LB <= 254) then
          begin
            LVal := -((LB - 251) * 256) - ReadUInt8(LJ + 1) - 108;
            if LPrivNumOps < Length(LPrivateArr) then
            begin
              LPrivateArr[LPrivNumOps] := LVal;
              Inc(LPrivNumOps);
            end;
            Inc(LJ, 2);
          end
          else
            Inc(LJ);
        end;
        { Read Local Subrs INDEX }
        if LSubrsOff >= 0 then
        begin
          LItemBase := LPrivateOff + LSubrsOff;
          ReadCff2Index(LItemBase, LI, LArr, LJ);
          SetLength(FCff2LocalSubrs, LI);
          for LIdx := 0 to LI - 1 do
            FCff2LocalSubrs[LIdx].Data := Copy(FData,
              LJ + Int32(LArr[LIdx]) - 1,
              Int32(LArr[LIdx + 1]) - Int32(LArr[LIdx]));
        end;
      end;
    end;
  end;

  { Parse ItemVariationStore if present }
  if LVStoreOff >= 0 then
  begin
    LItemBase := LVStoreOff + LBase;
    if FDataLength >= LItemBase + 8 then
    begin
      { format (2) + variationRegionListOffset (4) + itemVariationDataCount (2) }
      LJ := LItemBase + ReadUInt32BE(LItemBase + 2); { variationRegionListOffset relative to vstore start }
      if FDataLength >= LJ + 4 then
      begin
        FCff2AxisCount := ReadUInt16BE(LJ);
        FCff2RegionCount := ReadUInt16BE(LJ + 2);
        if (FCff2AxisCount > 0) and (FCff2RegionCount > 0) then
        begin
          SetLength(FCff2Regions, FCff2RegionCount);
          LI := LJ + 4; { first VariationRegion }
          for LIdx := 0 to FCff2RegionCount - 1 do
          begin
            SetLength(FCff2Regions[LIdx].Axes, FCff2AxisCount);
            for LJ := 0 to FCff2AxisCount - 1 do
            begin
              FCff2Regions[LIdx].Axes[LJ].Start := Int16(ReadUInt16BE(LI));
              FCff2Regions[LIdx].Axes[LJ].Peak  := Int16(ReadUInt16BE(LI + 2));
              FCff2Regions[LIdx].Axes[LJ].EndCoord := Int16(ReadUInt16BE(LI + 4));
              Inc(LI, 6);
            end;
          end;
          FCff2VStoreParsed := True;
          { Parse ItemVariationData subtables }
          LDataCount := ReadUInt16BE(LItemBase + 6);
          if (LDataCount > 0) and (LDataCount <= 256) then
          begin
            FCff2VStoreDataCount := LDataCount;
            SetLength(FCff2VStoreDataSubtables, LDataCount);
            for LIdx := 0 to LDataCount - 1 do
            begin
              if LItemBase + 8 + LIdx * 4 + 4 > FDataLength then Break;
              LDataOff := ReadUInt32BE(LItemBase + 8 + LIdx * 4);
              LDataBase := LItemBase + LDataOff;
              if LDataBase + 6 > FDataLength then Continue;
              LItemCount := ReadUInt16BE(LDataBase);
              LWordDeltaCount := ReadUInt16BE(LDataBase + 2);
              LRegionIdxCount := ReadUInt16BE(LDataBase + 4);
              FCff2VStoreDataSubtables[LIdx].ItemCount := LItemCount;
              FCff2VStoreDataSubtables[LIdx].RegionIndexCount := LRegionIdxCount;
              SetLength(FCff2VStoreDataSubtables[LIdx].RegionIndices, LRegionIdxCount);
              { Read region indices }
              for LJ := 0 to LRegionIdxCount - 1 do
              begin
                if LDataBase + 6 + LJ * 2 + 2 > FDataLength then Break;
                FCff2VStoreDataSubtables[LIdx].RegionIndices[LJ] :=
                  ReadUInt16BE(LDataBase + 6 + LJ * 2);
              end;
              { Read deltas }
              LLongWords := (LWordDeltaCount and $8000) shr 15;
              LWordDeltaCount := LWordDeltaCount and $7FFF;
              LDeltaOffset := LDataBase + 6 + LRegionIdxCount * 2;
              SetLength(FCff2VStoreDataSubtables[LIdx].Deltas,
                LItemCount * LRegionIdxCount);
              for LJ := 0 to LItemCount * LRegionIdxCount - 1 do
              begin
                if LJ div LRegionIdxCount < LWordDeltaCount then
                begin
                  if LLongWords <> 0 then
                  begin
                    if LDeltaOffset + 4 > FDataLength then Break;
                    FCff2VStoreDataSubtables[LIdx].Deltas[LJ] :=
                      Int16(ReadUInt16BE(LDeltaOffset)); { truncate 32→16 }
                    Inc(LDeltaOffset, 4);
                  end
                  else
                  begin
                    if LDeltaOffset + 2 > FDataLength then Break;
                    FCff2VStoreDataSubtables[LIdx].Deltas[LJ] :=
                      ReadInt16BE(LDeltaOffset);
                    Inc(LDeltaOffset, 2);
                  end;
                end
                else
                begin
                  if LLongWords <> 0 then
                  begin
                    if LDeltaOffset + 2 > FDataLength then Break;
                    FCff2VStoreDataSubtables[LIdx].Deltas[LJ] :=
                      ReadInt16BE(LDeltaOffset);
                    Inc(LDeltaOffset, 2);
                  end
                  else
                  begin
                    if LDeltaOffset + 1 > FDataLength then Break;
                    FCff2VStoreDataSubtables[LIdx].Deltas[LJ] :=
                      ShortInt(ReadUInt8(LDeltaOffset));
                    Inc(LDeltaOffset);
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  FCff2Parsed := True;
end;

function TTFontFace.Cff2GlyphOutline(AGlyphIndex: UInt32): TFontGlyphOutline;
{ CFF2 charstring interpreter → outline. 与 CffGlyphOutline 相同的 Type 2 算子集，
  但无 width 解析、无 endchar、无 seac。 }
const
  MAX_STACK = 48;
  MAX_CALL_DEPTH = 32;
var
  LCharStrBase, LCharStrLen: Int32;
  LStack: array[0..MAX_STACK - 1] of Int32;
  LStackTop: Int32;
  LCallStack: array[0..MAX_CALL_DEPTH - 1] of record
    Data: PByte; Len, Pos, Watermark: Int32;
  end;
  LCallDepth: Int32;
  LData: PByte;
  LLen, LPos: Int32;
  LX, LY: Int32;
  LPoints: TFontContourPointArray;
  LContours: array of UInt16;
  LPointCount, LContourCount: Int32;
  LStackWatermark: Int32;
  LVsIndex: Int32;  { CFF2 variation data subtable index for blend }

  procedure Push(AVal: Int32);
  begin
    if LStackTop < MAX_STACK then begin LStack[LStackTop] := AVal; Inc(LStackTop); end;
  end;

  function Pop: Int32;
  begin
    if LStackTop > 0 then begin Dec(LStackTop); Result := LStack[LStackTop]; end
    else Result := 0;
  end;

  procedure AddPoint(AX, AY: Int32; AOnCurve: Boolean);
  begin
    if LPointCount >= Length(LPoints) then SetLength(LPoints, LPointCount + 256);
    LPoints[LPointCount].X := AX;
    LPoints[LPointCount].Y := AY;
    LPoints[LPointCount].OnCurve := AOnCurve;
    Inc(LPointCount);
  end;

  procedure CloseContour;
  begin
    if LPointCount > 0 then
    begin
      if LContourCount >= Length(LContours) then SetLength(LContours, LContourCount + 16);
      LContours[LContourCount] := LPointCount - 1;
      Inc(LContourCount);
    end;
  end;

  function ReadNextByte: Byte;
  begin
    if LPos < LLen then begin Result := LData[LPos]; Inc(LPos); end
    else Result := 0; { EOF sentinel — no endchar in CFF2 }
  end;

  function SubrBias(ACount: Int32): Int32;
  begin
    if ACount < 1240 then Result := 107
    else if ACount < 33900 then Result := 1131
    else Result := 32768;
  end;

  procedure CallSubr(AIndex: Int32; AIsGlobal: Boolean);
  var LBias, LSubrIdx, LSubrCount: Int32;
  begin
    if LCallDepth >= MAX_CALL_DEPTH then Exit;
    if AIsGlobal then LSubrCount := Length(FCff2GlobalSubrs)
    else LSubrCount := Length(FCff2LocalSubrs);
    if LSubrCount = 0 then Exit;
    LBias := SubrBias(LSubrCount);
    LSubrIdx := AIndex + LBias;
    if (LSubrIdx < 0) or (LSubrIdx >= LSubrCount) then Exit;
    if AIsGlobal then
    begin
      if Length(FCff2GlobalSubrs[LSubrIdx].Data) = 0 then Exit;
      LCallStack[LCallDepth].Data := LData;
      LCallStack[LCallDepth].Len := LLen;
      LCallStack[LCallDepth].Pos := LPos;
      LCallStack[LCallDepth].Watermark := LStackWatermark;
      Inc(LCallDepth);
      LData := @FCff2GlobalSubrs[LSubrIdx].Data[0];
      LLen := Length(FCff2GlobalSubrs[LSubrIdx].Data);
    end
    else
    begin
      if Length(FCff2LocalSubrs[LSubrIdx].Data) = 0 then Exit;
      LCallStack[LCallDepth].Data := LData;
      LCallStack[LCallDepth].Len := LLen;
      LCallStack[LCallDepth].Pos := LPos;
      LCallStack[LCallDepth].Watermark := LStackWatermark;
      Inc(LCallDepth);
      LData := @FCff2LocalSubrs[LSubrIdx].Data[0];
      LLen := Length(FCff2LocalSubrs[LSubrIdx].Data);
    end;
    LStackWatermark := LStackTop;
    LPos := 0;
  end;

  procedure DoReturn;
  begin
    if LCallDepth > 0 then
    begin
      Dec(LCallDepth);
      LData := LCallStack[LCallDepth].Data;
      LLen := LCallStack[LCallDepth].Len;
      LPos := LCallStack[LCallDepth].Pos;
      LStackWatermark := LCallStack[LCallDepth].Watermark;
    end
    else
      LPos := LLen;
  end;

  procedure InterpretCharstring;
  var LB, LB2: Byte; LI, LVal: Int32;
      LBlendN, LBlendR, LBlendI, LBlendJ: Int32;
      LBlendScalar: Single; LBlendDelta: Int32;
  begin
    while LPos <= LLen do
    begin
      LB := ReadNextByte;
      case LB of
        { CFF2 无 endchar (0x0E) — 忽略 }
        $0E: ;
        { Hint operators }
        $01, $03, $12, $17: { hstem, vstem, hstemhm, vstemhm }
          LStackTop := LStackWatermark;
        $13, $14: begin { hintmask, cntrmask }
          LI := LStackTop - LStackWatermark;
          if LI >= 2 then begin LI := ((LI div 2) + 7) div 8;
            while LI > 0 do begin ReadNextByte; Dec(LI); end; end;
          LStackTop := LStackWatermark;
        end;
        $15: begin { rmoveto }
          CloseContour;
          if LStackTop >= 2 then begin LX := LX + LStack[LStackTop - 2];
            LY := LY + LStack[LStackTop - 1]; AddPoint(LX, LY, True); end;
          LStackTop := 0;
        end;
        $16: begin { hmoveto }
          CloseContour;
          if LStackTop >= 1 then begin LX := LX + LStack[LStackTop - 1];
            AddPoint(LX, LY, True); end;
          LStackTop := 0;
        end;
        $04: begin { vmoveto }
          CloseContour;
          if LStackTop >= 1 then begin LY := LY + LStack[LStackTop - 1];
            AddPoint(LX, LY, True); end;
          LStackTop := 0;
        end;
        $05: begin { rlineto }
          for LI := 0 to LStackTop - 1 do
            if LI and 1 = 0 then LX := LX + LStack[LI]
            else begin LY := LY + LStack[LI]; AddPoint(LX, LY, True); end;
          LStackTop := 0;
        end;
        $06: begin { hlineto }
          for LI := 0 to LStackTop - 1 do
          begin
            if LI and 1 = 0 then LX := LX + LStack[LI]
            else LY := LY + LStack[LI];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $07: begin { vlineto }
          for LI := 0 to LStackTop - 1 do
          begin
            if LI and 1 = 0 then LY := LY + LStack[LI]
            else LX := LX + LStack[LI];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $08: begin { rrcurveto }
          for LI := 0 to (LStackTop div 6) - 1 do
          begin
            AddPoint(LX + LStack[LI*6], LY + LStack[LI*6+1], False);
            AddPoint(LX + LStack[LI*6] + LStack[LI*6+2], LY + LStack[LI*6+1] + LStack[LI*6+3], False);
            LX := LX + LStack[LI*6] + LStack[LI*6+2] + LStack[LI*6+4];
            LY := LY + LStack[LI*6+1] + LStack[LI*6+3] + LStack[LI*6+5];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $1B: begin { hhcurveto }
          LI := 0;
          if (LStackTop > 0) and ((LStackTop and 1) = 1) then
          begin
            if LStackTop >= 6 then
            begin
              AddPoint(LX, LY + LStack[0], False);
              AddPoint(LX + LStack[1], LY + LStack[0] + LStack[2], False);
              LX := LX + LStack[1] + LStack[3]; LY := LY + LStack[0] + LStack[2] + LStack[4];
              AddPoint(LX, LY, True);
            end;
            LI := 5;
          end;
          while LI + 3 < LStackTop do
          begin
            AddPoint(LX + LStack[LI], LY, False);
            AddPoint(LX + LStack[LI] + LStack[LI+1], LY + LStack[LI+2], False);
            LX := LX + LStack[LI] + LStack[LI+1] + LStack[LI+3];
            LY := LY + LStack[LI+2];
            AddPoint(LX, LY, True);
            Inc(LI, 4);
          end;
          LStackTop := 0;
        end;
        $1A: begin { vvcurveto }
          LI := 0;
          if (LStackTop > 0) and ((LStackTop and 1) = 1) then
          begin
            if LStackTop >= 4 then
            begin
              AddPoint(LX + LStack[0], LY, False);
              AddPoint(LX + LStack[0] + LStack[1], LY + LStack[2], False);
              LX := LX + LStack[0] + LStack[1]; LY := LY + LStack[2] + LStack[3];
              AddPoint(LX, LY, True);
            end;
            LI := 4;
          end;
          while LI + 3 < LStackTop do
          begin
            AddPoint(LX, LY + LStack[LI], False);
            AddPoint(LX + LStack[LI+1], LY + LStack[LI] + LStack[LI+2], False);
            LX := LX + LStack[LI+1]; LY := LY + LStack[LI] + LStack[LI+2] + LStack[LI+3];
            AddPoint(LX, LY, True);
            Inc(LI, 4);
          end;
          LStackTop := 0;
        end;
        $18: begin { rcurveline }
          LI := 0;
          while LI + 6 <= LStackTop do
          begin
            AddPoint(LX + LStack[LI], LY + LStack[LI+1], False);
            AddPoint(LX + LStack[LI] + LStack[LI+2], LY + LStack[LI+1] + LStack[LI+3], False);
            LX := LX + LStack[LI] + LStack[LI+2] + LStack[LI+4];
            LY := LY + LStack[LI+1] + LStack[LI+3] + LStack[LI+5];
            AddPoint(LX, LY, True);
            Inc(LI, 6);
          end;
          if LI + 2 <= LStackTop then begin LX := LX + LStack[LI];
            LY := LY + LStack[LI+1]; AddPoint(LX, LY, True); end;
          LStackTop := 0;
        end;
        $19: begin { rlinecurve }
          LI := 0;
          while LI + 6 <= LStackTop do
          begin LX := LX + LStack[LI]; LY := LY + LStack[LI+1];
            AddPoint(LX, LY, True); Inc(LI, 2); end;
          if LI + 6 <= LStackTop then
          begin
            AddPoint(LX + LStack[LI], LY + LStack[LI+1], False);
            AddPoint(LX + LStack[LI] + LStack[LI+2], LY + LStack[LI+1] + LStack[LI+3], False);
            LX := LX + LStack[LI] + LStack[LI+2] + LStack[LI+4];
            LY := LY + LStack[LI+1] + LStack[LI+3] + LStack[LI+5];
            AddPoint(LX, LY, True);
          end;
          LStackTop := 0;
        end;
        $1E: begin { hvcurveto }
          LI := 0;
          while LI + 4 <= LStackTop do
          begin
            if (LStackTop - LI) >= 6 then
            begin
              AddPoint(LX + LStack[LI], LY, False);
              AddPoint(LX + LStack[LI] + LStack[LI+1], LY + LStack[LI+2], False);
              LX := LX + LStack[LI] + LStack[LI+1] + LStack[LI+4];
              LY := LY + LStack[LI+2] + LStack[LI+3];
              AddPoint(LX, LY, True);
              Inc(LI, 5);
              if (LStackTop - LI) >= 5 then
              begin
                AddPoint(LX, LY + LStack[LI], False);
                AddPoint(LX + LStack[LI+1], LY + LStack[LI] + LStack[LI+2], False);
                LX := LX + LStack[LI+1] + LStack[LI+3];
                LY := LY + LStack[LI] + LStack[LI+2] + LStack[LI+4];
                AddPoint(LX, LY, True);
                Inc(LI, 5);
              end;
            end else Break;
          end;
          LStackTop := 0;
        end;
        $1F: begin { vhcurveto }
          LI := 0;
          while LI + 4 <= LStackTop do
          begin
            if (LStackTop - LI) >= 6 then
            begin
              AddPoint(LX, LY + LStack[LI], False);
              AddPoint(LX + LStack[LI+1], LY + LStack[LI] + LStack[LI+2], False);
              LX := LX + LStack[LI+1] + LStack[LI+3];
              LY := LY + LStack[LI] + LStack[LI+2] + LStack[LI+4];
              AddPoint(LX, LY, True);
              Inc(LI, 5);
              if (LStackTop - LI) >= 5 then
              begin
                AddPoint(LX + LStack[LI], LY, False);
                AddPoint(LX + LStack[LI] + LStack[LI+1], LY + LStack[LI+2], False);
                LX := LX + LStack[LI] + LStack[LI+1] + LStack[LI+4];
                LY := LY + LStack[LI+2] + LStack[LI+3];
                AddPoint(LX, LY, True);
                Inc(LI, 5);
              end;
            end else Break;
          end;
          LStackTop := 0;
        end;
        $0A: begin { callsubr }
          if LStackTop > 0 then begin Dec(LStackTop); CallSubr(LStack[LStackTop], False); end;
        end;
        $1D: begin { callgsubr }
          if LStackTop > 0 then begin Dec(LStackTop); CallSubr(LStack[LStackTop], True); end;
        end;
        $0B: DoReturn;
        $0C: begin { two-byte operator }
          LB2 := ReadNextByte;
          case LB2 of
            $22: begin { hflex }
              if LStackTop >= 7 then
              begin
                AddPoint(LX + LStack[0], LY, False);
                AddPoint(LX + LStack[0] + LStack[1], LY + LStack[2], False);
                LX := LX + LStack[0] + LStack[1]; LY := LY + LStack[2] + LStack[3];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[4], LY, False);
                AddPoint(LX + LStack[4] + LStack[5], LY + LStack[6], False);
                LX := LX + LStack[4] + LStack[5];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $23: begin { flex }
              if LStackTop >= 13 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2] + LStack[4];
                LY := LY + LStack[1] + LStack[3] + LStack[5];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[6], LY + LStack[7], False);
                AddPoint(LX + LStack[6] + LStack[8], LY + LStack[7] + LStack[9], False);
                LX := LX + LStack[6] + LStack[8] + LStack[10];
                LY := LY + LStack[7] + LStack[9] + LStack[11];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $24: begin { hflex1 }
              if LStackTop >= 9 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2]; LY := LY + LStack[1] + LStack[3] + LStack[4];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[5], LY, False);
                AddPoint(LX + LStack[5] + LStack[6], LY + LStack[7], False);
                LX := LX + LStack[5] + LStack[6]; LY := LY + LStack[7] + LStack[8];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
            $25: begin { flex1 }
              if LStackTop >= 11 then
              begin
                AddPoint(LX + LStack[0], LY + LStack[1], False);
                AddPoint(LX + LStack[0] + LStack[2], LY + LStack[1] + LStack[3], False);
                LX := LX + LStack[0] + LStack[2] + LStack[4];
                LY := LY + LStack[1] + LStack[3] + LStack[5];
                AddPoint(LX, LY, True);
                AddPoint(LX + LStack[6], LY + LStack[7], False);
                AddPoint(LX + LStack[6] + LStack[8], LY + LStack[7] + LStack[9], False);
                LX := LX + LStack[6] + LStack[8] + LStack[10];
                LY := LY + LStack[7] + LStack[9];
                AddPoint(LX, LY, True);
              end;
              LStackTop := 0;
            end;
          else
            LStackTop := 0;
          end;
        end;
        $1C: begin { shortint }
          LVal := SmallInt((ReadNextByte shl 8) or ReadNextByte);
          Push(LVal);
        end;
        $FF: begin { fixed 16.16 }
          LVal := Int32((ReadNextByte shl 24) or (ReadNextByte shl 16) or
            (ReadNextByte shl 8) or ReadNextByte);
          Push(LVal);
        end;
        $0F: begin { vsindex — set variation data subtable index }
          LVsIndex := Pop;
          if LVsIndex < 0 then LVsIndex := 0;
          if LVsIndex >= FCff2VStoreDataCount then
            LVsIndex := FCff2VStoreDataCount - 1;
        end;
        $10: begin { blend — apply variation deltas }
          { Stack: numValues values... numValues*numRegions deltas...
            blend replaces the numValues original values with blended values }
          if (FCff2VStoreParsed) and (LVsIndex >= 0) and
             (LVsIndex < FCff2VStoreDataCount) then
          begin
            LBlendN := Pop; { numValues to blend }
            if (LBlendN > 0) and (LBlendN <= LStackTop) then
            begin
              LBlendR := FCff2VStoreDataSubtables[LVsIndex].RegionIndexCount;
              { Read deltas from stack (top of stack has the deltas) }
              { Stack layout: [original values...] [deltas...]
                After Pop of numValues, the deltas are at the top }
              for LBlendI := 0 to LBlendN - 1 do
              begin
                LBlendDelta := 0;
                for LBlendJ := 0 to LBlendR - 1 do
                begin
                  { Pop delta for this value/region pair }
                  if LStackTop > 0 then
                  begin
                    Dec(LStackTop);
                    LBlendScalar := CalcRegionScalar(
                      FCff2VStoreDataSubtables[LVsIndex].RegionIndices[LBlendJ],
                      FVariationCoords);
                    LBlendDelta := LBlendDelta +
                      Round(LStack[LStackTop] * LBlendScalar);
                  end;
                end;
                { Apply delta to the original value }
                if LStackTop > 0 then
                begin
                  Dec(LStackTop);
                  LStack[LStackTop] := LStack[LStackTop] + LBlendDelta;
                  Inc(LStackTop);
                end;
              end;
            end;
          end;
        end;
      else
        begin
          if (LB >= 32) and (LB <= 246) then Push(LB - 139)
          else if (LB >= 247) and (LB <= 250) then Push((LB - 247) * 256 + ReadNextByte + 108)
          else if (LB >= 251) and (LB <= 254) then Push(-((LB - 251) * 256) - ReadNextByte - 108)
          else if LB = 28 then Push(SmallInt((ReadNextByte shl 8) or ReadNextByte))
          else if LB = 29 then Push(Int32((ReadNextByte shl 24) or (ReadNextByte shl 16) or
            (ReadNextByte shl 8) or ReadNextByte));
        end;
      end;
      if LPos >= LLen then
      begin
        if LCallDepth > 0 then DoReturn
        else Break;
      end;
    end;
  end;

var
  LI: Int32;
begin
  Result := Default(TFontGlyphOutline);
  FontGlyphOutlineClear(Result);
  if (not FCff2Parsed) or (AGlyphIndex >= UInt32(FCff2GlyphCount)) then Exit;

  LCharStrBase := Int32(FCff2CharStringOffsets[AGlyphIndex]);
  LCharStrLen := Int32(FCff2CharStringOffsets[AGlyphIndex + 1]) - LCharStrBase;
  if LCharStrLen <= 0 then Exit;

  LStackTop := 0;
  LCallDepth := 0;
  LData := @FData[LCharStrBase];
  LLen := LCharStrLen;
  LPos := 0;
  LX := 0; LY := 0;
  LPointCount := 0;
  LContourCount := 0;
  LStackWatermark := 0;
  LVsIndex := 0;
  SetLength(LPoints, 0);
  SetLength(LContours, 0);

  InterpretCharstring;
  CloseContour;

  if LPointCount > 0 then
  begin
    SetLength(Result.Points, LPointCount);
    for LI := 0 to LPointCount - 1 do Result.Points[LI] := LPoints[LI];
    SetLength(Result.ContourEnds, LContourCount);
    for LI := 0 to LContourCount - 1 do Result.ContourEnds[LI] := LContours[LI];
    Result.ContourCount := LContourCount;
    Result.XMin := High(Int16); Result.YMin := High(Int16);
    Result.XMax := Low(Int16);  Result.YMax := Low(Int16);
    for LI := 0 to LPointCount - 1 do
    begin
      if Result.Points[LI].X < Result.XMin then Result.XMin := Result.Points[LI].X;
      if Result.Points[LI].Y < Result.YMin then Result.YMin := Result.Points[LI].Y;
      if Result.Points[LI].X > Result.XMax then Result.XMax := Result.Points[LI].X;
      if Result.Points[LI].Y > Result.YMax then Result.YMax := Result.Points[LI].Y;
    end;
  end;
end;

procedure TTFontFace.ParseGvar;
{**
 * gvar table layout (Apple/FreeType spec, 20-byte header):
 *   +0:  uint32 version (0x00010000)
 *   +4:  uint16 axisCount
 *   +6:  uint16 sharedTupleCount
 *   +8:  uint32 sharedTuplesOffset (from gvar start)
 *   +12: uint16 glyphCount
 *   +14: uint16 flags (bit 0: 1=long uint32 offsets, 0=short uint16*2)
 *   +16: uint32 offsetToGlyphVariationData (from gvar start)
 *   +20: offset array [(glyphCount+1) entries]
 *   ...: shared tuples [sharedTupleCount * axisCount * F2.14]
 *   offsetToGlyphVariationData: glyph variation data
 *}
var
  LGvarIdx, LGvarBase, LGvarLen, LVersion: Int32;
  LAxisCount, LSharedTupleCount, LSharedTuplesOff: Int32;
  LGlyphCount, LDataArrayOff: Int32;
  LI, LJ, LOffBase, LPos: Int32;
begin
  FGvarParsed := False;
  FGvarGlyphCount := 0;
  FGvarSharedTupleCount := 0;
  FGvarAxisCount := 0;
  SetLength(FGvarSharedTuples, 0);
  SetLength(FGvarDataOffsets, 0);
  LGvarIdx := FindTable($67766172); { 'gvar' }
  if LGvarIdx < 0 then Exit;
  LGvarBase := Int32(FTables[LGvarIdx].Offset);
  LGvarLen := Int32(FTables[LGvarIdx].Length);
  if (LGvarBase < 0) or (LGvarLen < 20) or (LGvarBase + LGvarLen > FDataLength) then Exit;

  { Parse 20-byte header }
  LVersion := ReadUInt32BE(LGvarBase);
  if LVersion <> $00010000 then Exit;
  LAxisCount := ReadUInt16BE(LGvarBase + 4);
  if (LAxisCount <> FFvarAxisCount) and (FFvarAxisCount > 0) then Exit;
  LSharedTupleCount := ReadUInt16BE(LGvarBase + 6);
  LSharedTuplesOff  := ReadUInt32BE(LGvarBase + 8);
  LGlyphCount        := ReadUInt16BE(LGvarBase + 12);
  FGvarLongOffsets    := (ReadUInt16BE(LGvarBase + 14) and 1) <> 0;
  LDataArrayOff      := ReadUInt32BE(LGvarBase + 16);

  if LGlyphCount <= 0 then Exit;
  { Offset array starts right after the 20-byte header }
  if FGvarLongOffsets then
  begin
    if (LGvarBase + 20 + (LGlyphCount + 1) * 4 > FDataLength) then Exit;
  end
  else
  begin
    if (LGvarBase + 20 + (LGlyphCount + 1) * 2 > FDataLength) then Exit;
  end;

  FGvarBase := LGvarBase;
  FGvarAxisCount := LAxisCount;
  FGvarGlyphCount := LGlyphCount;
  FGvarSharedTupleCount := LSharedTupleCount;
  FGvarDataArrayBase := LGvarBase + LDataArrayOff;

  { Read shared tuples (F2.14 format, 2 bytes per axis) }
  if (LSharedTupleCount > 0) and (LSharedTuplesOff > 0) then
  begin
    SetLength(FGvarSharedTuples, LSharedTupleCount);
    LPos := LGvarBase + LSharedTuplesOff;
    for LI := 0 to LSharedTupleCount - 1 do
    begin
      SetLength(FGvarSharedTuples[LI], LAxisCount);
      for LJ := 0 to LAxisCount - 1 do
      begin
        if LPos + 2 <= FDataLength then
          FGvarSharedTuples[LI][LJ] := ReadInt16BE(LPos)
        else
          FGvarSharedTuples[LI][LJ] := 0;
        Inc(LPos, 2);
      end;
    end;
  end;

  { Read glyph variation data offsets — right after the 20-byte header }
  SetLength(FGvarDataOffsets, LGlyphCount + 1);
  LOffBase := LGvarBase + 20;
  if FGvarLongOffsets then
  begin
    for LI := 0 to LGlyphCount do
      FGvarDataOffsets[LI] := ReadUInt32BE(LOffBase + LI * 4);
  end
  else
  begin
    for LI := 0 to LGlyphCount do
      FGvarDataOffsets[LI] := ReadUInt16BE(LOffBase + LI * 2) * 2;
  end;

  FGvarParsed := True;
end;

procedure TTFontFace.SetVariationCoords(const ACoords: array of Single);
var
  LI, LCount: Int32;
begin
  LCount := Length(ACoords);
  if LCount = 0 then
  begin
    SetLength(FVariationCoords, 0);
    FHasVariationCoords := False;
    Exit;
  end;
  SetLength(FVariationCoords, LCount);
  for LI := 0 to LCount - 1 do
    FVariationCoords[LI] := ACoords[LI];
  FHasVariationCoords := True;
end;

procedure TTFontFace.ApplyGvarDeltas(AGlyphIndex: UInt32;
  var AOutline: TFontGlyphOutline; const ACoords: array of Single);
{**
 * Apply gvar deltas to a glyph outline, including IUP interpolation.
 * TupleVariationHeader: uint16 tupleDataSize, uint16 tupleIndex
 *   tupleIndex: bit 15=EMBEDDED_PEAK, bit 14=INTERMEDIATE, bit 13=PRIVATE_POINT_NUMBERS,
 *               bits 12:0 = shared tuple index
 *}
var
  LNumPoints, LNumContours: Int32;
  LDataStart, LTupleCount, LDataOff, LHdrOff: Int32;
  LI, LJ, LK, LM: Int32;
  LTupSize, LTupIdx, LHdrSize, LSharedIdx: Int32;
  LEmbeddedPeak, LIntermediate, LPrivatePts, LAllPts: Boolean;
  LPeak, LStartR, LEndR: array of Single;
  LCoord, LScalar: Single;
  LXDelta, LYDelta: array of Single;
  LHasDelta: array of Boolean;
  LPtNums, LSharedPtNums: array of Int32;
  LPtNumCount, LSharedPtNumCount: Int32;
  LSharedPtParsed: Boolean;
  LTupleHasSharedPts: Boolean;
  LRunPos, LRunCount, LRunType, LRunLen: Int32;
  LXWord, LYWord: Boolean;
  LDeltaIdx, LSerialPos, LTupBase: Int32;
  LPIdx, LEndC, LWrapL, LFirstD, LLastD: Int32;
  LPrevI, LNextI, LStartI: Int32;
  LPrevD, LNextD, LTotD, LLam: Single;

  { Parse packed point numbers. Returns new position after the data. }
  function ParsePtNums(APos: Int32): Int32;
  var
    LPtCount, LRunH, LRunC, LBit, LPK, LPVal, LJ2: Int32;
    LIs16: Boolean;
  begin
    LPtNumCount := 0;
    if APos + 1 > FDataLength then begin Result := APos; Exit; end;
    LPtCount := ReadUInt8(APos); Inc(APos);
    if LPtCount = 0 then begin Result := APos; Exit; end; { 0 = all points }

    SetLength(LPtNums, LNumPoints);
    LPK := 0;
    LPVal := 0;
    while LPK < LPtCount do
    begin
      if APos + 1 > FDataLength then Break;
      LRunH := ReadUInt8(APos); Inc(APos);
      LRunC := (LRunH and $3F) + 1;
      LIs16 := (LRunH and $80) <> 0;
      for LJ2 := 0 to LRunC - 1 do
      begin
        if LPK >= LPtCount then Break;
        if LIs16 then
        begin
          if APos + 2 <= FDataLength then
            LPVal := LPVal + ReadUInt16BE(APos);
          Inc(APos, 2);
        end
        else
        begin
          if APos < FDataLength then
            LPVal := LPVal + ReadUInt8(APos);
          Inc(APos);
        end;
        LPtNums[LPK] := LPVal;
        Inc(LPK);
      end;
    end;
    LPtNumCount := LPK;
    Result := APos;
  end;

begin
  if not FGvarParsed then Exit;
  if (AGlyphIndex < 0) or (AGlyphIndex >= UInt32(FGvarGlyphCount)) then Exit;
  LPtNums := nil;
  LSharedPtNums := nil;
  LPtNumCount := 0;
  LNumPoints := Length(AOutline.Points);
  if LNumPoints = 0 then Exit;
  LNumContours := AOutline.ContourCount;
  if LNumContours <= 0 then Exit;

  if FGvarDataOffsets[AGlyphIndex] = FGvarDataOffsets[AGlyphIndex + 1] then Exit;
  LDataStart := FGvarDataArrayBase + FGvarDataOffsets[AGlyphIndex];
  if (LDataStart < 0) or (LDataStart + 4 > FDataLength) then Exit;

  { GlyphVariationData header }
  LTupleCount := ReadUInt16BE(LDataStart) and $7FFF;
  LDataOff := ReadUInt16BE(LDataStart + 2);
  LHdrOff := LDataStart + 4;

  LSerialPos := LDataStart + LDataOff;

  { Shared point numbers (bit 15 of tupleVariationCount).
    Position: after all tuple headers, before serialized delta data.
    We parse them lazily: after advancing past all tuple headers. }
  LSharedPtParsed := False;
  LSharedPtNumCount := 0;
  LTupleHasSharedPts := (ReadUInt16BE(LDataStart) and $8000) <> 0;

  { Step 1: scan tuple headers to advance LHdrOff past all of them }
  for LI := 0 to LTupleCount - 1 do
  begin
    if (LHdrOff < 0) or (LHdrOff + 4 > FDataLength) then Break;
    LHdrSize := 4;
    LTupIdx := ReadUInt16BE(LHdrOff + 2);
    if (LTupIdx and $8000) <> 0 then Inc(LHdrSize, FGvarAxisCount * 2); { embedded peak }
    if (LTupIdx and $4000) <> 0 then Inc(LHdrSize, FGvarAxisCount * 4); { intermediate }
    Inc(LHdrOff, LHdrSize);
  end;

  { Step 2: parse shared packed point numbers at LSerialPos (data offset position).
    Even a 0-byte count (1 byte consumed) means "all points". }
  if LTupleHasSharedPts then
  begin
    LSerialPos := ParsePtNums(LSerialPos);
    if LPtNumCount > 0 then
    begin
      SetLength(LSharedPtNums, LPtNumCount);
      for LJ := 0 to LPtNumCount - 1 do
        LSharedPtNums[LJ] := LPtNums[LJ];
      LSharedPtNumCount := LPtNumCount;
    end
    else
      LSharedPtNumCount := 0;
    LSharedPtParsed := True;
  end;

  { Step 3: re-scan tuple headers and process delta data }
  LHdrOff := LDataStart + 4;
  LSerialPos := LDataStart + LDataOff;
  for LI := 0 to LTupleCount - 1 do
  begin
    if (LHdrOff < 0) or (LHdrOff + 4 > FDataLength) then Break;

    { TupleVariationHeader }
    LTupSize := ReadUInt16BE(LHdrOff) and $7FFF;
    LTupIdx := ReadUInt16BE(LHdrOff + 2);

    LEmbeddedPeak := (LTupIdx and $8000) <> 0;
    LIntermediate := (LTupIdx and $4000) <> 0;
    LPrivatePts := (LTupIdx and $2000) <> 0;
    LSharedIdx := LTupIdx and $0FFF;

    LHdrSize := 4;

    { Peak values (F2.14 / 16384.0) }
    SetLength(LPeak, FGvarAxisCount);
    if LEmbeddedPeak then
    begin
      for LJ := 0 to FGvarAxisCount - 1 do
        LPeak[LJ] := SmallInt(ReadUInt16BE(LHdrOff + LHdrSize + LJ * 2)) / 16384.0;
      Inc(LHdrSize, FGvarAxisCount * 2);
    end
    else if LSharedIdx < FGvarSharedTupleCount then
    begin
      for LJ := 0 to FGvarAxisCount - 1 do
        LPeak[LJ] := FGvarSharedTuples[LSharedIdx][LJ] / 16384.0;
    end
    else
    begin
      for LJ := 0 to FGvarAxisCount - 1 do
        LPeak[LJ] := 0;
    end;

    { Intermediate region: start / end }
    SetLength(LStartR, FGvarAxisCount);
    SetLength(LEndR, FGvarAxisCount);
    if LIntermediate then
    begin
      for LJ := 0 to FGvarAxisCount - 1 do
        LStartR[LJ] := SmallInt(ReadUInt16BE(LHdrOff + LHdrSize + LJ * 2)) / 16384.0;
      Inc(LHdrSize, FGvarAxisCount * 2);
      for LJ := 0 to FGvarAxisCount - 1 do
        LEndR[LJ] := SmallInt(ReadUInt16BE(LHdrOff + LHdrSize + LJ * 2)) / 16384.0;
      Inc(LHdrSize, FGvarAxisCount * 2);
    end
    else
    begin
      { Non-intermediate: start at normalized default (0.0), end at peak }
      for LJ := 0 to FGvarAxisCount - 1 do
      begin
        LStartR[LJ] := 0.0;
        LEndR[LJ] := LPeak[LJ];
      end;
    end;

    { Compute tuple scalar }
    LScalar := 1.0;
    for LJ := 0 to FGvarAxisCount - 1 do
    begin
      if LJ >= Length(ACoords) then Break;
      if LPeak[LJ] = 0 then Continue;
      LCoord := ACoords[LJ];
      if LCoord = LPeak[LJ] then Continue  { at peak → scalar unchanged }
      else if (LCoord < LStartR[LJ]) or (LCoord > LEndR[LJ]) then LScalar := 0
      else if LCoord < LPeak[LJ] then
      begin
        if LPeak[LJ] <> LStartR[LJ] then
          LScalar := LScalar * (LCoord - LStartR[LJ]) / (LPeak[LJ] - LStartR[LJ]);
      end
      else if LCoord > LPeak[LJ] then
      begin
        if LEndR[LJ] <> LPeak[LJ] then
          LScalar := LScalar * (LEndR[LJ] - LCoord) / (LEndR[LJ] - LPeak[LJ]);
      end;
    end;

    if LScalar = 0 then
    begin
      Inc(LHdrOff, LHdrSize);
      Inc(LSerialPos, LTupSize);
      Continue;
    end;

    { Init delta arrays }
    SetLength(LXDelta, LNumPoints);
    SetLength(LYDelta, LNumPoints);
    SetLength(LHasDelta, LNumPoints);
    FillChar(LXDelta[0], LNumPoints * SizeOf(Single), 0);
    FillChar(LYDelta[0], LNumPoints * SizeOf(Single), 0);
    FillChar(LHasDelta[0], LNumPoints, 0);

    { Determine which points have deltas }
    LAllPts := True;
    LPtNumCount := 0;
    LRunPos := LSerialPos;
    if LPrivatePts then
    begin
      LRunPos := ParsePtNums(LSerialPos);
      LAllPts := (LPtNumCount = 0);
    end
    else if LSharedPtParsed and (LSharedPtNumCount > 0) then
    begin
      SetLength(LPtNums, LSharedPtNumCount);
      for LJ := 0 to LSharedPtNumCount - 1 do
        LPtNums[LJ] := LSharedPtNums[LJ];
      LPtNumCount := LSharedPtNumCount;
      LAllPts := False;
    end;

    { Read delta runs }
    if LRunPos + 1 > FDataLength then
    begin
      Inc(LHdrOff, LHdrSize);
      Inc(LSerialPos, LTupSize);
      Continue;
    end;

    LRunCount := ReadUInt8(LRunPos); Inc(LRunPos);
    LDeltaIdx := 0;

    for LK := 0 to LRunCount - 1 do
    begin
      if LRunPos >= FDataLength then Break;
      LRunType := ReadUInt8(LRunPos); Inc(LRunPos);
      LRunLen := (LRunType and $3F) + 1;
      LXWord := (LRunType and $40) <> 0;
      LYWord := (LRunType and $80) <> 0;

      { X deltas — all X values first, then all Y }
      for LM := 0 to LRunLen - 1 do
      begin
        if LDeltaIdx + LM >= LNumPoints then Break;
        if LAllPts then
        begin
          if LXWord then
          begin
            if LRunPos + 2 <= FDataLength then
              LXDelta[LDeltaIdx + LM] := SmallInt(ReadUInt16BE(LRunPos));
            Inc(LRunPos, 2);
          end
          else
          begin
            if LRunPos < FDataLength then
              LXDelta[LDeltaIdx + LM] := ShortInt(ReadUInt8(LRunPos));
            Inc(LRunPos);
          end;
          LHasDelta[LDeltaIdx + LM] := True;
        end
        else
        begin
          if LDeltaIdx + LM >= LPtNumCount then Break;
          if LXWord then
          begin
            if LRunPos + 2 <= FDataLength then
              LXDelta[LPtNums[LDeltaIdx + LM]] := SmallInt(ReadUInt16BE(LRunPos));
            Inc(LRunPos, 2);
          end
          else
          begin
            if LRunPos < FDataLength then
              LXDelta[LPtNums[LDeltaIdx + LM]] := ShortInt(ReadUInt8(LRunPos));
            Inc(LRunPos);
          end;
          LHasDelta[LPtNums[LDeltaIdx + LM]] := True;
        end;
      end;
      { Y deltas }
      for LM := 0 to LRunLen - 1 do
      begin
        if LDeltaIdx + LM >= LNumPoints then Break;
        if LAllPts then
        begin
          if LYWord then
          begin
            if LRunPos + 2 <= FDataLength then
              LYDelta[LDeltaIdx + LM] := SmallInt(ReadUInt16BE(LRunPos));
            Inc(LRunPos, 2);
          end
          else
          begin
            if LRunPos < FDataLength then
              LYDelta[LDeltaIdx + LM] := ShortInt(ReadUInt8(LRunPos));
            Inc(LRunPos);
          end;
        end
        else
        begin
          if LDeltaIdx + LM >= LPtNumCount then Break;
          if LYWord then
          begin
            if LRunPos + 2 <= FDataLength then
              LYDelta[LPtNums[LDeltaIdx + LM]] := SmallInt(ReadUInt16BE(LRunPos));
            Inc(LRunPos, 2);
          end
          else
          begin
            if LRunPos < FDataLength then
              LYDelta[LPtNums[LDeltaIdx + LM]] := ShortInt(ReadUInt8(LRunPos));
            Inc(LRunPos);
          end;
        end;
      end;
      Inc(LDeltaIdx, LRunLen);
    end;

    { IUP interpolation for points without explicit deltas }
    if not LAllPts then
    begin
      LPIdx := 0;
      for LJ := 0 to LNumContours - 1 do
      begin
        LEndC := AOutline.ContourEnds[LJ];
        if LEndC < LPIdx then begin LPIdx := LEndC + 1; Continue; end;
        LWrapL := LEndC - LPIdx + 1;
        if LWrapL < 2 then begin LPIdx := LEndC + 1; Continue; end;

        { Find first/last point with delta in this contour }
        LFirstD := -1;
        for LK := LPIdx to LEndC do
          if LHasDelta[LK] then begin LFirstD := LK; Break; end;
        if LFirstD < 0 then begin LPIdx := LEndC + 1; Continue; end;
        LLastD := LFirstD;
        for LK := LEndC downto LPIdx do
          if LHasDelta[LK] then begin LLastD := LK; Break; end;

        { Interpolate untouched points between first and last delta points }
        for LK := LFirstD to LLastD do
        begin
          if LHasDelta[LK] then Continue;
          { Find previous delta point (wrapping) }
          LPrevI := LK - 1;
          if LPrevI < LPIdx then LPrevI := LEndC;
          while not LHasDelta[LPrevI] do
          begin
            Dec(LPrevI);
            if LPrevI < LPIdx then LPrevI := LEndC;
          end;
          { Find next delta point (wrapping) }
          LNextI := LK + 1;
          if LNextI > LEndC then LNextI := LPIdx;
          while not LHasDelta[LNextI] do
          begin
            Inc(LNextI);
            if LNextI > LEndC then LNextI := LPIdx;
          end;
          { X interpolation — distance along contour using X coords }
          LPrevD := 0;
          LStartI := LPrevI;
          while LStartI <> LK do
          begin
            LM := LStartI + 1;
            if LM > LEndC then LM := LPIdx;
            LPrevD := LPrevD + Abs(AOutline.Points[LM].X - AOutline.Points[LStartI].X);
            LStartI := LM;
          end;
          LNextD := 0;
          LStartI := LK;
          while LStartI <> LNextI do
          begin
            LM := LStartI + 1;
            if LM > LEndC then LM := LPIdx;
            LNextD := LNextD + Abs(AOutline.Points[LM].X - AOutline.Points[LStartI].X);
            LStartI := LM;
          end;
          LTotD := LPrevD + LNextD;
          if LTotD > 0 then LLam := LPrevD / LTotD else LLam := 0;
          LXDelta[LK] := LXDelta[LPrevI] + LLam * (LXDelta[LNextI] - LXDelta[LPrevI]);
          { Y interpolation — distance along contour using Y coords }
          LPrevD := 0;
          LStartI := LPrevI;
          while LStartI <> LK do
          begin
            LM := LStartI + 1;
            if LM > LEndC then LM := LPIdx;
            LPrevD := LPrevD + Abs(AOutline.Points[LM].Y - AOutline.Points[LStartI].Y);
            LStartI := LM;
          end;
          LNextD := 0;
          LStartI := LK;
          while LStartI <> LNextI do
          begin
            LM := LStartI + 1;
            if LM > LEndC then LM := LPIdx;
            LNextD := LNextD + Abs(AOutline.Points[LM].Y - AOutline.Points[LStartI].Y);
            LStartI := LM;
          end;
          LTotD := LPrevD + LNextD;
          if LTotD > 0 then LLam := LPrevD / LTotD else LLam := 0;
          LYDelta[LK] := LYDelta[LPrevI] + LLam * (LYDelta[LNextI] - LYDelta[LPrevI]);
        end;
        LPIdx := LEndC + 1;
      end;
    end;

    { Apply scaled deltas to outline }
    for LJ := 0 to LNumPoints - 1 do
    begin
      AOutline.Points[LJ].X := AOutline.Points[LJ].X + Round(LXDelta[LJ] * LScalar);
      AOutline.Points[LJ].Y := AOutline.Points[LJ].Y + Round(LYDelta[LJ] * LScalar);
    end;

    Inc(LHdrOff, LHdrSize);
    Inc(LSerialPos, LTupSize);
  end;
end;

function TTFontFace.CalcHvarAdvanceDelta(AGlyphIndex: UInt32;
  const ACoords: array of Single): Single;
var
  LOuter, LInner, LItemIdx, LRegionIdx, LI, LJ: Int32;
  LCoord, LScalar, LPeak, LStart, LEnd: Single;
  LDelta: Int16;
begin
  Result := 0;
  if not FHvarParsed then Exit;

  { Map glyph to delta set index via DeltaSetIndexMap }
  if Length(FHvarIndexMap) > 0 then
  begin
    if AGlyphIndex >= UInt32(Length(FHvarIndexMap)) then Exit;
    LOuter := FHvarIndexMap[AGlyphIndex] shr 16;
    LInner := FHvarIndexMap[AGlyphIndex] and $FFFF;
  end
  else
  begin
    { No index map: glyph index IS the item index }
    LOuter := 0;
    LInner := AGlyphIndex;
  end;

  if (LOuter < 0) or (LOuter >= Length(FHvarDeltas)) then Exit;
  if LInner >= FHvarItemCount then Exit;

  { Compute region scalars and accumulate delta }
  LItemIdx := LInner;
  LRegionIdx := 0;
  for LI := 0 to High(FHvarDeltas[LOuter]) do
  begin
    if LI >= FHvarItemCount * Length(FHvarRegions) then Break;
    if LItemIdx * Length(FHvarRegions) + LRegionIdx > High(FHvarDeltas[LOuter]) then Break;

    if LRegionIdx < Length(FHvarRegions) then
    begin
      { Compute scalar for this region }
      LScalar := 1.0;
      for LJ := 0 to FHvarAxisCount - 1 do
      begin
        if LJ >= Length(ACoords) then Break;
        LCoord := ACoords[LJ] / 16384.0;

        if Length(FHvarRegions[LRegionIdx]) >= (LJ + 1) * 3 then
        begin
          LPeak := FHvarRegions[LRegionIdx][LJ * 3 + 2] / 16384.0;
          LStart := FHvarRegions[LRegionIdx][LJ * 3] / 16384.0;
          LEnd := FHvarRegions[LRegionIdx][LJ * 3 + 1] / 16384.0;
        end
        else
        begin
          LPeak := 0; LStart := 0; LEnd := 0;
        end;

        if Abs(LCoord - LPeak) < 0.00001 then
          Continue;

        if LPeak < 0 then
        begin
          if (LCoord < LPeak) or (LCoord > LStart) then begin LScalar := 0; Break; end;
          if Abs(LPeak - LStart) < 0.00001 then Continue;
          LScalar := LScalar * (LCoord - LStart) / (LPeak - LStart);
        end
        else
        begin
          if (LCoord < LStart) or (LCoord > LPeak) then begin LScalar := 0; Break; end;
          if Abs(LPeak - LStart) < 0.00001 then Continue;
          LScalar := LScalar * (LCoord - LStart) / (LPeak - LStart);
        end;
      end;

      { Add weighted delta }
      if (LItemIdx * Length(FHvarRegions) + LRegionIdx <= High(FHvarDeltas[LOuter])) then
      begin
        LDelta := FHvarDeltas[LOuter][LItemIdx * Length(FHvarRegions) + LRegionIdx];
        Result := Result + LScalar * LDelta;
      end;
    end;

    Inc(LRegionIdx);
    if LRegionIdx >= Length(FHvarRegions) then
    begin
      LRegionIdx := 0;
      Inc(LItemIdx);
      if LItemIdx >= FHvarItemCount then Break;
    end;
  end;
end;

{ -- CFF2 -- }

function TTFontFace.Cff2FontDictCount: Int32;
begin
  Result := FCff2FDCount;
end;

function TTFontFace.GetCff2GlyphFD(AGlyphIndex: UInt32): Int32;
var
  LNRanges, LI, LFirst, LNext: Int32;
begin
  { FDSelect Format 0: one byte per glyph. Format 3: range-based. }
  Result := 0;
  if (FCff2FDCount <= 1) or (AGlyphIndex >= UInt32(FCff2FDSelectGlyphCount)) then
    Exit;
  if FCff2FDSelectFormat = 0 then
  begin
    if Int32(AGlyphIndex) < Length(FCff2FDSelectData) then
      Result := FCff2FDSelectData[AGlyphIndex];
  end
  else if FCff2FDSelectFormat = 3 then
  begin
    { Format 3: nRanges * (first: uint16, fd: uint8) + sentinel first: uint16 }
    if Length(FCff2FDSelectData) >= 2 then
    begin
      LNRanges := (Length(FCff2FDSelectData) - 2) div 3;
      for LI := 0 to LNRanges - 1 do
      begin
        LFirst := (FCff2FDSelectData[LI * 3] shl 8) or FCff2FDSelectData[LI * 3 + 1];
        LNext := (FCff2FDSelectData[(LI + 1) * 3] shl 8) or FCff2FDSelectData[(LI + 1) * 3 + 1];
        if (AGlyphIndex >= UInt32(LFirst)) and (AGlyphIndex < UInt32(LNext)) then
        begin
          Result := FCff2FDSelectData[LI * 3 + 2];
          Exit;
        end;
      end;
    end;
  end;
end;

function TTFontFace.GetCff2FontDict(AIndex: Int32): TFontCff2FontDict;
begin
  Result.PrivateDictOffset := 0;
  Result.PrivateDictSize := 0;
  { For multi-FD fonts, we'd need to parse each Font DICT's Private operator.
    Currently only FD 0 is fully parsed. Return defaults for others. }
end;

end.
