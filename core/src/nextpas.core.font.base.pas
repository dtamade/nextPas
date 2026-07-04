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
  TABLE_TAG_CFF  = $43464620;   // 'CFF '
  TABLE_TAG_CFF2 = $43464632;   // 'CFF2'
  TABLE_TAG_HMTX = $686D7478;   // 'hmtx'
  TABLE_TAG_OS2  = $4F532F32;   // 'OS/2'
  TABLE_TAG_GPOS = $47504F53;   // 'GPOS'
  TABLE_TAG_GSUB = $47535542;   // 'GSUB'
  TABLE_TAG_POST = $706F7374;   // 'post'
  TABLE_TAG_FVAR = $66766172;   // 'fvar'
  TABLE_TAG_AVAR = $61766172;   // 'avar'
  TABLE_TAG_HVAR = $48564152;   // 'HVAR'
  TABLE_TAG_VVAR = $56564152;   // 'VVAR'
  TABLE_TAG_GVAR = $67766172;   // 'gvar'
  TABLE_TAG_NAME = $6E616D65;   // 'name'

  {** GPOS Lookup Type：Pair Adjustment（kern） }
  GPOS_LOOKUP_PAIR_ADJUSTMENT = 2;
  {** GPOS Lookup Type：Single Adjustment }
  GPOS_LOOKUP_SINGLE_POS = 1;
  {** GPOS Lookup Type：Cursive Attachment }
  GPOS_LOOKUP_CursivePos = 3;
  {** GPOS Lookup Type：Mark-to-Base Attachment }
  GPOS_LOOKUP_MARK_TO_BASE = 4;
  {** GPOS Lookup Type：Mark-to-Ligature Attachment }
  GPOS_LOOKUP_MARK_TO_LIGATURE = 5;
  {** GPOS Lookup Type：Mark-to-Mark Attachment }
  GPOS_LOOKUP_MARK_TO_MARK = 6;
  {** GPOS/GSUB Lookup Type：Extension（32-bit offset 包装） }
  GPOS_LOOKUP_EXTENSION = 9;
  GSUB_LOOKUP_EXTENSION = 7;

  {** GSUB Lookup Type：Single Substitution }
  GSUB_LOOKUP_SINGLE = 1;
  {** GSUB Lookup Type：Ligature Substitution }
  GSUB_LOOKUP_LIGATURE = 4;
  {** GSUB Lookup Type：Multiple Substitution（一对多） }
  GSUB_LOOKUP_MULTIPLE = 2;
  {** GSUB Lookup Type：Alternate Substitution（备选替换） }
  GSUB_LOOKUP_ALTERNATE = 3;
  {** GSUB Lookup Type：Context Substitution（规则匹配） }
  GSUB_LOOKUP_CONTEXT = 5;
  {** GSUB Lookup Type：Chained Context Substitution }
  GSUB_LOOKUP_CHAINED_CONTEXT = 6;
  {** GPOS Lookup Type：Context Positioning（规则匹配定位） }
  GPOS_LOOKUP_CONTEXT_POS = 7;
  {** GPOS Lookup Type：Chained Context Positioning }
  GPOS_LOOKUP_CONTEXT_POS_CHAINED = 8;

  {** OpenType Feature Tags（Big-Endian 4 字节标识） }
  FEATURE_TAG_KERN = $6B65726E;  // 'kern' — Kerning
  FEATURE_TAG_LIGA = $6C696761;  // 'liga' — Standard Ligatures
  FEATURE_TAG_CLIG = $636C6967;  // 'clig' — Contextual Ligatures
  FEATURE_TAG_MARK = $6D61726B;  // 'mark' — Mark Positioning
  FEATURE_TAG_MKMK = $6D6B6D6B;  // 'mkmk' — Mark-to-Mark Positioning
  FEATURE_TAG_CURS = $63757273;  // 'curs' — Cursive Positioning
  FEATURE_TAG_CALT = $63616C74;  // 'calt' — Contextual Alternates
  FEATURE_TAG_DLIG = $646C6967;  // 'dlig' — Discretionary Ligatures
  FEATURE_TAG_HLIG = $686C6967;  // 'hlig' — Historical Ligatures
  FEATURE_TAG_RLIG = $726C6967;  // 'rlig' — Required Ligatures
  FEATURE_TAG_CCMP = $63636D70;  // 'ccmp' — Glyph Composition/Decomposition
  FEATURE_TAG_LOCL = $6C6F636C;  // 'locl' — Localized Forms
  FEATURE_TAG_SALT = $73616C74;  // 'salt' — Stylistic Alternates

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
  CMAP_FORMAT_14 = 14;  // IVS（Variation Selector）

  {** name 表 NameID }
  NAME_ID_COPYRIGHT        = 0;
  NAME_ID_FONT_FAMILY      = 1;
  NAME_ID_FONT_SUBFAMILY   = 2;
  NAME_ID_UNIQUE_ID        = 3;
  NAME_ID_FULL_NAME        = 4;
  NAME_ID_VERSION          = 5;
  NAME_ID_POSTSCRIPT_NAME  = 6;
  NAME_ID_TRADEMARK        = 7;
  NAME_ID_MANUFACTURER     = 8;
  NAME_ID_DESIGNER         = 9;
  NAME_ID_DESCRIPTION      = 10;
  NAME_ID_VENDOR_URL       = 11;
  NAME_ID_DESIGNER_URL     = 12;
  NAME_ID_LICENSE          = 13;
  NAME_ID_LICENSE_URL      = 14;
  NAME_ID_TYPOGRAPHIC_FAMILY    = 16;
  NAME_ID_TYPOGRAPHIC_SUBFAMILY = 17;
  NAME_ID_COMPATIBLE_FULL       = 18;
  NAME_ID_SAMPLE_TEXT           = 19;
  NAME_ID_POSTSCRIPT_CID        = 20;
  NAME_ID_WWS_FAMILY            = 21;
  NAME_ID_WWS_SUBFAMILY         = 22;

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

  {** gvar tuple variation header flags }
  GVAR_TUPLE_COUNT_MASK           = $0FFF;  // tupleCount 低 12 位
  GVAR_TUPLES_SHARE_POINT_NUMBERS = $8000;  // 共享 packed points
  {** gvar tuple index flags }
  GVAR_TI_EMBEDDED_TUPLE_COORD    = $8000;  // 内嵌 tuple coords
  GVAR_TI_INTERMEDIATE_TUPLE      = $4000;  // 中间区域 tuple
  GVAR_TI_PRIVATE_POINT_NUMBERS   = $2000;  // 该 tuple 有自己的 point numbers
  GVAR_TI_TUPLE_INDEX_MASK        = $0FFF;  // 共享 tuple 索引掩码
  {** gvar packed points encoding }
  GVAR_PT_POINTS_ARE_WORDS        = $80;    // 点索引为 16-bit
  GVAR_PT_POINT_RUN_COUNT_MASK    = $7F;    // 运行计数掩码
  {** gvar packed deltas encoding }
  GVAR_DT_DELTAS_ARE_ZERO         = $80;    // 全零 delta 运行
  GVAR_DT_DELTAS_ARE_WORDS        = $40;    // 16-bit delta 运行
  GVAR_DT_DELTA_RUN_COUNT_MASK    = $3F;    // 运行计数掩码

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
    fffOpenTypeCff   // CFF 轮廓
  );

  {** OpenType 特性设置 }
  TFontFeatureSetting = record
    Tag: UInt32;       // Feature tag (e.g., FEATURE_TAG_LIGA)
    Value: UInt32;     // 0 = disabled, 1 = enabled, 2+ = variant selector
  end;
  TFontFeatureSettingArray = array of TFontFeatureSetting;

  {** 字体特性配置 }
  TFontFeatureConfig = record
    Features: TFontFeatureSettingArray;
  end;

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
  end;

  {** post 表关键字段（参考 Ghostty post.zig） }
  TFontPostTable = record
    UnderlinePosition: Int16;    // 下划线顶部 y 坐标建议值
    UnderlineThickness: Int16;   // 下划线粗细建议值（0 = broken）
    IsFixedPitch: UInt32;        // 0=比例间距, 非0=等宽
  end;

  {** COLR 表颜色层（v0 格式） }
  TFontColrLayer = record
    GlyphId: UInt16;           // 层字形 ID
    PaletteIndex: UInt16;      // 调色板索引
  end;
  TFontColrLayerArray = array of TFontColrLayer;

  {** CPAL 表调色板颜色（BGRA 格式） }
  TFontCpalColor = record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Alpha: Byte;
  end;

  {** CBDT/CBLC 位图字形数据 }
  TFontBitmapGlyph = record
    Width: UInt16;             // 位图宽度（像素）
    Height: UInt16;            // 位图高度（像素）
    BearingX: Int16;           // 水平 bearing
    BearingY: Int16;           // 垂直 bearing
    Advance: UInt16;           // 步进宽度
    PngDataLength: Int32;      // PNG 数据字节数
    PngData: array of Byte;    // PNG 压缩数据
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

  {** cmap 格式 14 (IVS) — Variation Selector 映射 }
  TFontCmapFmt14DefaultUVSRange = record
    StartUnicodeValue: UInt32;  // 3 字节
    AdditionalCount: Byte;
  end;
  TFontCmapFmt14DefaultUVSRangeArray = array of TFontCmapFmt14DefaultUVSRange;

  TFontCmapFmt14UVSMapping = record
    UnicodeValue: UInt32;      // 3 字节
    GlyphID: UInt16;
  end;
  TFontCmapFmt14UVSMappingArray = array of TFontCmapFmt14UVSMapping;

  TFontCmapFmt14VarSelector = record
    VarSelector: UInt32;       // 3 字节，U+E0100-U+E01EF
    DefaultUVSRanges: TFontCmapFmt14DefaultUVSRangeArray;
    NonDefaultUVS: TFontCmapFmt14UVSMappingArray;
  end;
  TFontCmapFmt14VarSelectorArray = array of TFontCmapFmt14VarSelector;

  TFontCmapFmt14 = record
    VarSelectors: TFontCmapFmt14VarSelectorArray;
  end;

  {** name 表名称记录 }
  TFontNameRecord = record
    PlatformID: UInt16;
    EncodingID: UInt16;
    LanguageID: UInt16;
    NameID: UInt16;
    Value: AnsiString;       // UTF-8 解码后的值
  end;
  TFontNameRecordArray = array of TFontNameRecord;

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

  {** GPOS PairPos kern 子表 Format 1（逐对调整，查询时解析 PairSet） }
  TFontPairPosFmt1Subtable = record
    BaseOffset: Int32;       // 子表在文件中的偏移
    CoverageOffset: Int32;   // Coverage 表偏移（相对文件）
    PairSetCount: Int32;      // PairSet 数量（= coverage glyph 数）
    ValueRecordSize: Int32;  // 每条 PairValueRecord 的总字节数（VR1 + VR2）
    XAdvanceOffset: Int32;   // XAdvance 在 ValueRecord1 中的字节偏移（-1 = 无）
  end;
  TFontPairPosFmt1SubtableArray = array of TFontPairPosFmt1Subtable;

  {** GPOS SinglePos 子表（Format 1 uniform / Format 2 per-glyph） }
  TFontSinglePosSubtable = record
    BaseOffset: Int32;         // 子表在文件中的偏移
    CoverageOffset: Int32;     // Coverage 表偏移（相对文件）
    Format: UInt16;            // 1=uniform, 2=per-glyph array
    ValueRecordSize: Int32;    // 每条 ValueRecord 的字节数
    XAdvanceOffset: Int32;     // XAdvance 在 ValueRecord 中的字节偏移（-1 = 无）
    GlyphCount: Int32;         // Format 2: glyph count
    ValueArrayOffset: Int32;   // Format 1/2: ValueRecord 数据起始偏移（相对文件）
  end;
  TFontSinglePosSubtableArray = array of TFontSinglePosSubtable;

  {** GSUB 连字子表数据（查询时解析） }
  TFontLigatureSubtable = record
    BaseOffset: Int32;       // 子表在文件中的偏移
    CoverageOffset: Int32;   // Coverage 表偏移（相对文件）
    LigatureSetCount: Int32; // LigatureSet 数量
  end;
  TFontLigatureSubtableArray = array of TFontLigatureSubtable;

  {** GSUB Single Substitution 子表（Format 1 delta 或 Format 2 array） }
  TFontSingleSubstSubtable = record
    BaseOffset: Int32;       // 子表在文件中的偏移
    CoverageOffset: Int32;   // Coverage 表偏移（相对文件）
    Format: UInt16;          // 1=delta, 2=array
    DeltaGlyphID: Int16;    // Format 1: delta value
    GlyphCount: Int32;      // Format 2: substitute glyph count
    SubstituteArrayOffset: Int32; // Format 2: substitute glyph array offset（相对文件）
  end;
  TFontSingleSubstSubtableArray = array of TFontSingleSubstSubtable;

  {** Feature 相关 lookup 索引数组 }
  TFontFeatureLookupIndexArray = array of UInt16;
  TFontGlyphIdArray = array of UInt16;

  {** GPOS Anchor 表（X/Y 坐标，font units） }
  TFontAnchor = record
    X: Int16;
    Y: Int16;
  end;

  {** GPOS Mark-to-Base 子表（查询时解析 MarkArray + BaseArray） }
  TFontMarkToBaseSubtable = record
    BaseOffset: Int32;         // 子表在文件中的偏移
    MarkCoverageOffset: Int32; // Mark Coverage 表偏移（相对文件）
    BaseCoverageOffset: Int32; // Base Coverage 表偏移（相对文件）
    ClassCount: Int32;         // mark class 数量
    MarkArrayOffset: Int32;    // MarkArray 偏移（相对文件）
    BaseArrayOffset: Int32;    // BaseArray 偏移（相对文件）
  end;
  TFontMarkToBaseSubtableArray = array of TFontMarkToBaseSubtable;

  {** GPOS Mark-to-Mark 子表（结构同 Mark-to-Base，Mark1=base mark, Mark2=attaching mark） }
  TFontMarkToMarkSubtable = record
    BaseOffset: Int32;           // 子表在文件中的偏移
    Mark1CoverageOffset: Int32;  // Mark1 Coverage（base mark）偏移
    Mark2CoverageOffset: Int32;  // Mark2 Coverage（attaching mark）偏移
    ClassCount: Int32;           // mark class 数量
    Mark1ArrayOffset: Int32;     // Mark1Array 偏移（base mark anchors）
    Mark2ArrayOffset: Int32;     // Mark2Array 偏移（attaching mark class + anchor）
  end;
  TFontMarkToMarkSubtableArray = array of TFontMarkToMarkSubtable;

  {** GPOS Mark-to-Ligature 子表（MarkLigPos Format 1）
      结构同 Mark-to-Base，但 LigatureArray 中每个连字有多个组件锚点 }
  TFontMarkToLigSubtable = record
    BaseOffset: Int32;           // 子表在文件中的偏移
    MarkCoverageOffset: Int32;   // Mark Coverage 表偏移（相对文件）
    LigCoverageOffset: Int32;    // Ligature Coverage 表偏移（相对文件）
    ClassCount: Int32;           // mark class 数量
    MarkArrayOffset: Int32;      // MarkArray 偏移（相对文件）
    LigArrayOffset: Int32;       // LigatureArray 偏移（相对文件）
  end;
  TFontMarkToLigSubtableArray = array of TFontMarkToLigSubtable;

  {** GPOS CursivePos 子表（Format 1: Entry/Exit anchor pairs） }
  TFontCursivePosSubtable = record
    BaseOffset: Int32;           // 子表在文件中的偏移
    CoverageOffset: Int32;       // Coverage 表偏移（相对文件）
    EntryExitCount: Int32;       // EntryExitRecord 数量
    EntryExitArrayOffset: Int32; // EntryExitRecord 数组起始偏移（相对文件）
  end;
  TFontCursivePosSubtableArray = array of TFontCursivePosSubtable;

  {** GSUB MultipleSubst 子表（Format 1: 一对多替换） }
  TFontMultipleSubstSubtable = record
    BaseOffset: Int32;           // 子表在文件中的偏移
    CoverageOffset: Int32;       // Coverage 表偏移（相对文件）
    SequenceCount: Int32;        // SequenceTable 数量（= Coverage glyph 数量）
    SequenceArrayOffset: Int32;  // SequenceTable 偏移数组起始（相对文件）
                                 // 每个偏移(2 bytes)相对于子表起始
  end;
  TFontMultipleSubstSubtableArray = array of TFontMultipleSubstSubtable;

  {** GSUB AlternateSubst 子表（Format 1: 备选替换，结构同 MultipleSubst） }
  TFontAlternateSubstSubtable = record
    BaseOffset: Int32;           // 子表在文件中的偏移
    CoverageOffset: Int32;       // Coverage 表偏移（相对文件）
    AlternateSetCount: Int32;    // AlternateSet 数量
    AlternateSetArrayOffset: Int32; // AlternateSet 偏移数组起始（相对文件）
  end;
  TFontAlternateSubstSubtableArray = array of TFontAlternateSubstSubtable;

  {** GSUB ContextSubst/ChainedContextSubst 子表 — 存储 Format 1/2/3 数据 }
  TFontContextSubstSubtable = record
    BaseOffset: Int32;               // 子表在文件中的偏移
    Format: Int32;                   // 子表格式（1=glyph-based, 2=class-based, 3=coverage-based）
    InputGlyphCount: Int32;          // 匹配序列长度（Format 3 专用）
    SubstCount: Int32;              // Substitution 记录数（Format 3 专用）
    InputCoverageOffsets: array of Int32; // 每个输入位置的 Coverage 偏移（Format 3）
    SubstSeqIndices: array of UInt16;    // 每个 subst 的序列索引（Format 3）
    SubstLookupIndices: array of UInt16; // 每个 subst 的 lookup 索引（Format 3）
    RuleSetCount: Int32;             // RuleSet/ClassSeqRuleSet 数量（Format 1/2）
    RuleSetOffsets: array of Int32;  // 每个 RuleSet 的绝对文件偏移（Format 1/2，0=空）
    IsChained: Boolean;              // True = ChainedContext (有 backtrack/lookahead)
  end;
  TFontContextSubstSubtableArray = array of TFontContextSubstSubtable;

  {** Context 子表中的单条 lookup 记录（sequenceIndex + lookupIndex） }
  TFontContextLookupRecord = record
    SequenceIndex: UInt16;
    LookupIndex: UInt16;
  end;
  TFontContextLookupRecordArray = array of TFontContextLookupRecord;

{** 字形轮廓内存释放 }
procedure FontGlyphOutlineClear(var AOutline: TFontGlyphOutline);

{** 光栅化结果内存释放 }
procedure FontRasterResultClear(var AResult: TFontRasterResult);

{ ========================================================================= }
{ CFF2 可变字体支持                                                         }
{ ========================================================================= }

const
  {** CFF2 ItemVariationStore region indices count }
  CFF2_MAX_AXES = 16;       // OpenType 最多支持 16 个变化轴
  CFF2_MAX_REGIONS = 64;    // 实用上限：同一 VariationStore 中的区域数量

type
  {** CFF2 变化轴区域（一个 Region 的单轴范围，F2Dot14 格式） }
  TCff2VariationRegionAxis = record
    StartCoord: Int16;
    PeakCoord: Int16;
    EndCoord: Int16;
  end;

  {** CFF2 变化区域（一组轴范围，共同定义一个 "region"） }
  TCff2VariationRegion = record
    AxisCount: Int32;
    Axes: array[0..CFF2_MAX_AXES - 1] of TCff2VariationRegionAxis;
  end;
  TCff2VariationRegionArray = array of TCff2VariationRegion;

  {** CFF2 ItemVariationStore 解析结果（定义在 TItemVariationDataSubtableArray 之后） }
  // 注意：此类型使用了 TItemVariationDataSubtableArray，需要在该类型之后定义
  // 移至 TItemVariationStore 附近定义

  {** CFF2 顶层 DICT 基本数据 }
  TCff2TopDict = record
    CharStringsType: Int32;         // 通常 2 (Type 2)
    CharStringsOff: Int32;          // CharStrings INDEX 偏移
    FDArrayOff: Int32;              // Font DICT Array 偏移
    FDSelectOff: Int32;             // FDSelect 偏移
    TopDictSize: Int32;             // Top DICT 数据长度
    VStoreOff: Int32;               // ItemVariationStore 偏移（0=无）
    HasVStore: Boolean;
  end;

  {** CFF2 FDArray 中的单个 Font DICT }
  TCff2FontDict = record
    PrivateDictSize: Int32;
    PrivateDictOff: Int32;
    SubrsOff: Int32;
  end;
  TCff2FontDictArray = array of TCff2FontDict;

  {** fvar 变化轴（参考 Apple TrueType Reference / OpenType fvar） }
  TFontVariationAxis = record
    Tag: UInt32;           // 4 字节标识符（'wght', 'wdth', 'opsz', 'ital', 'slnt'）
    NameID: UInt16;        // name 表中的 nameID
    MinValue: Single;      // 轴最小值
    DefaultValue: Single;  // 轴默认值
    MaxValue: Single;      // 轴最大值
  end;
  TFontVariationAxisArray = array of TFontVariationAxis;

  {** fvar 命名实例 }
  TFontNamedInstance = record
    Flags: UInt16;         // 标志位（0x0001 = 不同的 PostScript nameID）
    NameID: UInt16;        // 实例名称的 nameID
    Coordinates: array of Single;  // 每个轴的坐标值
  end;
  TFontNamedInstanceArray = array of TFontNamedInstance;

  {** fvar 表解析结果 }
  TFontFvarTable = record
    AxisCount: UInt16;
    Axes: TFontVariationAxisArray;
    InstanceCount: UInt16;
    Instances: TFontNamedInstanceArray;
  end;

  {** avar 轴值映射对 (F2Dot14 格式) }
  TAvarAxisValueMap = record
    FromCoord: Int16;   // 默认归一化坐标 (F2Dot14)
    ToCoord: Int16;     // 修改后归一化坐标 (F2Dot14)
  end;
  TAvarAxisValueMapArray = array of TAvarAxisValueMap;

  {** avar 单轴的分段映射 }
  TAvarSegmentMap = record
    PairCount: Int32;
    Pairs: TAvarAxisValueMapArray;
  end;
  TAvarSegmentMapArray = array of TAvarSegmentMap;

  {** avar 表解析结果 }
  TAvarTable = record
    AxisCount: UInt16;
    Segments: TAvarSegmentMapArray;
  end;

  {** 通用 ItemVariationStore — 用于 HVAR/VVAR 等表 }
  TItemVariationDataSubtable = record
    ItemCount: UInt16;
    WordDeltaCount: UInt16;     // 含 LONG_WORDS 标志
    RegionIndexCount: UInt16;
    RegionIndices: array of UInt16;
    DeltaDataOffset: Int32;     // deltaSets 数据起始（绝对文件偏移）
    RowStride: Int32;           // 每行字节数
  end;
  TItemVariationDataSubtableArray = array of TItemVariationDataSubtable;

  TItemVariationStore = record
    AxisCount: UInt16;
    RegionCount: UInt16;
    Regions: TCff2VariationRegionArray;   // 复用已有类型
    DataCount: UInt16;
    DataSubtables: TItemVariationDataSubtableArray;
  end;

  {** CFF2 ItemVariationStore 解析结果（含 DataSubtable 区域索引） }
  TCff2ItemVariationStore = record
    Format: UInt16;           // 目前固定为 1
    RegionCount: UInt16;
    Regions: TCff2VariationRegionArray;
    DataCount: UInt16;
    DataSubtables: TItemVariationDataSubtableArray;
  end;

  {** HVAR 表解析结果 }
  THvarTable = record
    HasAdvWidthMapping: Boolean;          // 是否有 advance width 映射
    AdvWidthMapFormat: Byte;              // DeltaSetIndexMap format (0 or 1)
    AdvWidthMapEntrySize: Int32;          // 每条目字节数
    AdvWidthMapInnerBits: Int32;          // inner index 位数
    AdvWidthMapCount: Int32;              // 映射条目数
    AdvWidthMapDataOff: Int32;            // mapData 绝对偏移
    VariationStore: TItemVariationStore;
  end;

  {** VVAR 表（垂直度量变化）。
      结构和 HVAR 完全一致，但有 vrsb 和 vadv 两个 DeltaSetIndexMap。 }
  TVvarTable = record
    VariationStore: TItemVariationStore;
    HasVrsbMapping: Boolean;
    VrsbMapDataOff: Int32;
    VrsbMapFormat: Int32;
    VrsbMapEntrySize: Int32;
    VrsbMapInnerBits: Int32;
    VrsbMapCount: Int32;
    HasVadvMapping: Boolean;
    VadvMapDataOff: Int32;
    VadvMapFormat: Int32;
    VadvMapEntrySize: Int32;
    VadvMapInnerBits: Int32;
    VadvMapCount: Int32;
  end;

  {** gvar 共享 tuple 坐标（已从 F2Dot14 转为 16.16 Fixed） }
  TGvarSharedTuple = record
    Coords: array of Int32;               // length = axisCount
  end;
  TGvarSharedTupleArray = array of TGvarSharedTuple;

  {** gvar 表解析结果 }
  TGvarTable = record
    AxisCount: Int32;
    GlyphCount: Int32;
    SharedTupleCount: Int32;
    SharedTuples: TGvarSharedTupleArray;  // 共享 tuple 坐标（Fixed 16.16）
    GlyphOffsets: array of UInt32;        // glyphCount+1 个数据偏移（绝对）
    TableStart: UInt32;                   // gvar 表起始偏移
    TableSize: UInt32;                    // gvar 表大小（bounds check）
  end;

{** 创建默认特性配置（liga=1, kern=1） }
function FontFeatureConfigDefault: TFontFeatureConfig;
{** 检查特性是否启用 }
function FontFeatureIsEnabled(const AConfig: TFontFeatureConfig;
  ATag: UInt32): Boolean;
{** 获取特性的值（0 = 未找到/禁用） }
function FontFeatureGetValue(const AConfig: TFontFeatureConfig;
  ATag: UInt32): UInt32;
{** 解析特性字符串（如 "+liga", "-kern", "cv01=2"）。
    成功返回 True 并设置 ATag/AValue。失败返回 False。
    支持 Ghostty/HarfBuzz 风格语法：
    - "+tag" / "-tag" — 启用/禁用
    - "tag on" / "tag off" — 关键字
    - "tag=N" — 数值参数
    - 引号可选："'kern'" / "\"liga\"" }
function FontFeatureParseString(const AStr: AnsiString;
  out ATag: UInt32; out AValue: UInt32): Boolean;
{** 从 4 字节 ASCII tag 创建 UInt32（Big-Endian） }
function FontFeatureTagFromString(const ATag: AnsiString): UInt32;

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
  SetLength(Result.Features, 2);
  Result.Features[0].Tag := FEATURE_TAG_LIGA;
  Result.Features[0].Value := 1;
  Result.Features[1].Tag := FEATURE_TAG_KERN;
  Result.Features[1].Value := 1;
end;

function FontFeatureIsEnabled(const AConfig: TFontFeatureConfig;
  ATag: UInt32): Boolean;
begin
  Result := FontFeatureGetValue(AConfig, ATag) > 0;
end;

function FontFeatureGetValue(const AConfig: TFontFeatureConfig;
  ATag: UInt32): UInt32;
var
  I: Int32;
begin
  Result := 0;
  for I := 0 to High(AConfig.Features) do
    if AConfig.Features[I].Tag = ATag then
      Exit(AConfig.Features[I].Value);
end;

function FontFeatureTagFromString(const ATag: AnsiString): UInt32;
var
  LLen: Int32;
begin
  Result := 0;
  LLen := Length(ATag);
  if LLen >= 1 then Result := Result or (UInt32(Byte(ATag[1])) shl 24);
  if LLen >= 2 then Result := Result or (UInt32(Byte(ATag[2])) shl 16);
  if LLen >= 3 then Result := Result or (UInt32(Byte(ATag[3])) shl 8);
  if LLen >= 4 then Result := Result or UInt32(Byte(ATag[4]));
end;

function FontFeatureParseString(const AStr: AnsiString;
  out ATag: UInt32; out AValue: UInt32): Boolean;
var
  LI, LLen: Int32;
  LTagStr: AnsiString;
  LValStr: AnsiString;
  LState: (psStart, psTag, psValue, psDone);
  LByte: Byte;
  LVal: Int32;
  LSign: Int32;

  function TrimStr(const S: AnsiString): AnsiString;
  var
    LStart, LEnd: Int32;
  begin
    LStart := 1;
    LEnd := Length(S);
    while (LStart <= LEnd) and ((Byte(S[LStart]) = Ord(' ')) or (Byte(S[LStart]) = Ord(#9))) do
      Inc(LStart);
    while (LEnd >= LStart) and ((Byte(S[LEnd]) = Ord(' ')) or (Byte(S[LEnd]) = Ord(#9))) do
      Dec(LEnd);
    Result := Copy(S, LStart, LEnd - LStart + 1);
  end;

  function ParseInt(const S: AnsiString): Int32;
  var
    I: Int32;
  begin
    Result := 0;
    LSign := 1;
    I := 1;
    if (Length(S) > 0) and (Byte(S[1]) = Ord('-')) then
    begin
      LSign := -1;
      I := 2;
    end;
    while I <= Length(S) do
    begin
      if (Byte(S[I]) >= Ord('0')) and (Byte(S[I]) <= Ord('9')) then
        Result := Result * 10 + (Byte(S[I]) - Ord('0'))
      else
        Break;
      Inc(I);
    end;
    Result := Result * LSign;
  end;
begin
  Result := False;
  ATag := 0;
  AValue := 1; // 默认启用
  LLen := Length(AStr);
  if LLen = 0 then
    Exit;

  LTagStr := '';
  LValStr := '';
  LState := psStart;
  LI := 1;

  while LI <= LLen do
  begin
    LByte := Byte(AStr[LI]);

    case LState of
      psStart: begin
        // 跳过前导空白
        if (LByte = Ord(' ')) or (LByte = Ord(#9)) then
        begin
          Inc(LI);
          Continue;
        end;
        // '+' 前缀 = 启用
        if LByte = Ord('+') then
        begin
          AValue := 1;
          LState := psTag;
          Inc(LI);
          Continue;
        end;
        // '-' 前缀 = 禁用
        if LByte = Ord('-') then
        begin
          AValue := 0;
          LState := psTag;
          Inc(LI);
          Continue;
        end;
        // 引号开始
        if (LByte = Ord('''')) or (LByte = Ord('"')) then
        begin
          LState := psTag;
          Inc(LI);
          Continue;
        end;
        // 直接开始 tag
        LState := psTag;
        Continue;
      end;

      psTag: begin
        // 引号结束
        if (LByte = Ord('''')) or (LByte = Ord('"')) then
        begin
          LState := psValue;
          Inc(LI);
          Continue;
        end;
        // 空格 = tag 结束，进入值解析
        if (LByte = Ord(' ')) or (LByte = Ord(#9)) then
        begin
          LState := psValue;
          Inc(LI);
          Continue;
        end;
        // '=' = 值开始
        if LByte = Ord('=') then
        begin
          LState := psValue;
          Inc(LI);
          Continue;
        end;
        // 逗号或结束 = 完成
        if (LByte = Ord(',')) or (LI = LLen + 1) then
        begin
          if Length(LTagStr) >= 4 then
          begin
            ATag := FontFeatureTagFromString(LTagStr);
            Result := True;
          end;
          Exit;
        end;
        // 收集 tag 字符
        if Length(LTagStr) < 4 then
          LTagStr := LTagStr + AnsiString(Char(LByte));
        Inc(LI);
      end;

      psValue: begin
        // 跳过空白
        if (LByte = Ord(' ')) or (LByte = Ord(#9)) then
        begin
          Inc(LI);
          Continue;
        end;
        // 逗号或结束 = 完成
        if (LByte = Ord(',')) or (LI = LLen + 1) then
        begin
          if Length(LTagStr) >= 4 then
          begin
            ATag := FontFeatureTagFromString(LTagStr);
            // 解析值
            LValStr := TrimStr(LValStr);
            if (LValStr = 'on') or (LValStr = 'On') or (LValStr = 'ON') then
              AValue := 1
            else if (LValStr = 'off') or (LValStr = 'Off') or (LValStr = 'OFF') then
              AValue := 0
            else if Length(LValStr) > 0 then
            begin
              LVal := ParseInt(LValStr);
              if LVal <> 0 then
                AValue := UInt32(LVal);
            end;
            Result := True;
          end;
          Exit;
        end;
        // 收集值字符
        LValStr := LValStr + AnsiString(Char(LByte));
        Inc(LI);
      end;
    else
      Inc(LI);
    end;
  end;

  // 字符串结束，处理最后的 tag
  if (LState = psTag) and (Length(LTagStr) >= 4) then
  begin
    ATag := FontFeatureTagFromString(LTagStr);
    Result := True;
  end
  else if (LState = psValue) and (Length(LTagStr) >= 4) then
  begin
    ATag := FontFeatureTagFromString(LTagStr);
    LValStr := TrimStr(LValStr);
    if (LValStr = 'on') or (LValStr = 'On') or (LValStr = 'ON') then
      AValue := 1
    else if (LValStr = 'off') or (LValStr = 'Off') or (LValStr = 'OFF') then
      AValue := 0
    else if Length(LValStr) > 0 then
    begin
      LVal := ParseInt(LValStr);
      if LVal <> 0 then
        AValue := UInt32(LVal);
    end;
    Result := True;
  end;
end;

end.
