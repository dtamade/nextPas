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

  {** GPOS Lookup Type：Pair Adjustment（kern） }
  GPOS_LOOKUP_PAIR_ADJUSTMENT = 2;

  {** GSUB Lookup Type：Ligature Substitution }
  GSUB_LOOKUP_LIGATURE = 4;

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

end.
