unit nextpas.core.font.base;
{**
 * @desc 纯 Pascal 字体渲染基础类型。
 *       定义 TTF 表常量、字形轮廓结构、字体/字形指标、光栅化结果。
 *       零内部依赖（只依赖 nextpas.core.base）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

const
  {** TTF 文件魔数：0x00010000 (TrueType) 或 'OTTO' (CFF OpenType) }
  FONT_MAGIC_TRUETYPE = $00010000;
  FONT_MAGIC_OTTO = $4F54544F;  // 'OTTO'
  FONT_MAGIC_TTC = $74746366;   // 'ttcf'

  {** TTF 表标签（Big-Endian 4 字节标识） }
  TABLE_TAG_HEAD = $68656164;   // 'head'
  TABLE_TAG_HHEA = $68686561;   // 'hhea'
  TABLE_TAG_MAXP = $6D617870;   // 'maxp'
  TABLE_TAG_CMAP = $636D6170;   // 'cmap'
  TABLE_TAG_LOCA = $6C6F6361;   // 'loca'
  TABLE_TAG_GLYF = $676C7966;   // 'glyf'
  TABLE_TAG_HMTX = $686D7478;   // 'hmtx'
  TABLE_TAG_OS2  = $4F532F32;   // 'OS/2'
  TABLE_TAG_GPOS = $47504F53;   // 'GPOS'
  TABLE_TAG_GSUB = $47535542;   // 'GSUB'
  TABLE_TAG_FVAR = $66766172;   // 'fvar'
  TABLE_TAG_AVAR = $61766172;   // 'avar'
  TABLE_TAG_NAME = $6E616D65;   // 'name'
  TABLE_TAG_POST = $706F7374;   // 'post'
  TABLE_TAG_GVAR = $67766172;   // 'gvar'
  TABLE_TAG_HVAR = $48564152;   // 'HVAR'
  TABLE_TAG_CFF  = $43464620;   // 'CFF '
  TABLE_TAG_CFF2 = $43464632;   // 'CFF2'
  TABLE_TAG_COLR = $434F4C52;   // 'COLR'
  TABLE_TAG_CPAL = $4350414C;   // 'CPAL'
  TABLE_TAG_CBDT = $43424454;   // 'CBDT'
  TABLE_TAG_CBLC = $43424C43;   // 'CBLC'

  {** GPOS Lookup Type：Pair Adjustment（kern） }
  GPOS_LOOKUP_PAIR_ADJUSTMENT = 2;

  {** GSUB Lookup Type：Ligature Substitution }
  GSUB_LOOKUP_LIGATURE = 4;
  GSUB_LOOKUP_SINGLE_SUBST = 1;
  GSUB_LOOKUP_MULTIPLE_SUBST = 2;
  GPOS_LOOKUP_SINGLE_ADJUSTMENT = 1;
  GPOS_LOOKUP_CURSIVE = 3;
  GPOS_LOOKUP_MARK_TO_BASE = 4;
  GPOS_LOOKUP_MARK_TO_MARK = 6;

  {** GSUB Lookup Type：Context/ChainedContext Substitution }
  GSUB_LOOKUP_CONTEXT_SUBST       = 5;
  GSUB_LOOKUP_CHAINED_CONTEXT_SUBST = 6;

  {** GPOS Lookup Type：MarkToLigature/Context/ChainedContext Positioning }
  GPOS_LOOKUP_MARK_TO_LIGATURE = 5;
  GPOS_LOOKUP_CONTEXT_POS       = 7;
  GPOS_LOOKUP_CHAINED_CONTEXT_POS = 8;

  {** cmap 平台 ID }
  CMAP_PLATFORM_UNICODE   = 0;
  CMAP_PLATFORM_MACINTOSH = 1;
  CMAP_PLATFORM_WINDOWS   = 3;

  {** cmap Unicode 编码（Platform ID 0 的 encoding） }
  CMAP_ENCODING_UNICODE_DEFAULT  = 0;  // Unicode 1.0
  CMAP_ENCODING_UNICODE_BMP      = 3;  // Unicode 2.0+ BMP (Format 4)
  CMAP_ENCODING_UNICODE_FULL     = 4;  // Unicode 2.0+ Full (Format 12)

  {** cmap Windows 编码（Platform ID 3 的 encoding） }
  CMAP_ENCODING_WINDOWS_SYMBOL   = 0;
  CMAP_ENCODING_WINDOWS_UNICODE_BMP  = 1;  // Format 4
  CMAP_ENCODING_WINDOWS_UNICODE_FULL = 10; // Format 12

  {** cmap 子表格式 }
  CMAP_FORMAT_4  = 4;   // BMP（最常用）
  CMAP_FORMAT_6  = 6;   // 紧凑单区间
  CMAP_FORMAT_12 = 12;  // 全 Unicode（SMP emoji 等）

  {** glyf 简单字形标志位 }
  GLYF_FLAG_ON_CURVE        = $01;
  GLYF_FLAG_X_SHORT         = $02;
  GLYF_FLAG_Y_SHORT         = $04;
  GLYF_FLAG_X_SAME          = $10;
  GLYF_FLAG_Y_SAME          = $20;
  GLYF_FLAG_REPEAT          = $08;

  {** glyf 复合字形标志位 }
  GLYF_COMPOUND_ARG_ARE_WORDS     = $0001;
  GLYF_COMPOUND_ARGS_ARE_XY       = $0002;
  GLYF_COMPOUND_ROUND_XY          = $0004;
  GLYF_COMPOUND_HAVE_SCALE        = $0008;
  GLYF_COMPOUND_MORE_COMPONENTS   = $0020;
  GLYF_COMPOUND_HAVE_XY_SCALE     = $0040;
  GLYF_COMPOUND_HAVE_MATRIX       = $0080;
  GLYF_COMPOUND_HAVE_INSTRUCTIONS = $0100;
  GLYF_COMPOUND_USE_METRICS       = $0400;

  {** Bezier 光栅化默认参数 }
  RASTERIZER_FLATNESS_PX = 0.25;    // 自适应细分平坦度阈值（像素）
  RASTERIZER_MAX_SUBDIVISIONS = 64; // 每条曲线最大细分数

  {** 复合字形最大递归深度 }
  GLYF_COMPOUND_MAX_DEPTH = 16;

type
  {** 字体文件格式 }
  TFontFileFormat = (
    fffUnknown,
    fffTrueType,     // glyf 轮廓
    fffOpenTypeCff   // CFF 轮廓（不支持）
  );

  {** TTF 表目录条目 }
  TFontTableEntry = record
    Tag: UInt32;
    Offset: UInt32;
    Length: UInt32;
  end;
  TFontTableEntryArray = array of TFontTableEntry;

  {** head 表数据 }
  TFontHeadTable = record
    MajorVersion: UInt16;
    MinorVersion: UInt16;
    FontRevision: UInt32;
    UnitsPerEm: UInt16;
    Created: UInt64;
    Modified: UInt64;
    XMin: Int16;
    YMin: Int16;
    XMax: Int16;
    YMax: Int16;
    MacStyle: UInt16;
    LowestRecPpem: UInt16;
    IndexToLocFormat: Int16;   // 0=short (2 bytes), 1=long (4 bytes)
  end;

  {** hhea 表数据 }
  TFontHheaTable = record
    Ascender: Int16;
    Descender: Int16;
    LineGap: Int16;
    AdvanceWidthMax: UInt16;
    MinLeftSideBearing: Int16;
    MinRightSideBearing: Int16;
    XMaxExtent: Int16;
    NumberOfHMetrics: UInt16;
  end;

  {** maxp 表数据（TrueType 版本） }
  TFontMaxpTable = record
    NumGlyphs: UInt16;
  end;

  {** os2 表关键字段 }
  TFontOs2Table = record
    XAvgCharWidth: Int16;
    UsWeightClass: UInt16;
    UsWidthClass: UInt16;
    FsSelection: UInt16;
    STypoAscender: Int16;
    STypoDescender: Int16;
    STypoLineGap: Int16;
    SxHeight: Int16;
    SCapHeight: Int16;
    Panose: array[0..9] of Byte;
  end;

  {** 字体级指标 }
  TFontMetrics = record
    UnitsPerEm: UInt16;
    Ascender: Int16;
    Descender: Int16;
    LineGap: Int16;
    XMin, YMin: Int16;
    XMax, YMax: Int16;
  end;

  {** 字体水平度量条目（hmtx 表） }
  TFontHorizontalMetric = record
    AdvanceWidth: UInt16;
    LeftSideBearing: Int16;
  end;
  TFontHorizontalMetricArray = array of TFontHorizontalMetric;

  {** 轮廓点 }
  TFontContourPoint = record
    X, Y: Int16;
    OnCurve: Boolean;
  end;
  TFontContourPointArray = array of TFontContourPoint;

  {** 字形轮廓（simple glyf 解析后） }
  TFontGlyphOutline = record
    XMin, YMin: Int16;
    XMax, YMax: Int16;
    ContourCount: Int32;
    Points: TFontContourPointArray;
    ContourEnds: array of UInt16;  // 每个轮廓的最后一点索引
  end;

  {** 复合字形成分 }
  TFontCompoundComponent = record
    GlyphIndex: UInt16;
    OffsetX, OffsetY: Int16;
    ScaleX, ScaleY: Single;  // 2x2 仿射矩阵缩放（默认 1.0）
    ScaleXY, ScaleYX: Single;
    UseMetrics: Boolean;     // 复合字形使用此成分的 metrics
  end;
  TFontCompoundComponentArray = array of TFontCompoundComponent;

  {** 字形级指标 }
  TFontGlyphMetrics = record
    Width, Height: Int32;        // 边界框（font units）
    BearingX, BearingY: Int32;   // 左边距、上边距（font units）
    AdvanceWidth: Int32;         // 横向步进（font units）
  end;

  {** 光栅化输出格式 }
  TFontRasterPixelFormat = (
    frpfAlpha8    // 8 位灰度覆盖率
  );

  {** 光栅化结果 }
  TFontRasterResult = record
    WidthPx, HeightPx: Int32;
    BearingXPx, BearingYPx: Int32;
    AdvancePx: Int32;
    PitchBytes: Int32;
    Pixels: array of Byte;       // Alpha8 覆盖率位图
  end;

  {** Bezier 线段（细分后的直线段） }
  TFontLineSegment = record
    X0, Y0: Single;
    X1, Y1: Single;
  end;
  TFontLineSegmentArray = array of TFontLineSegment;

  {** 边表条目（扫描线光栅化用） }
  TFontEdge = record
    YMin, YMax: Single;   // Y 范围（像素坐标）
    XAtYMin: Single;      // Y=YMin 时的 X 坐标
    InvSlope: Single;      // 1/m (dx/dy)，水平边跳过
  end;
  TFontEdgeArray = array of TFontEdge;

  {** cmap 格式 4 子表 }
  TFontCmapFmt4 = record
    StartCode: array of UInt16;
    EndCode: array of UInt16;
    IdDelta: array of Int16;
    IdRangeOffset: array of UInt16;
    SegmentCount: Int32;
    GlyphIdArray: array of UInt16;
  end;

  {** cmap 格式 12 子表组 }
  TFontCmapFmt12Group = record
    StartCharCode: UInt32;
    EndCharCode: UInt32;
    StartGlyphCode: UInt32;
  end;
  TFontCmapFmt12GroupArray = array of TFontCmapFmt12Group;

  {** cmap 格式 12 子表 }
  TFontCmapFmt12 = record
    Groups: TFontCmapFmt12GroupArray;
  end;

  {** 字体加载错误 }
  EFontError = class(Exception);

  {** GPOS PairPos kern 子表（class-based，查询时解析） }
  TFontPairPosSubtable = record
    BaseOffset: Int32;       // 子表在文件中的偏移
    CoverageOffset: Int32;   // Coverage 表偏移（相对文件）
    ClassDef1Offset: Int32;  // ClassDef1 偏移（相对文件）
    ClassDef2Offset: Int32;  // ClassDef2 偏移（相对文件）
    Class2Count: Int32;      // class2 数量
    ValueRecordSize: Int32;  // 每条 ValueRecord 的字节数
    XAdvanceOffset: Int32;   // XAdvance 在 ValueRecord 中的字节偏移（-1 = 无）
  end;
  TFontPairPosSubtableArray = array of TFontPairPosSubtable;

  {** GSUB 连字子表数据（查询时解析） }
  TFontLigatureSubtable = record
    BaseOffset: Int32;       // 子表在文件中的偏移
    CoverageOffset: Int32;   // Coverage 表偏移（相对文件）
    LigatureSetCount: Int32; // LigatureSet 数量
  end;
  TFontLigatureSubtableArray = array of TFontLigatureSubtable;

  {** GSUB/GPOS 锚点（mark attachment） }
  TFontAnchor = record
    X, Y: Int16;
  end;

  {** Glyph ID 数组（MultipleSubst 结果） }
  TFontGlyphIdArray = array of UInt16;

  {** GSUB SingleSubst 子表（查询时解析） }
  TFontSingleSubstSubtable = record
    CoverageOffset: Int32;
    Format: UInt16;
    DeltaGlyphID: Int16;
    GlyphCount: Int32;
    GlyphArrayOffset: Int32;
  end;
  TFontSingleSubstSubtableArray = array of TFontSingleSubstSubtable;

  {** GPOS SinglePos 子表（查询时解析） }
  TFontSinglePosSubtable = record
    CoverageOffset: Int32;
    Format: UInt16;
    ValueFormat: UInt16;
    XAdvanceOffset: Int32;
    ValueRecordSize: Int32;
    ValueOffset: Int32;
  end;
  TFontSinglePosSubtableArray = array of TFontSinglePosSubtable;

  {** GPOS MarkToBase 子表（查询时解析） }
  TFontMarkToBaseSubtable = record
    MarkCoverageOffset: Int32;
    BaseCoverageOffset: Int32;
    ClassCount: Int32;
    MarkArrayOffset: Int32;
    BaseArrayOffset: Int32;
  end;
  TFontMarkToBaseSubtableArray = array of TFontMarkToBaseSubtable;

  {** GPOS MarkToMark 子表（查询时解析） }
  TFontMarkToMarkSubtable = record
    Mark1CoverageOffset: Int32;
    Mark2CoverageOffset: Int32;
    ClassCount: Int32;
    Mark1ArrayOffset: Int32;
    Mark2ArrayOffset: Int32;
  end;
  TFontMarkToMarkSubtableArray = array of TFontMarkToMarkSubtable;

  {** GPOS MarkToLigature 子表（查询时解析） }
  TFontMarkToLigatureSubtable = record
    MarkCoverageOffset: Int32;
    LigatureCoverageOffset: Int32;
    ClassCount: Int32;
    MarkArrayOffset: Int32;
    LigatureArrayOffset: Int32;
  end;
  TFontMarkToLigatureSubtableArray = array of TFontMarkToLigatureSubtable;

  {** GPOS CursivePos 子表（查询时解析） }
  TFontCursivePosSubtable = record
    CoverageOffset: Int32;
    EntryExitCount: Int32;
    EntryExitArrayOffset: Int32;
  end;
  TFontCursivePosSubtableArray = array of TFontCursivePosSubtable;

  {** GPOS PairPos Fmt1 子表（pair-based kern，查询时解析） }
  TFontPairPosFmt1Subtable = record
    CoverageOffset: Int32;
    ValueFormat1: UInt16;
    ValueFormat2: UInt16;
    PairSetCount: Int32;
    PairSetOffsetsOffset: Int32;
    XAdvance1Offset: Int32;
    ValueRecord1Size: Int32;
  end;
  TFontPairPosFmt1SubtableArray = array of TFontPairPosFmt1Subtable;

  {** GSUB MultipleSubst 子表（查询时解析） }
  TFontMultipleSubstSubtable = record
    CoverageOffset: Int32;
    SequenceCount: Int32;
    SequenceOffsetsOffset: Int32; { 子表内 Sequence 偏移数组的起始位置 }
    BaseOffset: Int32;           { 子表起始位置 }
  end;
  TFontMultipleSubstSubtableArray = array of TFontMultipleSubstSubtable;

  {** GSUB AlternateSubst 子表（查询时解析） }
  TFontAlternateSubstSubtable = record
    CoverageOffset: Int32;
    AlternateSetCount: Int32;
    AlternateSetOffsetsOffset: Int32;
    BaseOffset: Int32;
  end;
  TFontAlternateSubstSubtableArray = array of TFontAlternateSubstSubtable;

  {** ContextSubst/ContextPos LookupRecord }
  TFontContextLookupRecord = record
    SequenceIndex: UInt16;
    LookupIndex: UInt16;
  end;
  TFontContextLookupRecordArray = array of TFontContextLookupRecord;

  {** ContextSubst/ContextPos 子表（支持 Format 1/2/3 + Chained） }
  TFontContextSubtable = record
    Format: Int32;            { 1=glyph, 2=class, 3=coverage }
    CoverageOffset: Int32;    { 绝对偏移 }
    IsChained: Boolean;       { True = ChainedContext (GSUB type 6 / GPOS type 8) }
    { Format 1: glyph-based rule sets }
    RuleSetCount: Int32;
    RuleSetOffsetsOffset: Int32; { RuleSet offsets array from subtable start }
    { Format 2: class-based }
    ClassDefOffset: Int32;
    ClassSetCount: Int32;
    ClassSetOffsetsOffset: Int32;
    { Format 3: coverage-based }
    GlyphCount: Int32;
    LookupRecordCount: Int32;
    LookupRecordsOffset: Int32;
    { Chained Fmt1/Fmt3: backtrack + lookahead + inputGlyphCount }
    InputGlyphCount: Int32;
    BacktrackGlyphCount: Int32;
    BacktrackCoverageOffsetsOffset: Int32;
    LookaheadGlyphCount: Int32;
    LookaheadCoverageOffsetsOffset: Int32;
  end;
  TFontContextSubtableArray = array of TFontContextSubtable;

  {** COLR v0 颜色层：一个 glyph 由多个彩色层叠加组成 }
  TFontColorLayer = record
    GlyphId: UInt16;       { 层字形 ID }
    PaletteIndex: UInt16;  { 调色板颜色索引（$FFFF = 前景色） }
  end;
  TFontColorLayerArray = array of TFontColorLayer;

  {** COLR v0 颜色层记录：base glyph → layers }
  TFontColorLayerRecord = record
    BaseGlyphId: UInt16;
    Layers: TFontColorLayerArray;
  end;
  TFontColorLayerRecordArray = array of TFontColorLayerRecord;

  {** CPAL 调色板颜色（BGRA 顺序） }
  TFontPaletteColor = record
    Blue, Green, Red, Alpha: Byte;
  end;
  TFontPaletteColorArray = array of TFontPaletteColor;

  {** CBDT 位图字形数据（从 CBDT/CBLC 表提取） }
  TFontBitmapGlyph = record
    Width, Height: UInt8;        { 位图像素尺寸 }
    BearingX, BearingY: Int8;    { 基线偏移 }
    Advance: UInt8;              { 水平步进（像素） }
    PngData: array of Byte;      { 原始 PNG 数据（可直接解码） }
    PngDataLength: Int32;        { PNG 数据有效长度 }
  end;

  {** fvar 变体轴 }
  TFontVariationAxis = record
    Tag: UInt32;
    MinValue, DefaultValue, MaxValue: Single;
    AxisNameID: UInt16;
  end;

  {** fvar 命名实例 }
  TFontNamedInstance = record
    NameID: UInt16;
    Coordinates: array of Single;
  end;

  {** CFF2 Font DICT }
  TFontCff2FontDict = record
    PrivateDictOffset: UInt32;
    PrivateDictSize: UInt32;
  end;
  TCff2FontDict = TFontCff2FontDict;

  {** 字体特性配置 }
  TFontFeatureConfig = record
    Tag: UInt32;
    Enabled: Boolean;
    Value: UInt16;
  end;

const
  {** OpenType Feature Tags }
  FEATURE_TAG_LIGA = $6C696761; { 'liga' }
  FEATURE_TAG_KERN = $6B65726E; { 'kern' }
  FEATURE_TAG_DLIG = $646C6967; { 'dlig' }
  FEATURE_TAG_CLIG = $636C6967; { 'clig' }
  FEATURE_TAG_MARK = $6D61726B; { 'mark' }
  FEATURE_TAG_MKMK = $6D6B6D6B; { 'mkmk' }
  FEATURE_TAG_RLIG = $726C6967; { 'rlig' }
  FEATURE_TAG_LOCA = $6C6F6361; { 'loca' }
  FEATURE_TAG_CALT = $63616C74; { 'calt' }

function FontFeatureConfigDefault: TFontFeatureConfig;
function FontFeatureIsEnabled(const AConfig: TFontFeatureConfig; ATag: UInt32): Boolean;
function FontFeatureGetValue(const AConfig: TFontFeatureConfig; ATag: UInt32): UInt16;
function FontFeatureParseString(const AStr: string; out ATag: UInt32; out AValue: UInt32): Boolean;
function FontFeatureTagFromString(const AStr: string): UInt32;

{** 字形轮廓内存释放 }
procedure FontGlyphOutlineClear(var AOutline: TFontGlyphOutline);

{** 光栅化结果内存释放 }
procedure FontRasterResultClear(var AResult: TFontRasterResult);

implementation

procedure FontGlyphOutlineClear(var AOutline: TFontGlyphOutline);
begin
  AOutline.ContourCount := 0;
  SetLength(AOutline.Points, 0);
  SetLength(AOutline.ContourEnds, 0);
  AOutline.XMin := 0;
  AOutline.YMin := 0;
  AOutline.XMax := 0;
  AOutline.YMax := 0;
end;

procedure FontRasterResultClear(var AResult: TFontRasterResult);
begin
  AResult.WidthPx := 0;
  AResult.HeightPx := 0;
  AResult.BearingXPx := 0;
  AResult.BearingYPx := 0;
  AResult.AdvancePx := 0;
  AResult.PitchBytes := 0;
  SetLength(AResult.Pixels, 0);
end;

function FontFeatureConfigDefault: TFontFeatureConfig;
begin
  Result.Tag := 0;
  Result.Enabled := True;
  Result.Value := 0;
end;

function FontFeatureIsEnabled(const AConfig: TFontFeatureConfig; ATag: UInt32): Boolean;
begin
  { 如果配置指定了特定 tag，检查 tag 匹配 }
  if (AConfig.Tag <> 0) and (AConfig.Tag <> ATag) then
    Exit(False);
  { 默认配置（Tag=0）时，对常见特性有内置默认行为 }
  if AConfig.Tag = 0 then
  begin
    case ATag of
      FEATURE_TAG_LIGA, FEATURE_TAG_KERN, FEATURE_TAG_CLIG,
      FEATURE_TAG_RLIG, FEATURE_TAG_CALT: Result := True;
    else
      Result := False; { 其他特性默认禁用 }
    end;
    Exit;
  end;
  Result := AConfig.Enabled;
end;

function FontFeatureGetValue(const AConfig: TFontFeatureConfig; ATag: UInt32): UInt16;
begin
  { 如果配置指定了特定 tag，检查 tag 匹配 }
  if (AConfig.Tag <> 0) and (AConfig.Tag <> ATag) then
    Exit(0);
  { 默认配置（Tag=0）时，对常见特性有内置默认值 }
  if AConfig.Tag = 0 then
  begin
    case ATag of
      FEATURE_TAG_LIGA, FEATURE_TAG_KERN, FEATURE_TAG_CLIG,
      FEATURE_TAG_RLIG, FEATURE_TAG_CALT: Result := 1;
    else
      Result := 0;
    end;
    Exit;
  end;
  Result := AConfig.Value;
end;

function FontFeatureParseString(const AStr: string; out ATag: UInt32; out AValue: UInt32): Boolean;
var
  LStr: string;
  LLen: Int32;
  LTagStr: string;
  LEqPos: Int32;

  { 简单 Trim 实现（不依赖 SysUtils） }
  function TrimStr(const S: string): string;
  var
    L, R: Int32;
  begin
    L := 1;
    R := Length(S);
    while (L <= R) and (S[L] = ' ') do Inc(L);
    while (R >= L) and (S[R] = ' ') do Dec(R);
    Result := Copy(S, L, R - L + 1);
  end;

begin
  ATag := 0;
  AValue := 0;
  Result := False;

  LStr := TrimStr(AStr);
  LLen := Length(LStr);
  if LLen < 2 then
    Exit;

  { 格式 1: "+tag" / "-tag" }
  if (LStr[1] = '+') or (LStr[1] = '-') then
  begin
    ATag := FontFeatureTagFromString(Copy(LStr, 2, LLen - 1));
    if ATag = 0 then
      Exit;
    if LStr[1] = '+' then
      AValue := 1
    else
      AValue := 0;
    Result := True;
    Exit;
  end;

  { 格式 2: "'tag'" (quoted) }
  if (LStr[1] = '''') and (LLen >= 4) and (LStr[LLen] = '''') then
  begin
    ATag := FontFeatureTagFromString(Copy(LStr, 2, LLen - 2));
    if ATag = 0 then
      Exit;
    AValue := 1; { 默认启用 }
    Result := True;
    Exit;
  end;

  { 格式 3: "tag=value" }
  LEqPos := Pos('=', LStr);
  if LEqPos > 1 then
  begin
    ATag := FontFeatureTagFromString(Copy(LStr, 1, LEqPos - 1));
    if ATag = 0 then
      Exit;
    Val(Copy(LStr, LEqPos + 1, LLen - LEqPos), AValue);
    Result := True;
    Exit;
  end;

  { 格式 4: "tag on" / "tag off" }
  if (LLen > 3) and (Copy(LStr, LLen - 2, 3) = ' on') then
  begin
    ATag := FontFeatureTagFromString(Copy(LStr, 1, LLen - 3));
    if ATag = 0 then
      Exit;
    AValue := 1;
    Result := True;
    Exit;
  end;
  if (LLen > 4) and (Copy(LStr, LLen - 3, 4) = ' off') then
  begin
    ATag := FontFeatureTagFromString(Copy(LStr, 1, LLen - 4));
    if ATag = 0 then
      Exit;
    AValue := 0;
    Result := True;
    Exit;
  end;
end;

function FontFeatureTagFromString(const AStr: string): UInt32;
var
  LStr: string;
  I, LLen: Int32;
begin
  Result := 0;
  LLen := Length(AStr);
  if LLen < 1 then
    Exit;
  { 取前 4 个字符，不足 4 个补空格 }
  for I := 1 to 4 do
  begin
    Result := Result shl 8;
    if I <= LLen then
      Result := Result or Ord(AStr[I])
    else
      Result := Result or Ord(' ');
  end;
end;

end.
