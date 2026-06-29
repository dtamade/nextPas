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
    FCmapFmt14: TFontCmapFmt14;
    FHasFmt4: Boolean;
    FHasFmt12: Boolean;
    FHasFmt14: Boolean;
    FLocaOffsets: array of UInt32;
    FOs2: TFontOs2Table;
    FPairPosSubtables: TFontPairPosSubtableArray;
    FPairPosFmt1Subtables: TFontPairPosFmt1SubtableArray;
    FLigatureSubtables: TFontLigatureSubtableArray;
    FSingleSubstSubtables: TFontSingleSubstSubtableArray;
    FSinglePosSubtables: TFontSinglePosSubtableArray;
    FMarkToBaseSubtables: TFontMarkToBaseSubtableArray;
    FMarkToMarkSubtables: TFontMarkToMarkSubtableArray;
    FMarkToLigSubtables: TFontMarkToLigSubtableArray;
    FCursivePosSubtables: TFontCursivePosSubtableArray;
    FMultipleSubstSubtables: TFontMultipleSubstSubtableArray;
    FAlternateSubstSubtables: TFontAlternateSubstSubtableArray;
    FContextSubstSubtables: TFontContextSubstSubtableArray;
    FContextPosSubtables: TFontContextSubstSubtableArray;  // GPOS ContextPos + ChainedContextPos (same record layout)
    {** Feature-specific lookup indices }
    FKernLookups: TFontFeatureLookupIndexArray;     // GPOS 'kern'
    FMarkLookups: TFontFeatureLookupIndexArray;      // GPOS 'mark'
    FMkmkLookups: TFontFeatureLookupIndexArray;      // GPOS 'mkmk'
    FLigaLookups: TFontFeatureLookupIndexArray;      // GSUB 'liga'
    FCligLookups: TFontFeatureLookupIndexArray;      // GSUB 'clig'
    FCursLookups: TFontFeatureLookupIndexArray;      // GPOS 'curs'
    {** CFF 字体数据（OTF OpenType with CFF outlines） }
    FCffValid: Boolean;
    FCffOff: Int32;                    // CFF 表在文件中的偏移
    FCffCharStringsOff: Int32;        // CharStrings INDEX 偏移（相对 CFF 起始）
    FCffCharStringsCount: Int32;      // 字形数量
    FCffCharStringsOffSize: Int32;    // CharStrings INDEX offset size
    FCffCharStringsDataStart: Int32;  // CharStrings 数据起始（绝对文件偏移）
    FCffDefaultWidthX: Int32;         // DefaultWidthX（Private DICT）
    FCffNominalWidthX: Int32;         // NominalWidthX（Private DICT）
    {** CFF subroutine INDEX 数据 }
    FCffGlobalSubrIdxPos: Int32;      // Global Subr INDEX header 位置（绝对）
    FCffGlobalSubrCount: Int32;       // Global Subr 条目数量
    FCffLocalSubrIdxPos: Int32;       // Local Subr INDEX header 位置（绝对）
    FCffLocalSubrCount: Int32;        // Local Subr 条目数量
    FCffGlobalSubrBias: Int32;        // Global Subr 数字偏移
    FCffLocalSubrBias: Int32;         // Local Subr 数字偏移
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
    procedure ParseCff;
    function GlyphOutlineCff(AGlyphIndex: UInt32): TFontGlyphOutline;
    function ParseFeatureLookups(ATableOffset: Int32;
      const AFeatureTags: array of UInt32): TFontFeatureLookupIndexArray;
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
    {** 是否包含逐对 kern 数据（GPOS PairPos Fmt1） }
    function HasKernFmt1Pairs: Boolean;
    {** 是否包含连字数据（GSUB Ligature） }
    function HasLigatures: Boolean;
    {** 查找 kern 对调整值（font units，0 = 无调整）— class-based Fmt2 }
    function LookupKern(ALeftGlyph, ARightGlyph: UInt16): Int16;
    {** 查找 kern 对调整值（font units，0 = 无调整）— pair-based Fmt1 }
    function LookupKernFmt1(ALeftGlyph, ARightGlyph: UInt16): Int16;
    {** 查找连字替换。输入字形序列匹配时返回替换字形索引。
        不匹配返回 0。 }
    function LookupLigature(const AGlyphs: array of UInt16): UInt16;
    {** 是否包含单字形替换数据（GSUB Single） }
    function HasSingleSubst: Boolean;
    {** 查找单字形替换。AGlyphId 匹配 coverage 时返回替换字形索引。
        不匹配返回 0。 }
    function LookupSingleSubst(AGlyphId: UInt16): UInt16;

    {** 是否包含一对多替换数据（GSUB MultipleSubst） }
    function HasMultipleSubst: Boolean;
    {** 查找一对多替换。AGlyphId 匹配 coverage 时返回替换字形数量和 ID 数组。
        不匹配返回空数组。 }
    function LookupMultipleSubst(AGlyphId: UInt16): TFontGlyphIdArray;

    {** 是否包含备选替换数据（GSUB AlternateSubst） }
    function HasAlternateSubst: Boolean;
    {** 查找备选替换。AGlyphId 匹配 coverage 时返回备选字形数组。
        不匹配返回空数组。返回的数组可由调用方按需选择（如 stylistic set）。 }
    function LookupAlternateSubst(AGlyphId: UInt16): TFontGlyphIdArray;

    {** 是否包含规则匹配替换数据（GSUB ContextSubst + ChainedContextSubst） }
    function HasContextSubst: Boolean;
    {** 获取 ContextSubst 子表数量 }
    function ContextSubstCount: Int32;
    {** 获取指定索引的 ContextSubst 子表信息 }
    procedure GetContextSubstInfo(AIndex: Int32;
      out AInputGlyphCount, ASubstCount: Int32);
    {** 获取指定 ContextSubst 子表的输入 Coverage 偏移 }
    function GetContextSubstInputCoverage(AIndex, APosition: Int32): Int32;
    {** 获取指定 ContextSubst 子表的替换记录 }
    procedure GetContextSubstLookup(AIndex, ASubstIdx: Int32;
      out ASeqIndex: UInt16; out ALookupIndex: UInt16);
    {** 获取指定 ContextSubst 子表的格式（1/2/3） }
    function GetContextSubstFmt(AIndex: Int32): Int32;
    {** 获取指定 ContextSubst 子表的 RuleSet 数量（Format 1/2） }
    function GetContextSubstRuleSetCount(AIndex: Int32): Int32;
    {** 获取指定 ContextSubst 子表中指定首字形的 lookup 记录。
        Format 1/2: 通过 CoverageIndexOf 找到 rule set，解析规则中的 subst 记录。
        Format 3: 返回所有 subst 记录（首字形忽略）。 }
    function GetContextSubstForGlyph(AIndex: Int32;
      AFirstGlyph: UInt16): TFontContextLookupRecordArray;

    {** 是否包含规则匹配定位数据（GPOS ContextPos + ChainedContextPos） }
    function HasContextPos: Boolean;
    {** 获取 ContextPos 子表数量 }
    function ContextPosCount: Int32;
    {** 获取指定索引的 ContextPos 子表信息 }
    procedure GetContextPosInfo(AIndex: Int32;
      out AInputGlyphCount, APosCount: Int32);
    {** 获取指定 ContextPos 子表的输入 Coverage 偏移 }
    function GetContextPosInputCoverage(AIndex, APosition: Int32): Int32;
    {** 获取指定 ContextPos 子表的定位记录 }
    procedure GetContextPosLookup(AIndex, APosIdx: Int32;
      out ASeqIndex: UInt16; out ALookupIndex: UInt16);

    {** 是否包含单字形定位数据（GPOS SinglePos） }
    function HasSinglePos: Boolean;
    {** 查找单字形 XAdvance 调整。AGlyphId 匹配 coverage 时返回 XAdvance 偏移。
        不匹配返回 0。 }
    function LookupSinglePosXAdvance(AGlyphId: UInt16): Int16;
    {** 是否包含 Mark-to-Base 定位数据（GPOS MarkBasePos） }
    function HasMarkToBase: Boolean;
    {** 查找 Mark-to-Base 定位。AMarkGlyph 是 combining mark 的字形索引，
        ABaseGlyph 是 base 字形的索引。返回 mark 的 anchor 偏移
        （相对于 base 的 anchor）。未匹配时返回 X=0,Y=0。 }
    function LookupMarkToBase(AMarkGlyph, ABaseGlyph: UInt16): TFontAnchor;
    {** 是否包含 Mark-to-Mark 定位数据（GPOS MarkMarkPos） }
    function HasMarkToMark: Boolean;
    {** 查找 Mark-to-Mark 定位。AMarkGlyph 是 attaching mark，ABaseMarkGlyph 是 base mark。
        返回 attaching mark 的 anchor 偏移。未匹配时返回 X=0,Y=0。 }
    function LookupMarkToMark(AMarkGlyph, ABaseMarkGlyph: UInt16): TFontAnchor;

    {** GPOS MarkLigPos 是否有子表 }
    function HasMarkToLig: Boolean;
    {** 查找 Mark-to-Ligature 定位。AMarkGlyph 是 combining mark，
        ALigGlyph 是连字字形，AComponentIdx 是组件索引（0=第一个组件）。
        返回 mark 的 anchor 偏移。未匹配时返回 X=0,Y=0。 }
    function LookupMarkToLig(AMarkGlyph, ALigGlyph: UInt16;
      AComponentIdx: Int32): TFontAnchor;

    {** GPOS CursivePos 是否有子表 }
    function HasCursivePos: Boolean;
    {** 查找 CursivePos ExitAnchor（字形 A 的出口锚点）。
        AGlyphId 是前一个字形，返回其 exit anchor 的 X/Y 偏移。
        未匹配时返回 X=0,Y=0。 }
    function LookupCursivePosExitAnchor(AGlyphId: UInt16): TFontAnchor;
    {** 查找 CursivePos EntryAnchor（字形 B 的入口锚点）。
        AGlyphId 是后一个字形，返回其 entry anchor 的 X/Y 偏移。
        未匹配时返回 X=0,Y=0。 }
    function LookupCursivePosEntryAnchor(AGlyphId: UInt16): TFontAnchor;

    {** GPOS 是否声明了 'kern' feature（PairPos lookups 受此控制） }
    function HasFeatureKern: Boolean;
    {** GPOS 是否声明了 'mark' feature（MarkBasePos lookups 受此控制） }
    function HasFeatureMark: Boolean;
    {** GPOS 是否声明了 'mkmk' feature（MarkMarkPos lookups 受此控制） }
    function HasFeatureMkmk: Boolean;
    {** GSUB 是否声明了 'liga' feature（Ligature lookups 受此控制） }
    function HasFeatureLiga: Boolean;
    {** GSUB 是否声明了 'clig' feature（Contextual Ligature lookups 受此控制） }
    function HasFeatureClig: Boolean;
    {** GPOS 是否声明了 'curs' feature（CursivePos lookups 受此控制） }
    function HasFeatureCurs: Boolean;

    {** 是否包含 cmap Format 14 (IVS) 数据 }
    function HasFmt14: Boolean;
    {** 查找 IVS (Ideographic Variation Selector) 字形。
        ACodepoint 是基础字码（如 U+845B），AVariationSelector 是 VS（如 U+E0100）。
        返回字形索引。未匹配返回 0（使用默认字形）。
        - Non-Default UVS: 精确匹配返回指定 glyphID
        - Default UVS: 范围匹配返回 0（表示使用默认字形）
        - 无此 VS: 返回 0 }
    function LookupIVS(ACodepoint, AVariationSelector: UInt32): UInt32;
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
  FHasFmt14 := False;
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
    if not (FFormat in [fffTrueType, fffOpenTypeCff]) then
      Exit;
    ParseTableDirectory;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseCmap;
    if FFormat = fffTrueType then
      ParseLoca;
    ParseHmtx;
    ParseOs2;
    if FFormat = fffOpenTypeCff then
    begin
      try
        ParseCff;
      except
      end;
    end;
    try
      ParseGpos;
    except
    end;
    try
      ParseGsub;
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
  FHasFmt14 := False;
  FLastError := '';

  LLen := Length(AData);
  if LLen < 12 then
    Exit;

  SetLength(FData, LLen);
  FDataLength := LLen;
  Move(AData[0], FData[0], LLen);

  try
    ParseHeader;
    if not (FFormat in [fffTrueType, fffOpenTypeCff]) then
      Exit;
    ParseTableDirectory;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseCmap;
    if FFormat = fffTrueType then
      ParseLoca;
    ParseHmtx;
    ParseOs2;
    if FFormat = fffOpenTypeCff then
    begin
      try
        ParseCff;
      except
      end;
    end;
    try
      ParseGpos;
    except
    end;
    try
      ParseGsub;
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
  LFmt14Length, LNumVarSelectors: UInt32;
  LVarSelectorIdx, LDefaultUVSOff, LNonDefaultUVSOff: UInt32;
  LNumDefaultRanges, LNumNonDefaultMappings: UInt32;
  M: Int32;
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

    // Format 14（IVS — Variation Selector）
    if (LFormat = CMAP_FORMAT_14) and (not FHasFmt14) then
    begin
      LFmt14Length := ReadUInt32BE(LSubtableBase + 2);
      LNumVarSelectors := ReadUInt32BE(LSubtableBase + 6);
      if (LNumVarSelectors > 0) and (LNumVarSelectors < 1024) then
      begin
        SetLength(FCmapFmt14.VarSelectors, LNumVarSelectors);
        for M := 0 to Int32(LNumVarSelectors) - 1 do
        begin
          // 每条记录：varSelector(3) + defaultUVSOffset(4) + nonDefaultUVSOffset(4) = 11 bytes
          J := LSubtableBase + 10 + M * 11;
          FCmapFmt14.VarSelectors[M].VarSelector :=
            (ReadUInt8(J) shl 16) or (ReadUInt8(J + 1) shl 8) or ReadUInt8(J + 2);
          LDefaultUVSOff := ReadUInt32BE(J + 3);
          LNonDefaultUVSOff := ReadUInt32BE(J + 7);

          // Default UVS Table
          if LDefaultUVSOff > 0 then
          begin
            LNumDefaultRanges := ReadUInt32BE(LSubtableBase + LDefaultUVSOff);
            if LNumDefaultRanges < 65536 then
            begin
              SetLength(FCmapFmt14.VarSelectors[M].DefaultUVSRanges, LNumDefaultRanges);
              for K := 0 to Int32(LNumDefaultRanges) - 1 do
              begin
                LVarSelectorIdx := LSubtableBase + LDefaultUVSOff + 4 + K * 4;
                FCmapFmt14.VarSelectors[M].DefaultUVSRanges[K].StartUnicodeValue :=
                  (ReadUInt8(LVarSelectorIdx) shl 16) or
                  (ReadUInt8(LVarSelectorIdx + 1) shl 8) or
                  ReadUInt8(LVarSelectorIdx + 2);
                FCmapFmt14.VarSelectors[M].DefaultUVSRanges[K].AdditionalCount :=
                  ReadUInt8(LVarSelectorIdx + 3);
              end;
            end;
          end;

          // Non-Default UVS Table
          if LNonDefaultUVSOff > 0 then
          begin
            LNumNonDefaultMappings := ReadUInt32BE(LSubtableBase + LNonDefaultUVSOff);
            if LNumNonDefaultMappings < 65536 then
            begin
              SetLength(FCmapFmt14.VarSelectors[M].NonDefaultUVS, LNumNonDefaultMappings);
              for K := 0 to Int32(LNumNonDefaultMappings) - 1 do
              begin
                LVarSelectorIdx := LSubtableBase + LNonDefaultUVSOff + 4 + K * 5;
                FCmapFmt14.VarSelectors[M].NonDefaultUVS[K].UnicodeValue :=
                  (ReadUInt8(LVarSelectorIdx) shl 16) or
                  (ReadUInt8(LVarSelectorIdx + 1) shl 8) or
                  ReadUInt8(LVarSelectorIdx + 2);
                FCmapFmt14.VarSelectors[M].NonDefaultUVS[K].GlyphID :=
                  ReadUInt16BE(LVarSelectorIdx + 3);
              end;
            end;
          end;
        end;
        FHasFmt14 := True;
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
  LIdx, LOff: Int32;
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

  if Int32(FTables[LIdx].Length) >= 96 then
  begin
    FOs2.SxHeight := ReadInt16BE(LOff + 86);
    FOs2.SCapHeight := ReadInt16BE(LOff + 88);
  end;
end;

{ ========================================================================= }
{ Feature List 解析                                                         }
{ ========================================================================= }

function TTFontFace.ParseFeatureLookups(ATableOffset: Int32;
  const AFeatureTags: array of UInt32): TFontFeatureLookupIndexArray;
var
  LFeatListOff, LFeatCount, LI, LJ, LK: Int32;
  LFeatTag, LFeatOff, LLookupCount, LLookupIdx: Int32;
  LMatch, LAlready: Boolean;
  LCapacity: Int32;
begin
  SetLength(Result, 0);
  LCapacity := 0;
  if FDataLength < ATableOffset + 10 then
    Exit;
  LFeatListOff := ATableOffset + ReadUInt16BE(ATableOffset + 6);
  if LFeatListOff = ATableOffset then
    Exit; // No feature list.
  if FDataLength < LFeatListOff + 2 then
    Exit;
  LFeatCount := ReadUInt16BE(LFeatListOff);
  for LI := 0 to LFeatCount - 1 do
  begin
    if FDataLength < LFeatListOff + 2 + LI * 6 + 8 then
      Continue;
    LFeatTag := ReadUInt32BE(LFeatListOff + 2 + LI * 6);
    // Check if this feature tag matches any of the requested tags.
    LMatch := False;
    for LJ := 0 to High(AFeatureTags) do
      if LFeatTag = AFeatureTags[LJ] then
      begin
        LMatch := True;
        Break;
      end;
    if not LMatch then
      Continue;
    // Read the Feature table and collect lookup indices.
    LFeatOff := LFeatListOff + ReadUInt16BE(LFeatListOff + 2 + LI * 6 + 4);
    if FDataLength < LFeatOff + 4 then
      Continue;
    LLookupCount := ReadUInt16BE(LFeatOff + 2);
    for LJ := 0 to LLookupCount - 1 do
    begin
      if FDataLength < LFeatOff + 4 + LJ * 2 + 2 then
        Continue;
      LLookupIdx := ReadUInt16BE(LFeatOff + 4 + LJ * 2);
      // Add if not already present (dedup).
      LAlready := False;
      for LK := 0 to High(Result) do
        if Result[LK] = LLookupIdx then
        begin
          LAlready := True;
          Break;
        end;
      if not LAlready then
      begin
        LCapacity := Length(Result) + 1;
        SetLength(Result, LCapacity);
        Result[LCapacity - 1] := LLookupIdx;
      end;
    end;
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
  LSubOff, LSub, LPosFmt, LCovOff, LValFmt1, LValFmt2: Int32;
  LEntrySize, LXAdvBit, LIdx, LEECount: Int32;
  LLookupOffOrig: Int32;
  LLSCount, LK, LCtxIdx, LSubFmt: Int32;
  LSubtable: TFontPairPosSubtable;
  LSinglePos: TFontSinglePosSubtable;
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
  SetLength(FPairPosFmt1Subtables, 0);
  SetLength(FSinglePosSubtables, 0);
  SetLength(FMarkToBaseSubtables, 0);
  SetLength(FMarkToMarkSubtables, 0);
  SetLength(FCursivePosSubtables, 0);
  SetLength(FMarkToLigSubtables, 0);
  SetLength(FContextPosSubtables, 0);
  // Parse GPOS feature list for kern/mark/mkmk/curs features.
  FKernLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_KERN]);
  FMarkLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_MARK]);
  FMkmkLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_MKMK]);
  FCursLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_CURS]);

  for LI := 0 to LLookupCount - 1 do
  begin
    if FDataLength < LLookupListOff + 4 + LI * 2 then
      Continue;
    LLookupOff := LLookupListOff + ReadUInt16BE(LLookupListOff + 2 + LI * 2);
    if FDataLength < LLookupOff + 6 then
      Continue;
    LLookupType := ReadUInt16BE(LLookupOff);
    LLookupOffOrig := LLookupOff;

    // ExtensionPos (type 9): unwrap to actual lookup type + subtable offset.
    if LLookupType = GPOS_LOOKUP_EXTENSION then
    begin
      if FDataLength < LLookupOff + 12 then
        Continue;
      LLookupType := ReadUInt16BE(LLookupOff + 6);
      LLookupOff := LLookupOff + ReadUInt32BE(LLookupOff + 8);
    end;

    // SinglePos (type 1).
    if LLookupType = GPOS_LOOKUP_SINGLE_POS then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 8 then
          Continue;
        LPosFmt := ReadUInt16BE(LSub);
        LCovOff := ReadUInt16BE(LSub + 2);
        LValFmt1 := ReadUInt16BE(LSub + 4);
        LXAdvBit := -1;
        LEntrySize := 0;
        if (LValFmt1 and $0001) <> 0 then Inc(LEntrySize, 2);
        if (LValFmt1 and $0002) <> 0 then Inc(LEntrySize, 2);
        if (LValFmt1 and $0004) <> 0 then begin LXAdvBit := LEntrySize; Inc(LEntrySize, 2); end;
        if (LValFmt1 and $0008) <> 0 then Inc(LEntrySize, 2);
        if (LEntrySize <= 0) or (LXAdvBit < 0) then
          Continue;
        LSinglePos.BaseOffset := LSub;
        LSinglePos.CoverageOffset := LSub + LCovOff;
        LSinglePos.Format := LPosFmt;
        LSinglePos.ValueRecordSize := LEntrySize;
        LSinglePos.XAdvanceOffset := LXAdvBit;
        if LPosFmt = 1 then
        begin
          LSinglePos.GlyphCount := 0;
          LSinglePos.ValueArrayOffset := LSub + 6;
        end
        else if LPosFmt = 2 then
        begin
          if FDataLength < LSub + 8 then
            Continue;
          LSinglePos.GlyphCount := ReadUInt16BE(LSub + 6);
          LSinglePos.ValueArrayOffset := LSub + 8;
        end
        else
          Continue;
        LIdx := Length(FSinglePosSubtables);
        SetLength(FSinglePosSubtables, LIdx + 1);
        FSinglePosSubtables[LIdx] := LSinglePos;
      end;
    end;

    // PairPos (type 1 — pair-based, type 2 — class-based).
    if LLookupType = GPOS_LOOKUP_PAIR_ADJUSTMENT then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 10 then
          Continue;
        LPosFmt := ReadUInt16BE(LSub);
        LCovOff := ReadUInt16BE(LSub + 2);
        LValFmt1 := ReadUInt16BE(LSub + 4);
        LValFmt2 := ReadUInt16BE(LSub + 6);

        // Compute VR1 size and XAdvance offset within VR1.
        LXAdvBit := -1;
        LEntrySize := 0;
        if (LValFmt1 and $0001) <> 0 then Inc(LEntrySize, 2);
        if (LValFmt1 and $0002) <> 0 then Inc(LEntrySize, 2);
        if (LValFmt1 and $0004) <> 0 then begin LXAdvBit := LEntrySize; Inc(LEntrySize, 2); end;
        if (LValFmt1 and $0008) <> 0 then Inc(LEntrySize, 2);
        if (LEntrySize <= 0) or (LXAdvBit < 0) then
          Continue;

        if LPosFmt = 1 then
        begin
          // Format 1: Pair-based adjustment.
          // PairValueRecord = SecondGlyph(2) + VR1 + VR2.
          // Add VR2 size to get full record size.
          LIdx := LEntrySize;  // VR1 size.
          if (LValFmt2 and $0001) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0002) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0004) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0008) <> 0 then Inc(LEntrySize, 2);
          if FDataLength < LSub + 10 then
            Continue;
          LIdx := Length(FPairPosFmt1Subtables);
          SetLength(FPairPosFmt1Subtables, LIdx + 1);
          FPairPosFmt1Subtables[LIdx].BaseOffset := LSub;
          FPairPosFmt1Subtables[LIdx].CoverageOffset := LSub + LCovOff;
          FPairPosFmt1Subtables[LIdx].PairSetCount := ReadUInt16BE(LSub + 8);
          FPairPosFmt1Subtables[LIdx].ValueRecordSize := LEntrySize;
          FPairPosFmt1Subtables[LIdx].XAdvanceOffset := LXAdvBit;
        end
        else if LPosFmt = 2 then
        begin
          // Format 2: Class-based adjustment.
          // Class2Record = VR1 + VR2 (no SecondGlyph prefix).
          if FDataLength < LSub + 16 then
            Continue;
          // Add VR2 size to get full Class2Record size.
          if (LValFmt2 and $0001) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0002) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0004) <> 0 then Inc(LEntrySize, 2);
          if (LValFmt2 and $0008) <> 0 then Inc(LEntrySize, 2);
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
        end;
      end;
    end;

    // CursivePos (type 3): cursive attachment (entry/exit anchors).
    if LLookupType = GPOS_LOOKUP_CursivePos then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        if FDataLength < LSubOff + 6 then
          Continue;
        LSub := LSubOff;
        if ReadUInt16BE(LSub) <> 1 then
          Continue;
        LEECount := ReadUInt16BE(LSub + 4);
        LIdx := Length(FCursivePosSubtables);
        SetLength(FCursivePosSubtables, LIdx + 1);
        FCursivePosSubtables[LIdx].BaseOffset := LSub;
        FCursivePosSubtables[LIdx].CoverageOffset := LSub + ReadUInt16BE(LSub + 2);
        FCursivePosSubtables[LIdx].EntryExitCount := LEECount;
        FCursivePosSubtables[LIdx].EntryExitArrayOffset := LSub + 6;
      end;
    end;

    // MarkBasePos (type 4).
    if LLookupType = GPOS_LOOKUP_MARK_TO_BASE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        if FDataLength < LSubOff + 12 then
          Continue;
        LSub := LSubOff;
        if ReadUInt16BE(LSub) <> 1 then
          Continue;
        LIdx := Length(FMarkToBaseSubtables);
        SetLength(FMarkToBaseSubtables, LIdx + 1);
        FMarkToBaseSubtables[LIdx].BaseOffset := LSub;
        FMarkToBaseSubtables[LIdx].MarkCoverageOffset := LSub + ReadUInt16BE(LSub + 2);
        FMarkToBaseSubtables[LIdx].BaseCoverageOffset := LSub + ReadUInt16BE(LSub + 4);
        FMarkToBaseSubtables[LIdx].ClassCount := ReadUInt16BE(LSub + 6);
        FMarkToBaseSubtables[LIdx].MarkArrayOffset := LSub + ReadUInt16BE(LSub + 8);
        FMarkToBaseSubtables[LIdx].BaseArrayOffset := LSub + ReadUInt16BE(LSub + 10);
      end;
    end;

    // MarkLigPos (type 5): mark-to-ligature attachment.
    // Structure: posFormat(2) + markCoverage(2) + ligCoverage(2) +
    //            classCount(2) + markArray(2) + ligArray(2).
    if LLookupType = GPOS_LOOKUP_MARK_TO_LIGATURE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        if FDataLength < LSubOff + 14 then
          Continue;
        LSub := LSubOff;
        if ReadUInt16BE(LSub) <> 1 then
          Continue;
        LIdx := Length(FMarkToLigSubtables);
        SetLength(FMarkToLigSubtables, LIdx + 1);
        FMarkToLigSubtables[LIdx].BaseOffset := LSub;
        FMarkToLigSubtables[LIdx].MarkCoverageOffset := LSub + ReadUInt16BE(LSub + 2);
        FMarkToLigSubtables[LIdx].LigCoverageOffset := LSub + ReadUInt16BE(LSub + 4);
        FMarkToLigSubtables[LIdx].ClassCount := ReadUInt16BE(LSub + 6);
        FMarkToLigSubtables[LIdx].MarkArrayOffset := LSub + ReadUInt16BE(LSub + 8);
        FMarkToLigSubtables[LIdx].LigArrayOffset := LSub + ReadUInt16BE(LSub + 10);
      end;
    end;

    // MarkMarkPos (type 6).
    if LLookupType = GPOS_LOOKUP_MARK_TO_MARK then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        if FDataLength < LSubOff + 12 then
          Continue;
        LSub := LSubOff;
        if ReadUInt16BE(LSub) <> 1 then
          Continue;
        LIdx := Length(FMarkToMarkSubtables);
        SetLength(FMarkToMarkSubtables, LIdx + 1);
        FMarkToMarkSubtables[LIdx].BaseOffset := LSub;
        FMarkToMarkSubtables[LIdx].Mark1CoverageOffset := LSub + ReadUInt16BE(LSub + 2);
        FMarkToMarkSubtables[LIdx].Mark2CoverageOffset := LSub + ReadUInt16BE(LSub + 4);
        FMarkToMarkSubtables[LIdx].ClassCount := ReadUInt16BE(LSub + 6);
        FMarkToMarkSubtables[LIdx].Mark1ArrayOffset := LSub + ReadUInt16BE(LSub + 8);
        FMarkToMarkSubtables[LIdx].Mark2ArrayOffset := LSub + ReadUInt16BE(LSub + 10);
      end;
    end;

    // ContextPos (type 7) and ChainedContextPos (type 8).
    // Parses Format 1 (glyph-based), Format 2 (class-based), Format 3 (coverage-based).
    if (LLookupType = GPOS_LOOKUP_CONTEXT_POS) or
       (LLookupType = GPOS_LOOKUP_CONTEXT_POS_CHAINED) then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        if LSubFmt = 3 then
        begin
          if LLookupType = GPOS_LOOKUP_CONTEXT_POS then
          begin
            // ContextPos Fmt3: format(2) + posCount(2) + posLookupCount(2) +
            //   inputCoverages[posCount](2) + posLookupRecords[posLookupCount](4).
            if FDataLength < LSub + 6 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 2);  // posCount (input glyph count)
            LIdx := ReadUInt16BE(LSub + 4);       // posLookupRecordCount
            if FDataLength < LSub + 6 + LLSCount * 2 + LIdx * 4 then
              Continue;
            LCtxIdx := Length(FContextPosSubtables);
            SetLength(FContextPosSubtables, LCtxIdx + 1);
            FContextPosSubtables[LCtxIdx].BaseOffset := LSub;
            FContextPosSubtables[LCtxIdx].Format := 3;
            FContextPosSubtables[LCtxIdx].IsChained := False;
            FContextPosSubtables[LCtxIdx].InputGlyphCount := LLSCount;
            FContextPosSubtables[LCtxIdx].SubstCount := LIdx;
            SetLength(FContextPosSubtables[LCtxIdx].InputCoverageOffsets, LLSCount);
            SetLength(FContextPosSubtables[LCtxIdx].SubstSeqIndices, LIdx);
            SetLength(FContextPosSubtables[LCtxIdx].SubstLookupIndices, LIdx);
            for LK := 0 to LLSCount - 1 do
              FContextPosSubtables[LCtxIdx].InputCoverageOffsets[LK] :=
                LSub + ReadUInt16BE(LSub + 6 + LK * 2);
            for LK := 0 to LIdx - 1 do
            begin
              FContextPosSubtables[LCtxIdx].SubstSeqIndices[LK] :=
                ReadUInt16BE(LSub + 6 + LLSCount * 2 + LK * 4);
              FContextPosSubtables[LCtxIdx].SubstLookupIndices[LK] :=
                ReadUInt16BE(LSub + 6 + LLSCount * 2 + LK * 4 + 2);
            end;
          end
          else
          begin
            // ChainedContextPos Fmt3: same structure as ChainedContextSubst Fmt3.
            if FDataLength < LSub + 4 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 2);
            LK := LSub + 4 + LLSCount * 2;
            if FDataLength < LK + 2 then
              Continue;
            LLSCount := ReadUInt16BE(LK);
            LK := LK + 2 + LLSCount * 2;
            if FDataLength < LK + 2 then
              Continue;
            LCovOff := ReadUInt16BE(LK);
            LK := LK + 2 + LCovOff * 2;
            if FDataLength < LK + 2 then
              Continue;
            LIdx := ReadUInt16BE(LK);
            if FDataLength < LK + 2 + LIdx * 4 then
              Continue;
            LCtxIdx := Length(FContextPosSubtables);
            SetLength(FContextPosSubtables, LCtxIdx + 1);
            FContextPosSubtables[LCtxIdx].BaseOffset := LSub;
            FContextPosSubtables[LCtxIdx].Format := 3;
            FContextPosSubtables[LCtxIdx].IsChained := True;
            FContextPosSubtables[LCtxIdx].InputGlyphCount := LLSCount;
            FContextPosSubtables[LCtxIdx].SubstCount := LIdx;
            SetLength(FContextPosSubtables[LCtxIdx].InputCoverageOffsets, LLSCount);
            SetLength(FContextPosSubtables[LCtxIdx].SubstSeqIndices, LIdx);
            SetLength(FContextPosSubtables[LCtxIdx].SubstLookupIndices, LIdx);
            for LCovOff := 0 to LLSCount - 1 do
              FContextPosSubtables[LCtxIdx].InputCoverageOffsets[LCovOff] :=
                LSub + ReadUInt16BE(LK - 2 - (LLSCount - LCovOff) * 2);
            for LCovOff := 0 to LIdx - 1 do
            begin
              FContextPosSubtables[LCtxIdx].SubstSeqIndices[LCovOff] :=
                ReadUInt16BE(LK + 2 + LCovOff * 4);
              FContextPosSubtables[LCtxIdx].SubstLookupIndices[LCovOff] :=
                ReadUInt16BE(LK + 2 + LCovOff * 4 + 2);
            end;
          end;
        end
        else if (LSubFmt = 1) or (LSubFmt = 2) then
        begin
          // Same structure as GSUB ContextSubst/ChainedContextSubst Fmt1/2.
          if LSubFmt = 1 then
          begin
            if FDataLength < LSub + 6 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 4);
            if FDataLength < LSub + 6 + LLSCount * 2 then
              Continue;
            LCtxIdx := Length(FContextPosSubtables);
            SetLength(FContextPosSubtables, LCtxIdx + 1);
            FContextPosSubtables[LCtxIdx].BaseOffset := LSub;
            FContextPosSubtables[LCtxIdx].Format := 1;
            FContextPosSubtables[LCtxIdx].IsChained := (LLookupType = GPOS_LOOKUP_CONTEXT_POS_CHAINED);
            FContextPosSubtables[LCtxIdx].RuleSetCount := LLSCount;
            SetLength(FContextPosSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
            for LK := 0 to LLSCount - 1 do
            begin
              LCovOff := ReadUInt16BE(LSub + 6 + LK * 2);
              if LCovOff <> 0 then
                FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
              else
                FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
            end;
          end
          else
          begin
            if LLookupType = GPOS_LOOKUP_CONTEXT_POS then
            begin
              if FDataLength < LSub + 8 then
                Continue;
              LLSCount := ReadUInt16BE(LSub + 6);
              if FDataLength < LSub + 8 + LLSCount * 2 then
                Continue;
              LCtxIdx := Length(FContextPosSubtables);
              SetLength(FContextPosSubtables, LCtxIdx + 1);
              FContextPosSubtables[LCtxIdx].BaseOffset := LSub;
              FContextPosSubtables[LCtxIdx].Format := 2;
              FContextPosSubtables[LCtxIdx].IsChained := False;
              FContextPosSubtables[LCtxIdx].RuleSetCount := LLSCount;
              SetLength(FContextPosSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
              for LK := 0 to LLSCount - 1 do
              begin
                LCovOff := ReadUInt16BE(LSub + 8 + LK * 2);
                if LCovOff <> 0 then
                  FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
                else
                  FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
              end;
            end
            else
            begin
              if FDataLength < LSub + 12 then
                Continue;
              LLSCount := ReadUInt16BE(LSub + 10);
              if FDataLength < LSub + 12 + LLSCount * 2 then
                Continue;
              LCtxIdx := Length(FContextPosSubtables);
              SetLength(FContextPosSubtables, LCtxIdx + 1);
              FContextPosSubtables[LCtxIdx].BaseOffset := LSub;
              FContextPosSubtables[LCtxIdx].Format := 2;
              FContextPosSubtables[LCtxIdx].IsChained := True;
              FContextPosSubtables[LCtxIdx].RuleSetCount := LLSCount;
              SetLength(FContextPosSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
              for LK := 0 to LLSCount - 1 do
              begin
                LCovOff := ReadUInt16BE(LSub + 12 + LK * 2);
                if LCovOff <> 0 then
                  FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
                else
                  FContextPosSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TTFontFace.ParseGsub;
var
  LTableIdx, LGsubOff: Int32;
  LLookupListOff, LLookupCount, LI, LJ: Int32;
  LLookupOff, LLookupType, LSubtableCount: Int32;
  LSubOff, LSub, LSubFmt, LCovOff, LLSCount, LIdx: Int32;
  LLookupOffOrig, LK, LCtxIdx: Int32;
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
  SetLength(FMultipleSubstSubtables, 0);
  SetLength(FAlternateSubstSubtables, 0);
  SetLength(FContextSubstSubtables, 0);
  // Parse GSUB feature list for liga/clig features.
  FLigaLookups := ParseFeatureLookups(LGsubOff,
    [FEATURE_TAG_LIGA]);
  FCligLookups := ParseFeatureLookups(LGsubOff,
    [FEATURE_TAG_CLIG]);

  for LI := 0 to LLookupCount - 1 do
  begin
    if FDataLength < LLookupListOff + 4 + LI * 2 then
      Continue;
    LLookupOff := LLookupListOff + ReadUInt16BE(LLookupListOff + 2 + LI * 2);
    if FDataLength < LLookupOff + 6 then
      Continue;
    LLookupType := ReadUInt16BE(LLookupOff);
    LLookupOffOrig := LLookupOff;

    // ExtensionSubst (type 7): unwrap to actual lookup type + subtable offset.
    if LLookupType = GSUB_LOOKUP_EXTENSION then
    begin
      if FDataLength < LLookupOff + 12 then
        Continue;
      LLookupType := ReadUInt16BE(LLookupOff + 6);
      LLookupOff := LLookupOff + ReadUInt32BE(LLookupOff + 8);
    end;

    // Single Substitution (type 1).
    if LLookupType = GSUB_LOOKUP_SINGLE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        LCovOff := ReadUInt16BE(LSub + 2);
        // Format 1: delta substitution.
        if LSubFmt = 1 then
        begin
          if FDataLength < LSub + 6 then
            Continue;
          LSingleSubst.BaseOffset := LSub;
          LSingleSubst.CoverageOffset := LSub + LCovOff;
          LSingleSubst.Format := 1;
          LSingleSubst.DeltaGlyphID := ReadInt16BE(LSub + 4);
          LSingleSubst.GlyphCount := 0;
          LSingleSubst.SubstituteArrayOffset := 0;
          LIdx := Length(FSingleSubstSubtables);
          SetLength(FSingleSubstSubtables, LIdx + 1);
          FSingleSubstSubtables[LIdx] := LSingleSubst;
        end
        // Format 2: array substitution.
        else if LSubFmt = 2 then
        begin
          if FDataLength < LSub + 8 then
            Continue;
          LSingleSubst.BaseOffset := LSub;
          LSingleSubst.CoverageOffset := LSub + LCovOff;
          LSingleSubst.Format := 2;
          LSingleSubst.DeltaGlyphID := 0;
          LSingleSubst.GlyphCount := ReadUInt16BE(LSub + 4);
          LSingleSubst.SubstituteArrayOffset := LSub + 6;
          LIdx := Length(FSingleSubstSubtables);
          SetLength(FSingleSubstSubtables, LIdx + 1);
          FSingleSubstSubtables[LIdx] := LSingleSubst;
        end;
      end;
    end;

    // Multiple Substitution (type 2): one-to-many.
    if LLookupType = GSUB_LOOKUP_MULTIPLE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        if LSubFmt <> 1 then
          Continue;
        LCovOff := ReadUInt16BE(LSub + 2);
        LLSCount := ReadUInt16BE(LSub + 4);
        LIdx := Length(FMultipleSubstSubtables);
        SetLength(FMultipleSubstSubtables, LIdx + 1);
        FMultipleSubstSubtables[LIdx].BaseOffset := LSub;
        FMultipleSubstSubtables[LIdx].CoverageOffset := LSub + LCovOff;
        FMultipleSubstSubtables[LIdx].SequenceCount := LLSCount;
        FMultipleSubstSubtables[LIdx].SequenceArrayOffset := LSub + 6;
      end;
    end;

    // Alternate Substitution (type 3): one-from-many.
    if LLookupType = GSUB_LOOKUP_ALTERNATE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 6 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        if LSubFmt <> 1 then
          Continue;
        LCovOff := ReadUInt16BE(LSub + 2);
        LLSCount := ReadUInt16BE(LSub + 4);
        LIdx := Length(FAlternateSubstSubtables);
        SetLength(FAlternateSubstSubtables, LIdx + 1);
        FAlternateSubstSubtables[LIdx].BaseOffset := LSub;
        FAlternateSubstSubtables[LIdx].CoverageOffset := LSub + LCovOff;
        FAlternateSubstSubtables[LIdx].AlternateSetCount := LLSCount;
        FAlternateSubstSubtables[LIdx].AlternateSetArrayOffset := LSub + 6;
      end;
    end;

    // Context Substitution (type 5) and ChainedContext Substitution (type 6).
    // Parses Format 1 (glyph-based), Format 2 (class-based), Format 3 (coverage-based).
    if (LLookupType = GSUB_LOOKUP_CONTEXT) or
       (LLookupType = GSUB_LOOKUP_CHAINED_CONTEXT) then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
        LSub := LSubOff;
        if FDataLength < LSub + 4 then
          Continue;
        LSubFmt := ReadUInt16BE(LSub);
        if LSubFmt = 3 then
        begin
          if LLookupType = GSUB_LOOKUP_CONTEXT then
          begin
            // ContextSubst Fmt3: format(2) + glyphCount(2) + substCount(2) +
            //   inputCoverages[glyphCount](2) + substRecords[substCount](4).
            if FDataLength < LSub + 6 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 2);  // inputGlyphCount
            LIdx := ReadUInt16BE(LSub + 4);       // substCount
            if FDataLength < LSub + 6 + LLSCount * 2 + LIdx * 4 then
              Continue;
            LCtxIdx := Length(FContextSubstSubtables);
            SetLength(FContextSubstSubtables, LCtxIdx + 1);
            FContextSubstSubtables[LCtxIdx].BaseOffset := LSub;
            FContextSubstSubtables[LCtxIdx].Format := 3;
            FContextSubstSubtables[LCtxIdx].IsChained := False;
            FContextSubstSubtables[LCtxIdx].InputGlyphCount := LLSCount;
            FContextSubstSubtables[LCtxIdx].SubstCount := LIdx;
            SetLength(FContextSubstSubtables[LCtxIdx].InputCoverageOffsets, LLSCount);
            SetLength(FContextSubstSubtables[LCtxIdx].SubstSeqIndices, LIdx);
            SetLength(FContextSubstSubtables[LCtxIdx].SubstLookupIndices, LIdx);
            for LK := 0 to LLSCount - 1 do
              FContextSubstSubtables[LCtxIdx].InputCoverageOffsets[LK] :=
                LSub + ReadUInt16BE(LSub + 6 + LK * 2);
            for LK := 0 to LIdx - 1 do
            begin
              FContextSubstSubtables[LCtxIdx].SubstSeqIndices[LK] :=
                ReadUInt16BE(LSub + 6 + LLSCount * 2 + LK * 4);
              FContextSubstSubtables[LCtxIdx].SubstLookupIndices[LK] :=
                ReadUInt16BE(LSub + 6 + LLSCount * 2 + LK * 4 + 2);
            end;
          end
          else
          begin
            // ChainedContextSubst Fmt3: format(2) + backtrackGlyphCount(2) +
            //   backtrackCoverages[bt](2) + inputGlyphCount(2) +
            //   inputCoverages[input](2) + lookaheadGlyphCount(2) +
            //   lookaheadCoverages[la](2) + substCount(2) + substRecords(4).
            if FDataLength < LSub + 4 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 2);  // backtrackGlyphCount
            LK := LSub + 4 + LLSCount * 2;       // offset to inputGlyphCount
            if FDataLength < LK + 2 then
              Continue;
            LLSCount := ReadUInt16BE(LK);         // inputGlyphCount
            LK := LK + 2 + LLSCount * 2;         // offset to lookaheadGlyphCount
            if FDataLength < LK + 2 then
              Continue;
            LCovOff := ReadUInt16BE(LK);          // lookaheadGlyphCount
            LK := LK + 2 + LCovOff * 2;          // offset to substCount
            if FDataLength < LK + 2 then
              Continue;
            LIdx := ReadUInt16BE(LK);             // substCount
            if FDataLength < LK + 2 + LIdx * 4 then
              Continue;
            LCtxIdx := Length(FContextSubstSubtables);
            SetLength(FContextSubstSubtables, LCtxIdx + 1);
            FContextSubstSubtables[LCtxIdx].BaseOffset := LSub;
            FContextSubstSubtables[LCtxIdx].Format := 3;
            FContextSubstSubtables[LCtxIdx].IsChained := True;
            FContextSubstSubtables[LCtxIdx].InputGlyphCount := LLSCount;
            FContextSubstSubtables[LCtxIdx].SubstCount := LIdx;
            SetLength(FContextSubstSubtables[LCtxIdx].InputCoverageOffsets, LLSCount);
            SetLength(FContextSubstSubtables[LCtxIdx].SubstSeqIndices, LIdx);
            SetLength(FContextSubstSubtables[LCtxIdx].SubstLookupIndices, LIdx);
            // Input coverage offsets are right before lookaheadGlyphCount.
            for LCovOff := 0 to LLSCount - 1 do
              FContextSubstSubtables[LCtxIdx].InputCoverageOffsets[LCovOff] :=
                LSub + ReadUInt16BE(LK - 2 - (LLSCount - LCovOff) * 2);
            for LCovOff := 0 to LIdx - 1 do
            begin
              FContextSubstSubtables[LCtxIdx].SubstSeqIndices[LCovOff] :=
                ReadUInt16BE(LK + 2 + LCovOff * 4);
              FContextSubstSubtables[LCtxIdx].SubstLookupIndices[LCovOff] :=
                ReadUInt16BE(LK + 2 + LCovOff * 4 + 2);
            end;
          end;
        end
        else if (LSubFmt = 1) or (LSubFmt = 2) then
        begin
          // ContextSubst Fmt1: format(2) + coverageOffset(2) + subRuleSetCount(2) +
          //   subRuleSetOffsets[subRuleSetCount](2).
          // ContextSubst Fmt2: format(2) + coverageOffset(2) + classDefOffset(2) +
          //   subClassSetCount(2) + subClassSetOffsets[subClassSetCount](2).
          // ChainedContextSubst Fmt1: format(2) + coverageOffset(2) +
          //   chainedSubRuleSetCount(2) + chainedSubRuleSetOffsets[...](2).
          // ChainedContextSubst Fmt2: format(2) + coverageOffset(2) +
          //   backtrackClassDefOffset(2) + inputClassDefOffset(2) +
          //   lookaheadClassDefOffset(2) + chainedClassSeqRuleSetCount(2) +
          //   chainedClassSeqRuleSetOffsets[...](2).
          if LSubFmt = 1 then
          begin
            // Format 1: coverage(2) + ruleSetCount(2) + offsets(2*count).
            if FDataLength < LSub + 6 then
              Continue;
            LLSCount := ReadUInt16BE(LSub + 4);  // ruleSetCount
            if FDataLength < LSub + 6 + LLSCount * 2 then
              Continue;
            LCtxIdx := Length(FContextSubstSubtables);
            SetLength(FContextSubstSubtables, LCtxIdx + 1);
            FContextSubstSubtables[LCtxIdx].BaseOffset := LSub;
            FContextSubstSubtables[LCtxIdx].Format := 1;
            FContextSubstSubtables[LCtxIdx].IsChained := (LLookupType = GSUB_LOOKUP_CHAINED_CONTEXT);
            FContextSubstSubtables[LCtxIdx].RuleSetCount := LLSCount;
            SetLength(FContextSubstSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
            for LK := 0 to LLSCount - 1 do
            begin
              LCovOff := ReadUInt16BE(LSub + 6 + LK * 2);
              if LCovOff <> 0 then
                FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
              else
                FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
            end;
          end
          else
          begin
            // Format 2: ruleSetCount is at different offset depending on Chained vs plain.
            if LLookupType = GSUB_LOOKUP_CONTEXT then
            begin
              // ContextSubst Fmt2: format(2) + cov(2) + classDef(2) + subClassSetCount(2) + offsets.
              if FDataLength < LSub + 8 then
                Continue;
              LLSCount := ReadUInt16BE(LSub + 6);  // subClassSetCount
              if FDataLength < LSub + 8 + LLSCount * 2 then
                Continue;
              LCtxIdx := Length(FContextSubstSubtables);
              SetLength(FContextSubstSubtables, LCtxIdx + 1);
              FContextSubstSubtables[LCtxIdx].BaseOffset := LSub;
              FContextSubstSubtables[LCtxIdx].Format := 2;
              FContextSubstSubtables[LCtxIdx].IsChained := False;
              FContextSubstSubtables[LCtxIdx].RuleSetCount := LLSCount;
              SetLength(FContextSubstSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
              for LK := 0 to LLSCount - 1 do
              begin
                LCovOff := ReadUInt16BE(LSub + 8 + LK * 2);
                if LCovOff <> 0 then
                  FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
                else
                  FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
              end;
            end
            else
            begin
              // ChainedContextSubst Fmt2: format(2) + cov(2) + btClassDef(2) +
              //   inClassDef(2) + laClassDef(2) + ruleSetCount(2) + offsets.
              if FDataLength < LSub + 12 then
                Continue;
              LLSCount := ReadUInt16BE(LSub + 10);  // chainedClassSeqRuleSetCount
              if FDataLength < LSub + 12 + LLSCount * 2 then
                Continue;
              LCtxIdx := Length(FContextSubstSubtables);
              SetLength(FContextSubstSubtables, LCtxIdx + 1);
              FContextSubstSubtables[LCtxIdx].BaseOffset := LSub;
              FContextSubstSubtables[LCtxIdx].Format := 2;
              FContextSubstSubtables[LCtxIdx].IsChained := True;
              FContextSubstSubtables[LCtxIdx].RuleSetCount := LLSCount;
              SetLength(FContextSubstSubtables[LCtxIdx].RuleSetOffsets, LLSCount);
              for LK := 0 to LLSCount - 1 do
              begin
                LCovOff := ReadUInt16BE(LSub + 12 + LK * 2);
                if LCovOff <> 0 then
                  FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := LSub + LCovOff
                else
                  FContextSubstSubtables[LCtxIdx].RuleSetOffsets[LK] := 0;
              end;
            end;
          end;
        end;
      end;
    end;

    // Ligature Substitution (type 4).
    if LLookupType = GSUB_LOOKUP_LIGATURE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOffOrig + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOffOrig + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOffOrig + ReadUInt16BE(LLookupOffOrig + 6 + LJ * 2);
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
    end;
  end;
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

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR2, LSG2, LEC2: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR2 := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR2 * 6 + 6 then
          Break;
        LSG2 := ReadUInt16BE(ACovOffset + 4 + LR2 * 6);
        LEC2 := ReadUInt16BE(ACovOffset + 4 + LR2 * 6 + 2);
        if (AGlyphId >= LSG2) and (AGlyphId <= LEC2) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR2 * 6 + 4) + (AGlyphId - LSG2));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result := 0;
  for LI := 0 to High(FPairPosSubtables) do
  begin
    LSub := FPairPosSubtables[LI];
    // Check if left glyph is in coverage.
    if CoverageIndexOf(LSub.CoverageOffset, ALeftGlyph) < 0 then
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

function TTFontFace.LookupKernFmt1(ALeftGlyph, ARightGlyph: UInt16): Int16;
var
  LI: Int32;
  LSub: TFontPairPosFmt1Subtable;
  LCovIdx, LPairSetOff, LPairCount, LRecSize: Int32;
  LLo, LHi, LMid, LSecondGid: Int32;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR2, LSG2, LEC2: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR2 := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR2 * 6 + 6 then
          Break;
        LSG2 := ReadUInt16BE(ACovOffset + 4 + LR2 * 6);
        LEC2 := ReadUInt16BE(ACovOffset + 4 + LR2 * 6 + 2);
        if (AGlyphId >= LSG2) and (AGlyphId <= LEC2) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR2 * 6 + 4) + (AGlyphId - LSG2));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result := 0;
  for LI := 0 to High(FPairPosFmt1Subtables) do
  begin
    LSub := FPairPosFmt1Subtables[LI];
    // Check if left glyph is in coverage.
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, ALeftGlyph);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= LSub.PairSetCount then
      Continue;
    // Read PairSet offset from the PairSet offset array at subtable start + 10.
    if FDataLength < LSub.BaseOffset + 10 + (LCovIdx + 1) * 2 then
      Continue;
    LPairSetOff := LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 10 + LCovIdx * 2);
    if FDataLength < LPairSetOff + 2 then
      Continue;
    LPairCount := ReadUInt16BE(LPairSetOff);
    LRecSize := 2 + LSub.ValueRecordSize;  // SecondGlyph(2) + VR1 + VR2.
    // Binary search for ARightGlyph in the sorted PairSet.
    LLo := 0;
    LHi := LPairCount - 1;
    while LLo <= LHi do
    begin
      LMid := (LLo + LHi) div 2;
      if FDataLength < LPairSetOff + 2 + (LMid + 1) * LRecSize then
        Break;
      LSecondGid := ReadUInt16BE(LPairSetOff + 2 + LMid * LRecSize);
      if LSecondGid = ARightGlyph then
      begin
        // Found: read XAdvance from VR1.
        if (LSub.XAdvanceOffset >= 0) and
           (FDataLength >= LPairSetOff + 2 + LMid * LRecSize + 2 + LSub.XAdvanceOffset + 2) then
          Result := ReadInt16BE(LPairSetOff + 2 + LMid * LRecSize + 2 + LSub.XAdvanceOffset);
        Exit;
      end
      else if LSecondGid < ARightGlyph then
        LLo := LMid + 1
      else
        LHi := LMid - 1;
    end;
  end;
end;

function TTFontFace.LookupLigature(const AGlyphs: array of UInt16): UInt16;
var
  LI, LJ, LK, LM: Int32;
  LSub: TFontLigatureSubtable;
  LCovFmt, LCovCount, LCovIdx: Int32;
  LLSOff, LLSCount, LLigOff, LCompCount: Int32;
  LMatch: Boolean;
begin
  Result := 0;
  if Length(AGlyphs) < 2 then
    Exit;

  for LI := 0 to High(FLigatureSubtables) do
  begin
    LSub := FLigatureSubtables[LI];
    // Check if first glyph is in coverage and find its index.
    if FDataLength < LSub.CoverageOffset + 4 then
      Continue;
    LCovFmt := ReadUInt16BE(LSub.CoverageOffset);
    LCovIdx := -1;
    if LCovFmt = 1 then
    begin
      LCovCount := ReadUInt16BE(LSub.CoverageOffset + 2);
      for LJ := 0 to LCovCount - 1 do
        if ReadUInt16BE(LSub.CoverageOffset + 4 + LJ * 2) = AGlyphs[0] then
        begin
          LCovIdx := LJ;
          Break;
        end;
    end;
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

function TTFontFace.HasKernPairs: Boolean;
begin
  Result := Length(FPairPosSubtables) > 0;
end;

function TTFontFace.HasKernFmt1Pairs: Boolean;
begin
  Result := Length(FPairPosFmt1Subtables) > 0;
end;

function TTFontFace.HasLigatures: Boolean;
begin
  Result := Length(FLigatureSubtables) > 0;
end;

function TTFontFace.HasSingleSubst: Boolean;
begin
  Result := Length(FSingleSubstSubtables) > 0;
end;

function TTFontFace.LookupSingleSubst(AGlyphId: UInt16): UInt16;
var
  LI, LCovIdx: Int32;
  LSub: TFontSingleSubstSubtable;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result := 0;
  for LI := 0 to High(FSingleSubstSubtables) do
  begin
    LSub := FSingleSubstSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LSub.Format = 1 then
    begin
      // Format 1: delta substitution.
      Result := (AGlyphId + LSub.DeltaGlyphID) and $FFFF;
      if Result <> 0 then
        Exit;
    end
    else if LSub.Format = 2 then
    begin
      // Format 2: array substitution.
      if LCovIdx >= LSub.GlyphCount then
        Continue;
      if FDataLength < LSub.SubstituteArrayOffset + (LCovIdx + 1) * 2 then
        Continue;
      Result := ReadUInt16BE(LSub.SubstituteArrayOffset + LCovIdx * 2);
      if Result <> 0 then
        Exit;
    end;
  end;
end;

function TTFontFace.HasMultipleSubst: Boolean;
begin
  Result := Length(FMultipleSubstSubtables) > 0;
end;

function TTFontFace.LookupMultipleSubst(AGlyphId: UInt16): TFontGlyphIdArray;
var
  LI, LCovIdx, LSeqOff, LCount, LJ: Int32;
  LSub: TFontMultipleSubstSubtable;

  function CoverageIndexOf(ACovOffset, ATarget: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = ATarget then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (ATarget >= LSG) and (ATarget <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (ATarget - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  SetLength(Result, 0);
  for LI := 0 to High(FMultipleSubstSubtables) do
  begin
    LSub := FMultipleSubstSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= LSub.SequenceCount then
      Continue;
    // SequenceTable offset is relative to the subtable start (BaseOffset).
    LSeqOff := LSub.SequenceArrayOffset + LCovIdx * 2;
    if FDataLength < LSeqOff + 2 then
      Continue;
    LSeqOff := LSub.BaseOffset + ReadUInt16BE(LSeqOff);
    if FDataLength < LSeqOff + 2 then
      Continue;
    LCount := ReadUInt16BE(LSeqOff);
    if LCount = 0 then
      Continue;
    if FDataLength < LSeqOff + 2 + LCount * 2 then
      Continue;
    SetLength(Result, LCount);
    for LJ := 0 to LCount - 1 do
      Result[LJ] := ReadUInt16BE(LSeqOff + 2 + LJ * 2);
    Exit;
  end;
end;

function TTFontFace.HasAlternateSubst: Boolean;
begin
  Result := Length(FAlternateSubstSubtables) > 0;
end;

function TTFontFace.LookupAlternateSubst(AGlyphId: UInt16): TFontGlyphIdArray;
var
  LI, LCovIdx, LSetOff, LCount, LJ: Int32;
  LSub: TFontAlternateSubstSubtable;

  function CoverageIndexOf(ACovOffset, ATarget: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = ATarget then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (ATarget >= LSG) and (ATarget <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (ATarget - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  SetLength(Result, 0);
  for LI := 0 to High(FAlternateSubstSubtables) do
  begin
    LSub := FAlternateSubstSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= LSub.AlternateSetCount then
      Continue;
    LSetOff := LSub.AlternateSetArrayOffset + LCovIdx * 2;
    if FDataLength < LSetOff + 2 then
      Continue;
    LSetOff := LSub.BaseOffset + ReadUInt16BE(LSetOff);
    if FDataLength < LSetOff + 2 then
      Continue;
    LCount := ReadUInt16BE(LSetOff);
    if LCount = 0 then
      Continue;
    if FDataLength < LSetOff + 2 + LCount * 2 then
      Continue;
    SetLength(Result, LCount);
    for LJ := 0 to LCount - 1 do
      Result[LJ] := ReadUInt16BE(LSetOff + 2 + LJ * 2);
    Exit;
  end;
end;

function TTFontFace.HasContextSubst: Boolean;
begin
  Result := Length(FContextSubstSubtables) > 0;
end;

function TTFontFace.ContextSubstCount: Int32;
begin
  Result := Length(FContextSubstSubtables);
end;

procedure TTFontFace.GetContextSubstInfo(AIndex: Int32;
  out AInputGlyphCount, ASubstCount: Int32);
begin
  if (AIndex >= 0) and (AIndex < Length(FContextSubstSubtables)) then
  begin
    AInputGlyphCount := FContextSubstSubtables[AIndex].InputGlyphCount;
    ASubstCount := FContextSubstSubtables[AIndex].SubstCount;
  end
  else
  begin
    AInputGlyphCount := 0;
    ASubstCount := 0;
  end;
end;

function TTFontFace.GetContextSubstInputCoverage(AIndex, APosition: Int32): Int32;
begin
  Result := 0;
  if (AIndex >= 0) and (AIndex < Length(FContextSubstSubtables)) then
    if (APosition >= 0) and (APosition < Length(FContextSubstSubtables[AIndex].InputCoverageOffsets)) then
      Result := FContextSubstSubtables[AIndex].InputCoverageOffsets[APosition];
end;

procedure TTFontFace.GetContextSubstLookup(AIndex, ASubstIdx: Int32;
  out ASeqIndex: UInt16; out ALookupIndex: UInt16);
begin
  ASeqIndex := 0;
  ALookupIndex := 0;
  if (AIndex >= 0) and (AIndex < Length(FContextSubstSubtables)) then
    if (ASubstIdx >= 0) and (ASubstIdx < FContextSubstSubtables[AIndex].SubstCount) then
    begin
      ASeqIndex := FContextSubstSubtables[AIndex].SubstSeqIndices[ASubstIdx];
      ALookupIndex := FContextSubstSubtables[AIndex].SubstLookupIndices[ASubstIdx];
    end;
end;

function TTFontFace.GetContextSubstFmt(AIndex: Int32): Int32;
begin
  if (AIndex >= 0) and (AIndex < Length(FContextSubstSubtables)) then
    Result := FContextSubstSubtables[AIndex].Format
  else
    Result := 0;
end;

function TTFontFace.GetContextSubstRuleSetCount(AIndex: Int32): Int32;
begin
  if (AIndex >= 0) and (AIndex < Length(FContextSubstSubtables)) then
    Result := FContextSubstSubtables[AIndex].RuleSetCount
  else
    Result := 0;
end;

function TTFontFace.GetContextSubstForGlyph(AIndex: Int32;
  AFirstGlyph: UInt16): TFontContextLookupRecordArray;
var
  LSub: TFontContextSubstSubtable;
  LCovIdx, LRuleSetOff, LRuleCount, LRuleOff: Int32;
  LI, LK, LPos, LBtCount, LInCount, LLaCount, LSubstCount: Int32;
  LInClassDefOff: Int32;
  LClassId: UInt16;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

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
  SetLength(Result, 0);
  if (AIndex < 0) or (AIndex >= Length(FContextSubstSubtables)) then
    Exit;
  LSub := FContextSubstSubtables[AIndex];

  if LSub.Format = 3 then
  begin
    // Format 3: return all pre-parsed records.
    SetLength(Result, LSub.SubstCount);
    for LI := 0 to LSub.SubstCount - 1 do
    begin
      Result[LI].SequenceIndex := LSub.SubstSeqIndices[LI];
      Result[LI].LookupIndex := LSub.SubstLookupIndices[LI];
    end;
    Exit;
  end;

  if LSub.Format = 1 then
  begin
    // Format 1: use coverage index to find rule set.
    LCovIdx := CoverageIndexOf(LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 2),
      AFirstGlyph);
    if LCovIdx < 0 then
      Exit;
    if LCovIdx >= LSub.RuleSetCount then
      Exit;
    LRuleSetOff := LSub.RuleSetOffsets[LCovIdx];
    if LRuleSetOff = 0 then
      Exit;
  end
  else if LSub.Format = 2 then
  begin
    // Format 2: use class ID to find rule set.
    // InputClassDef offset depends on plain vs chained.
    if ReadUInt16BE(LSub.BaseOffset) = 2 then
    begin
      // ContextSubst Fmt2: format(2) + cov(2) + classDef(2) + ...
      LInClassDefOff := LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 4);
    end
    else
    begin
      // ChainedContextSubst Fmt2: format(2) + cov(2) + btClassDef(2) +
      //   inClassDef(2) + laClassDef(2) + ...
      LInClassDefOff := LSub.BaseOffset + ReadUInt16BE(LSub.BaseOffset + 6);
    end;
    LClassId := GetClass(LInClassDefOff, AFirstGlyph);
    if LClassId >= LSub.RuleSetCount then
      Exit;
    LRuleSetOff := LSub.RuleSetOffsets[LClassId];
    if LRuleSetOff = 0 then
      Exit;
  end
  else
    Exit;

  // Parse rules in the rule set.
  // RuleSet: ruleCount(2) + ruleOffsets[ruleCount](2).
  // Rule: [backtrackGlyphCount(2) + backtrackGlyphIDs(bt*2)] +
  //       inputGlyphCount(2) + inputGlyphIDs[(input-1)*2] +
  //       [lookaheadGlyphCount(2) + lookaheadGlyphIDs(la*2)] +
  //       substCount(2) + substRecords[substCount](4).
  if FDataLength < LRuleSetOff + 2 then
    Exit;
  LRuleCount := ReadUInt16BE(LRuleSetOff);
  // For simplicity, parse the first rule only (most common case).
  if LRuleCount = 0 then
    Exit;
  if FDataLength < LRuleSetOff + 4 then
    Exit;
  LRuleOff := LRuleSetOff + ReadUInt16BE(LRuleSetOff + 2);
  if FDataLength < LRuleOff + 2 then
    Exit;

  // Walk the rule to find substCount.
  // Determine if this is a plain or chained context by checking the subtable's
  // lookup type via BaseOffset format field (already stored).
  // Plain ContextSubst (GSUB 5): inputGlyphCount(2) + inputGlyphIDs + substCount(2) + substRecords.
  // Chained ContextSubst (GSUB 6): backtrackGlyphCount(2) + ... + substCount(2) + substRecords.
  // We distinguish by checking if the subtable was parsed from a Chained type.
  // Parse rules in the rule set.
  // RuleSet: ruleCount(2) + ruleOffsets[ruleCount](2).
  if FDataLength < LRuleSetOff + 2 then
    Exit;
  LRuleCount := ReadUInt16BE(LRuleSetOff);
  if LRuleCount = 0 then
    Exit;
  if FDataLength < LRuleSetOff + 4 then
    Exit;
  LRuleOff := LRuleSetOff + ReadUInt16BE(LRuleSetOff + 2);
  if FDataLength < LRuleOff + 2 then
    Exit;

  if LSub.IsChained then
  begin
    // ChainedSubRule: backtrackGlyphCount(2) + backtrackGlyphIDs(bt*2) +
    //   inputGlyphCount(2) + inputGlyphIDs[(input-1)*2] +
    //   lookaheadGlyphCount(2) + lookaheadGlyphIDs(la*2) +
    //   substCount(2) + substRecords[substCount](4).
    LBtCount := ReadUInt16BE(LRuleOff);
    LPos := LRuleOff + 2 + LBtCount * 2;
    if FDataLength < LPos + 2 then
      Exit;
    LInCount := ReadUInt16BE(LPos);
    LPos := LPos + 2 + (LInCount - 1) * 2;
    if FDataLength < LPos + 2 then
      Exit;
    LLaCount := ReadUInt16BE(LPos);
    LPos := LPos + 2 + LLaCount * 2;
  end
  else
  begin
    // SubRule: inputGlyphCount(2) + inputGlyphIDs[(input-1)*2] +
    //   substCount(2) + substRecords[substCount](4).
    LPos := LRuleOff;
    LInCount := ReadUInt16BE(LPos);
    LPos := LPos + 2 + (LInCount - 1) * 2;
  end;
  if FDataLength < LPos + 2 then
    Exit;
  LSubstCount := ReadUInt16BE(LPos);
  if FDataLength < LPos + 2 + LSubstCount * 4 then
    Exit;
  LPos := LPos + 2;

  SetLength(Result, LSubstCount);
  for LI := 0 to LSubstCount - 1 do
  begin
    Result[LI].SequenceIndex := ReadUInt16BE(LPos + LI * 4);
    Result[LI].LookupIndex := ReadUInt16BE(LPos + LI * 4 + 2);
  end;
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
begin
  if (AIndex >= 0) and (AIndex < Length(FContextPosSubtables)) then
  begin
    AInputGlyphCount := FContextPosSubtables[AIndex].InputGlyphCount;
    APosCount := FContextPosSubtables[AIndex].SubstCount;
  end
  else
  begin
    AInputGlyphCount := 0;
    APosCount := 0;
  end;
end;

function TTFontFace.GetContextPosInputCoverage(AIndex, APosition: Int32): Int32;
begin
  Result := 0;
  if (AIndex >= 0) and (AIndex < Length(FContextPosSubtables)) then
    if (APosition >= 0) and (APosition < Length(FContextPosSubtables[AIndex].InputCoverageOffsets)) then
      Result := FContextPosSubtables[AIndex].InputCoverageOffsets[APosition];
end;

procedure TTFontFace.GetContextPosLookup(AIndex, APosIdx: Int32;
  out ASeqIndex: UInt16; out ALookupIndex: UInt16);
begin
  ASeqIndex := 0;
  ALookupIndex := 0;
  if (AIndex >= 0) and (AIndex < Length(FContextPosSubtables)) then
    if (APosIdx >= 0) and (APosIdx < FContextPosSubtables[AIndex].SubstCount) then
    begin
      ASeqIndex := FContextPosSubtables[AIndex].SubstSeqIndices[APosIdx];
      ALookupIndex := FContextPosSubtables[AIndex].SubstLookupIndices[APosIdx];
    end;
end;

function TTFontFace.HasSinglePos: Boolean;
begin
  Result := Length(FSinglePosSubtables) > 0;
end;

function TTFontFace.LookupSinglePosXAdvance(AGlyphId: UInt16): Int16;
var
  LI, LCovIdx: Int32;
  LSub: TFontSinglePosSubtable;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result := 0;
  for LI := 0 to High(FSinglePosSubtables) do
  begin
    LSub := FSinglePosSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LSub.Format = 1 then
    begin
      // Format 1: uniform — same ValueRecord for all glyphs.
      if FDataLength < LSub.ValueArrayOffset + LSub.XAdvanceOffset + 2 then
        Continue;
      Result := ReadInt16BE(LSub.ValueArrayOffset + LSub.XAdvanceOffset);
      if Result <> 0 then
        Exit;
    end
    else if LSub.Format = 2 then
    begin
      // Format 2: per-glyph array.
      if LCovIdx >= LSub.GlyphCount then
        Continue;
      if FDataLength < LSub.ValueArrayOffset + LCovIdx * LSub.ValueRecordSize + LSub.XAdvanceOffset + 2 then
        Continue;
      Result := ReadInt16BE(LSub.ValueArrayOffset + LCovIdx * LSub.ValueRecordSize + LSub.XAdvanceOffset);
      if Result <> 0 then
        Exit;
    end;
  end;
end;

function TTFontFace.HasMarkToBase: Boolean;
begin
  Result := Length(FMarkToBaseSubtables) > 0;
end;

function TTFontFace.LookupMarkToBase(AMarkGlyph, ABaseGlyph: UInt16): TFontAnchor;
var
  LI: Int32;
  LSub: TFontMarkToBaseSubtable;
  LMarkCovIdx, LBaseCovIdx: Int32;
  LMarkCount, LBaseCount: Int32;
  LMarkClass: UInt16;
  LMarkAnchorOff, LBaseAnchorOff: Int32;
  LBaseRecordSize: Int32;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToBaseSubtables) do
  begin
    LSub := FMarkToBaseSubtables[LI];
    // Check mark coverage.
    LMarkCovIdx := CoverageIndexOf(LSub.MarkCoverageOffset, AMarkGlyph);
    if LMarkCovIdx < 0 then
      Continue;
    // Check base coverage.
    LBaseCovIdx := CoverageIndexOf(LSub.BaseCoverageOffset, ABaseGlyph);
    if LBaseCovIdx < 0 then
      Continue;
    // Read MarkArray: markCount (uint16), then per-mark: markClass (uint16) + anchor offset (uint16).
    if FDataLength < LSub.MarkArrayOffset + 2 then
      Continue;
    LMarkCount := ReadUInt16BE(LSub.MarkArrayOffset);
    if LMarkCovIdx >= LMarkCount then
      Continue;
    // Each mark record: 2 + 2 = 4 bytes.
    if FDataLength < LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 4 then
      Continue;
    LMarkClass := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4);
    LMarkAnchorOff := LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 +
      ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 2);
    // Read mark anchor (X, Y as int16).
    if FDataLength < LMarkAnchorOff + 4 then
      Continue;
    // Read BaseArray: baseCount (uint16), then per-base: classCount * offset(uint16).
    if FDataLength < LSub.BaseArrayOffset + 2 then
      Continue;
    LBaseCount := ReadUInt16BE(LSub.BaseArrayOffset);
    if LBaseCovIdx >= LBaseCount then
      Continue;
    if LMarkClass >= LSub.ClassCount then
      Continue;
    // Each base record: ClassCount * 2 bytes (array of Offset16).
    LBaseRecordSize := LSub.ClassCount * 2;
    if FDataLength < LSub.BaseArrayOffset + 2 + LBaseCovIdx * LBaseRecordSize + LMarkClass * 2 + 2 then
      Continue;
    LBaseAnchorOff := LSub.BaseArrayOffset + 2 + LBaseCovIdx * LBaseRecordSize +
      ReadUInt16BE(LSub.BaseArrayOffset + 2 + LBaseCovIdx * LBaseRecordSize + LMarkClass * 2);
    // Read base anchor (X, Y as int16).
    if FDataLength < LBaseAnchorOff + 4 then
      Continue;
    // Positioning: mark offset = base_anchor - mark_anchor.
    Result.X := ReadInt16BE(LBaseAnchorOff) - ReadInt16BE(LMarkAnchorOff);
    Result.Y := ReadInt16BE(LBaseAnchorOff + 2) - ReadInt16BE(LMarkAnchorOff + 2);
    Exit;
  end;
end;

function TTFontFace.HasMarkToMark: Boolean;
begin
  Result := Length(FMarkToMarkSubtables) > 0;
end;

function TTFontFace.LookupMarkToMark(AMarkGlyph, ABaseMarkGlyph: UInt16): TFontAnchor;
var
  LI: Int32;
  LSub: TFontMarkToMarkSubtable;
  LMark2CovIdx, LMark1CovIdx: Int32;
  LMark2Count, LMark1Count: Int32;
  LMarkClass: UInt16;
  LMark2AnchorOff, LMark1AnchorOff: Int32;
  LMark1RecordSize: Int32;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToMarkSubtables) do
  begin
    LSub := FMarkToMarkSubtables[LI];
    // Check Mark2 coverage (attaching mark).
    LMark2CovIdx := CoverageIndexOf(LSub.Mark2CoverageOffset, AMarkGlyph);
    if LMark2CovIdx < 0 then
      Continue;
    // Check Mark1 coverage (base mark).
    LMark1CovIdx := CoverageIndexOf(LSub.Mark1CoverageOffset, ABaseMarkGlyph);
    if LMark1CovIdx < 0 then
      Continue;
    // Read Mark2Array: mark2Count, then per-mark2: markClass(uint16) + anchor offset(uint16).
    if FDataLength < LSub.Mark2ArrayOffset + 2 then
      Continue;
    LMark2Count := ReadUInt16BE(LSub.Mark2ArrayOffset);
    if LMark2CovIdx >= LMark2Count then
      Continue;
    if FDataLength < LSub.Mark2ArrayOffset + 2 + LMark2CovIdx * 4 + 4 then
      Continue;
    LMarkClass := ReadUInt16BE(LSub.Mark2ArrayOffset + 2 + LMark2CovIdx * 4);
    LMark2AnchorOff := LSub.Mark2ArrayOffset + 2 + LMark2CovIdx * 4 +
      ReadUInt16BE(LSub.Mark2ArrayOffset + 2 + LMark2CovIdx * 4 + 2);
    if FDataLength < LMark2AnchorOff + 4 then
      Continue;
    // Read Mark1Array: mark1Count, then per-mark1: ClassCount * offset(uint16).
    if FDataLength < LSub.Mark1ArrayOffset + 2 then
      Continue;
    LMark1Count := ReadUInt16BE(LSub.Mark1ArrayOffset);
    if LMark1CovIdx >= LMark1Count then
      Continue;
    if LMarkClass >= LSub.ClassCount then
      Continue;
    LMark1RecordSize := LSub.ClassCount * 2;
    if FDataLength < LSub.Mark1ArrayOffset + 2 + LMark1CovIdx * LMark1RecordSize + LMarkClass * 2 + 2 then
      Continue;
    LMark1AnchorOff := LSub.Mark1ArrayOffset + 2 + LMark1CovIdx * LMark1RecordSize +
      ReadUInt16BE(LSub.Mark1ArrayOffset + 2 + LMark1CovIdx * LMark1RecordSize + LMarkClass * 2);
    if FDataLength < LMark1AnchorOff + 4 then
      Continue;
    // Positioning: mark offset = mark1_anchor - mark2_anchor.
    Result.X := ReadInt16BE(LMark1AnchorOff) - ReadInt16BE(LMark2AnchorOff);
    Result.Y := ReadInt16BE(LMark1AnchorOff + 2) - ReadInt16BE(LMark2AnchorOff + 2);
    Exit;
  end;
end;

function TTFontFace.HasMarkToLig: Boolean;
begin
  Result := Length(FMarkToLigSubtables) > 0;
end;

function TTFontFace.LookupMarkToLig(AMarkGlyph, ALigGlyph: UInt16;
  AComponentIdx: Int32): TFontAnchor;
var
  LI: Int32;
  LSub: TFontMarkToLigSubtable;
  LMarkCovIdx, LLigCovIdx: Int32;
  LMarkCount, LMarkClass: UInt16;
  LMarkAnchorOff: Int32;
  LLigCount, LCompCount: UInt16;
  LLigAttachOff, LCompOff, LAnchorOff: Int32;

  function CoverageIndexOf(ACovOffset, AGlyphId: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = AGlyphId then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (AGlyphId >= LSG) and (AGlyphId <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (AGlyphId - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FMarkToLigSubtables) do
  begin
    LSub := FMarkToLigSubtables[LI];
    LMarkCovIdx := CoverageIndexOf(LSub.MarkCoverageOffset, AMarkGlyph);
    if LMarkCovIdx < 0 then
      Continue;
    LLigCovIdx := CoverageIndexOf(LSub.LigCoverageOffset, ALigGlyph);
    if LLigCovIdx < 0 then
      Continue;
    // Read MarkArray: markCount, then per-mark: markClass(uint16) + anchorOffset(uint16).
    if FDataLength < LSub.MarkArrayOffset + 2 then
      Continue;
    LMarkCount := ReadUInt16BE(LSub.MarkArrayOffset);
    if LMarkCovIdx >= LMarkCount then
      Continue;
    if FDataLength < LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 4 then
      Continue;
    LMarkClass := ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4);
    LMarkAnchorOff := LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 +
      ReadUInt16BE(LSub.MarkArrayOffset + 2 + LMarkCovIdx * 4 + 2);
    if FDataLength < LMarkAnchorOff + 4 then
      Continue;
    if LMarkClass >= LSub.ClassCount then
      Continue;
    // Read LigatureArray: ligCount, then per-lig: LigAttach offset (uint16, relative to LigArray).
    if FDataLength < LSub.LigArrayOffset + 2 then
      Continue;
    LLigCount := ReadUInt16BE(LSub.LigArrayOffset);
    if LLigCovIdx >= LLigCount then
      Continue;
    if FDataLength < LSub.LigArrayOffset + 2 + LLigCovIdx * 2 + 2 then
      Continue;
    LLigAttachOff := LSub.LigArrayOffset +
      ReadUInt16BE(LSub.LigArrayOffset + 2 + LLigCovIdx * 2);
    if FDataLength < LLigAttachOff + 2 then
      Continue;
    LCompCount := ReadUInt16BE(LLigAttachOff);
    if (AComponentIdx < 0) or (AComponentIdx >= LCompCount) then
      Continue;
    // ComponentRecord[componentIdx]: ClassCount * anchor offsets (uint16, relative to LigAttach).
    LCompOff := LLigAttachOff + 2 + AComponentIdx * (LSub.ClassCount * 2);
    if FDataLength < LCompOff + (LMarkClass + 1) * 2 then
      Continue;
    LAnchorOff := LLigAttachOff + ReadUInt16BE(LCompOff + LMarkClass * 2);
    if FDataLength < LAnchorOff + 4 then
      Continue;
    // Positioning: mark offset = ligature_anchor - mark_anchor.
    Result.X := ReadInt16BE(LAnchorOff) - ReadInt16BE(LMarkAnchorOff);
    Result.Y := ReadInt16BE(LAnchorOff + 2) - ReadInt16BE(LMarkAnchorOff + 2);
    Exit;
  end;
end;

function TTFontFace.HasCursivePos: Boolean;
begin
  Result := Length(FCursivePosSubtables) > 0;
end;

function TTFontFace.LookupCursivePosExitAnchor(AGlyphId: UInt16): TFontAnchor;
var
  LI, LJ: Int32;
  LSub: TFontCursivePosSubtable;
  LCovIdx: Int32;
  LRecOff, LExitOff: Int32;

  function CoverageIndexOf(ACovOffset, ATarget: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = ATarget then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (ATarget >= LSG) and (ATarget <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (ATarget - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FCursivePosSubtables) do
  begin
    LSub := FCursivePosSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= LSub.EntryExitCount then
      Continue;
    // EntryExitRecord[LCovIdx]: entryAnchorOffset(uint16) + exitAnchorOffset(uint16).
    LRecOff := LSub.EntryExitArrayOffset + LCovIdx * 4;
    if FDataLength < LRecOff + 4 then
      Continue;
    LExitOff := ReadUInt16BE(LRecOff + 2);  // exit anchor offset (relative to subtable).
    if LExitOff = 0 then
      Continue;  // null exit anchor.
    LExitOff := LSub.BaseOffset + LExitOff;
    if FDataLength < LExitOff + 4 then
      Continue;
    // AnchorFormat 1: X(Int16) + Y(Int16).
    if ReadUInt16BE(LExitOff) = 1 then
    begin
      Result.X := ReadInt16BE(LExitOff + 2);
      Result.Y := ReadInt16BE(LExitOff + 4);
    end;
    Exit;
  end;
end;

function TTFontFace.LookupCursivePosEntryAnchor(AGlyphId: UInt16): TFontAnchor;
var
  LI: Int32;
  LSub: TFontCursivePosSubtable;
  LCovIdx: Int32;
  LRecOff, LEntryOff: Int32;

  function CoverageIndexOf(ACovOffset, ATarget: Int32): Int32;
  var
    LFmt, LCnt, LM, LR, LSG, LEC: Int32;
  begin
    if FDataLength < ACovOffset + 4 then
      Exit(-1);
    LFmt := ReadUInt16BE(ACovOffset);
    if LFmt = 1 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LM := 0 to LCnt - 1 do
        if ReadUInt16BE(ACovOffset + 4 + LM * 2) = ATarget then
          Exit(LM);
      Result := -1;
    end
    else if LFmt = 2 then
    begin
      LCnt := ReadUInt16BE(ACovOffset + 2);
      for LR := 0 to LCnt - 1 do
      begin
        if FDataLength < ACovOffset + 4 + LR * 6 + 6 then
          Break;
        LSG := ReadUInt16BE(ACovOffset + 4 + LR * 6);
        LEC := ReadUInt16BE(ACovOffset + 4 + LR * 6 + 2);
        if (ATarget >= LSG) and (ATarget <= LEC) then
          Exit(ReadUInt16BE(ACovOffset + 4 + LR * 6 + 4) + (ATarget - LSG));
      end;
      Result := -1;
    end
    else
      Result := -1;
  end;

begin
  Result.X := 0;
  Result.Y := 0;
  for LI := 0 to High(FCursivePosSubtables) do
  begin
    LSub := FCursivePosSubtables[LI];
    LCovIdx := CoverageIndexOf(LSub.CoverageOffset, AGlyphId);
    if LCovIdx < 0 then
      Continue;
    if LCovIdx >= LSub.EntryExitCount then
      Continue;
    LRecOff := LSub.EntryExitArrayOffset + LCovIdx * 4;
    if FDataLength < LRecOff + 4 then
      Continue;
    LEntryOff := ReadUInt16BE(LRecOff);  // entry anchor offset (relative to subtable).
    if LEntryOff = 0 then
      Continue;  // null entry anchor.
    LEntryOff := LSub.BaseOffset + LEntryOff;
    if FDataLength < LEntryOff + 4 then
      Continue;
    // AnchorFormat 1: X(Int16) + Y(Int16).
    if ReadUInt16BE(LEntryOff) = 1 then
    begin
      Result.X := ReadInt16BE(LEntryOff + 2);
      Result.Y := ReadInt16BE(LEntryOff + 4);
    end;
    Exit;
  end;
end;

function TTFontFace.HasFeatureKern: Boolean;
begin
  Result := Length(FKernLookups) > 0;
end;

function TTFontFace.HasFeatureMark: Boolean;
begin
  Result := Length(FMarkLookups) > 0;
end;

function TTFontFace.HasFeatureMkmk: Boolean;
begin
  Result := Length(FMkmkLookups) > 0;
end;

function TTFontFace.HasFeatureLiga: Boolean;
begin
  Result := Length(FLigaLookups) > 0;
end;

function TTFontFace.HasFeatureClig: Boolean;
begin
  Result := Length(FCligLookups) > 0;
end;

function TTFontFace.HasFeatureCurs: Boolean;
begin
  Result := Length(FCursLookups) > 0;
end;

function TTFontFace.HasFmt14: Boolean;
begin
  Result := FHasFmt14;
end;

function TTFontFace.LookupIVS(ACodepoint, AVariationSelector: UInt32): UInt32;
var
  I, J: Int32;
  LVS: TFontCmapFmt14VarSelector;
  LRange: TFontCmapFmt14DefaultUVSRange;
  LMapping: TFontCmapFmt14UVSMapping;
begin
  Result := 0;
  if not FHasFmt14 then
    Exit;

  // 查找 Variation Selector
  for I := 0 to High(FCmapFmt14.VarSelectors) do
  begin
    if FCmapFmt14.VarSelectors[I].VarSelector = AVariationSelector then
    begin
      LVS := FCmapFmt14.VarSelectors[I];

      // 先查 Non-Default UVS（精确匹配返回 glyphID）
      for J := 0 to High(LVS.NonDefaultUVS) do
      begin
        LMapping := LVS.NonDefaultUVS[J];
        if LMapping.UnicodeValue = ACodepoint then
          Exit(UInt32(LMapping.GlyphID));
      end;

      // 再查 Default UVS（范围匹配返回 0 = 使用默认字形）
      for J := 0 to High(LVS.DefaultUVSRanges) do
      begin
        LRange := LVS.DefaultUVSRanges[J];
        if (ACodepoint >= LRange.StartUnicodeValue) and
           (ACodepoint <= LRange.StartUnicodeValue + LRange.AdditionalCount) then
          Exit(0); // Default: 使用基础字形
      end;

      // VS 存在但此字码不在任何表中
      Exit(0);
    end;
  end;

  // 此 VS 未在 Format 14 中注册
  Result := 0;
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
  if FCffValid then
    Result := UInt32(FCffCharStringsCount)
  else
    Result := FMaxp.NumGlyphs;
end;

function TTFontFace.LookupCodepoint(ACodepoint: UInt32): UInt32;
var
  J: Int32;
  LStartCode, LEndCode: UInt16;
  LIdDelta, LIdRangeOff: UInt16;
  LOffset, LGlyphId: UInt32;
begin
  Result := 0; // .notdef

  // Format 12 优先（覆盖全 Unicode，包括 SMP）
  if FHasFmt12 then
  begin
    for J := 0 to High(FCmapFmt12.Groups) do
    begin
      if (ACodepoint >= FCmapFmt12.Groups[J].StartCharCode) and
         (ACodepoint <= FCmapFmt12.Groups[J].EndCharCode) then
      begin
        Result := FCmapFmt12.Groups[J].StartGlyphCode +
                  (ACodepoint - FCmapFmt12.Groups[J].StartCharCode);
        Exit;
      end;
    end;
  end;

  // Format 4（BMP）
  if FHasFmt4 then
  begin
    for J := 0 to FCmapFmt4.SegmentCount - 1 do
    begin
      LStartCode := FCmapFmt4.StartCode[J];
      LEndCode := FCmapFmt4.EndCode[J];
      if LStartCode > LEndCode then
        Continue;
      if LStartCode = $FFFF then
        Continue; // 最后一个段是哨兵

      if (ACodepoint >= LStartCode) and (ACodepoint <= LEndCode) then
      begin
        LIdDelta := UInt16(FCmapFmt4.IdDelta[J]);
        LIdRangeOff := FCmapFmt4.IdRangeOffset[J];

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
          LOffset := (ACodepoint - LStartCode) +
            (LIdRangeOff div 2) - (FCmapFmt4.SegmentCount - J);
          if LOffset < UInt32(Length(FCmapFmt4.GlyphIdArray)) then
          begin
            LGlyphId := FCmapFmt4.GlyphIdArray[LOffset];
            if LGlyphId <> 0 then
              LGlyphId := UInt16((LGlyphId + LIdDelta) and $FFFF);
            Result := LGlyphId;
            Exit;
          end;
        end;
      end;
    end;
  end;
end;

function TTFontFace.GlyphHorizontalMetric(AGlyphIndex: UInt32): TFontHorizontalMetric;
begin
  if AGlyphIndex < UInt32(Length(FHmtx)) then
    Result := FHmtx[AGlyphIndex]
  else
  begin
    Result.AdvanceWidth := 0;
    Result.LeftSideBearing := 0;
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
  FontGlyphOutlineClear(Result);

  // CFF 字体：使用 Type 2 charstring 解析
  if FCffValid then
  begin
    Result := GlyphOutlineCff(AGlyphIndex);
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
end;

{ ========================================================================= }
{ CFF (Compact Font Format) 解析                                              }
{ ========================================================================= }

procedure TTFontFace.ParseCff;
var
  LIdx, LCffOff, LHdrSize: Int32;
  LNameCount, LTopDictCount: Int32;
  LNameIdxOff, LTopDictIdxOff: Int32;
  LTopDictOff, LTopDictLen: Int32;
  LCharStringsIdxOff: Int32;
  LPrivateSize, LPrivateOff: Int32;
  LNOffSz, LNLastOff, LI2: Int32;

  function ReadUInt8Local(AOff: Int32): Byte;
  begin
    if (AOff >= 0) and (AOff < FDataLength) then
      Result := FData[AOff]
    else
      Result := 0;
  end;

  function ParseCffIndex(APos: Int32; out ACount: Int32): Int32;
  begin
    ACount := 0;
    if FDataLength < APos + 3 then
      Exit(0);
    ACount := (ReadUInt8Local(APos) shl 8) or ReadUInt8Local(APos + 1);
    if ACount = 0 then
      Exit(APos + 2);
    Result := APos + 3 + (ACount + 1) * ReadUInt8Local(APos + 2);
  end;

  procedure GetCffIndexItem(AIdxPos, AItem, ACount: Int32;
    out AItemOff, AItemLen: Int32);
  var
    LOffSz, LI, LV1, LV2, LDataStart: Int32;
  begin
    AItemOff := 0; AItemLen := 0;
    if (AItem < 0) or (AItem >= ACount) or (ACount = 0) then
      Exit;
    LOffSz := ReadUInt8Local(AIdxPos + 2);
    LDataStart := AIdxPos + 3 + (ACount + 1) * LOffSz;
    LV1 := 0;
    for LI := 0 to LOffSz - 1 do
      LV1 := (LV1 shl 8) or ReadUInt8Local(AIdxPos + 3 + AItem * LOffSz + LI);
    LV2 := 0;
    for LI := 0 to LOffSz - 1 do
      LV2 := (LV2 shl 8) or ReadUInt8Local(AIdxPos + 3 + (AItem + 1) * LOffSz + LI);
    AItemOff := LDataStart + LV1 - 1;
    AItemLen := LV2 - LV1;
  end;

  function ParseCffDictInt(APos, ALen, ATargetOp: Int32): Int32;
  var
    LI, LB: Int32;
    LOps: array[0..31] of Int32;
    LN: Int32;
    LOp: Int32;
  begin
    Result := 0;
    LN := 0;
    LI := APos;
    while LI < APos + ALen do
    begin
      LB := ReadUInt8Local(LI);
      if (LB >= 32) and (LB <= 246) then
      begin
        if LN < 32 then begin LOps[LN] := LB - 139; Inc(LN); end;
        Inc(LI);
      end
      else if (LB >= 247) and (LB <= 250) then
      begin
        if LN < 32 then begin LOps[LN] := (LB - 247) * 256 + ReadUInt8Local(LI + 1) + 108; Inc(LN); end;
        Inc(LI, 2);
      end
      else if (LB >= 251) and (LB <= 254) then
      begin
        if LN < 32 then begin LOps[LN] := -((LB - 251) * 256) - ReadUInt8Local(LI + 1) - 108; Inc(LN); end;
        Inc(LI, 2);
      end
      else if LB = 28 then
      begin
        if LN < 32 then begin LOps[LN] := SmallInt((ReadUInt8Local(LI + 1) shl 8) or ReadUInt8Local(LI + 2)); Inc(LN); end;
        Inc(LI, 3);
      end
      else if LB = 29 then
      begin
        if LN < 32 then begin LOps[LN] := Int32(ReadUInt32BE(LI + 1)); Inc(LN); end;
        Inc(LI, 5);
      end
      else if LB = 30 then
      begin
        Inc(LI);
        while LI < APos + ALen do
        begin
          LB := ReadUInt8Local(LI); Inc(LI);
          if (LB and $0F) = $0F then Break;
          if ((LB shr 4) and $0F) = $0F then Break;
        end;
        LN := 0;
      end
      else if LB <= 21 then
      begin
        LOp := LB;
        if LB = 12 then begin Inc(LI); LOp := (12 shl 8) or ReadUInt8Local(LI); end;
        Inc(LI);
        if (LOp = ATargetOp) and (LN > 0) then
          Exit(LOps[0]);
        LN := 0;
      end
      else
        Inc(LI);
    end;
  end;

  function ParseCffDictSecondInt(APos, ALen, ATargetOp: Int32): Int32;
  var
    LI, LB: Int32;
    LOps: array[0..31] of Int32;
    LN: Int32;
    LOp: Int32;
  begin
    Result := 0;
    LN := 0;
    LI := APos;
    while LI < APos + ALen do
    begin
      LB := ReadUInt8Local(LI);
      if (LB >= 32) and (LB <= 246) then
      begin
        if LN < 32 then begin LOps[LN] := LB - 139; Inc(LN); end;
        Inc(LI);
      end
      else if (LB >= 247) and (LB <= 250) then
      begin
        if LN < 32 then begin LOps[LN] := (LB - 247) * 256 + ReadUInt8Local(LI + 1) + 108; Inc(LN); end;
        Inc(LI, 2);
      end
      else if (LB >= 251) and (LB <= 254) then
      begin
        if LN < 32 then begin LOps[LN] := -((LB - 251) * 256) - ReadUInt8Local(LI + 1) - 108; Inc(LN); end;
        Inc(LI, 2);
      end
      else if LB = 28 then
      begin
        if LN < 32 then begin LOps[LN] := SmallInt((ReadUInt8Local(LI + 1) shl 8) or ReadUInt8Local(LI + 2)); Inc(LN); end;
        Inc(LI, 3);
      end
      else if LB = 29 then
      begin
        if LN < 32 then begin LOps[LN] := Int32(ReadUInt32BE(LI + 1)); Inc(LN); end;
        Inc(LI, 5);
      end
      else if LB = 30 then
      begin
        Inc(LI);
        while LI < APos + ALen do
        begin
          LB := ReadUInt8Local(LI); Inc(LI);
          if (LB and $0F) = $0F then Break;
          if ((LB shr 4) and $0F) = $0F then Break;
        end;
        LN := 0;
      end
      else if LB <= 21 then
      begin
        LOp := LB;
        if LB = 12 then begin Inc(LI); LOp := (12 shl 8) or ReadUInt8Local(LI); end;
        Inc(LI);
        if (LOp = ATargetOp) and (LN >= 2) then
          Exit(LOps[1]);
        LN := 0;
      end
      else
        Inc(LI);
    end;
  end;

var
  LItemOff, LItemLen: Int32;
  LStringIdxOff: Int32;
  LStringCount: Int32;
  LStrOffSz, LStrLastOff: Int32;
  LSubrsOff: Int32;
  LPrivateAbs: Int32;
  LTopDictOffSz, LTopDictLastOff: Int32;
begin
  FCffValid := False;
  LIdx := FindTable(TABLE_TAG_CFF);
  if LIdx < 0 then
    Exit;
  LCffOff := FTables[LIdx].Offset;
  FCffOff := LCffOff;
  if FDataLength < LCffOff + 4 then
    Exit;

  LHdrSize := ReadUInt8Local(LCffOff + 2);

  // Name INDEX — header position
  LNameIdxOff := LCffOff + LHdrSize;
  ParseCffIndex(LNameIdxOff, LNameCount);
  if LNameCount = 0 then
    Exit;

  // Top DICT INDEX — starts at end of Name INDEX data
  LNOffSz := ReadUInt8Local(LNameIdxOff + 2);
  LNLastOff := 0;
  for LI2 := 0 to LNOffSz - 1 do
    LNLastOff := (LNLastOff shl 8) or ReadUInt8Local(LNameIdxOff + 3 + LNameCount * LNOffSz + LI2);
  // Save header position, then get data start
  LTopDictIdxOff := LNameIdxOff + 3 + (LNameCount + 1) * LNOffSz + LNLastOff - 1;
  ParseCffIndex(LTopDictIdxOff, LTopDictCount);
  if LTopDictCount = 0 then
    Exit;

  // Get first Top DICT item
  GetCffIndexItem(LTopDictIdxOff, 0, LTopDictCount, LTopDictOff, LTopDictLen);

  // CharStrings offset (operator 17)
  FCffCharStringsOff := ParseCffDictInt(LTopDictOff, LTopDictLen, 17);
  if FCffCharStringsOff <= 0 then
    Exit;

  // Private DICT: size (first operand of op 18), offset (second operand)
  LPrivateSize := ParseCffDictInt(LTopDictOff, LTopDictLen, 18);
  LPrivateOff := ParseCffDictSecondInt(LTopDictOff, LTopDictLen, 18);

  // CharStrings INDEX
  LCharStringsIdxOff := LCffOff + FCffCharStringsOff;
  FCffCharStringsDataStart := ParseCffIndex(LCharStringsIdxOff, FCffCharStringsCount);
  if FCffCharStringsCount <= 0 then
    Exit;
  FCffCharStringsOffSize := ReadUInt8Local(LCharStringsIdxOff + 2);

  // Private DICT: DefaultWidthX (op 20), NominalWidthX (op 21)
  FCffDefaultWidthX := 0;
  FCffNominalWidthX := 0;
  if (LPrivateSize > 0) and (LPrivateOff > 0) then
  begin
    FCffDefaultWidthX := ParseCffDictInt(LCffOff + LPrivateOff, LPrivateSize, 20);
    FCffNominalWidthX := ParseCffDictInt(LCffOff + LPrivateOff, LPrivateSize, 21);
  end;

  // Global Subr INDEX — follows String INDEX
  // 计算 Top DICT INDEX 结束位置 → String INDEX header 位置
  LTopDictOffSz := ReadUInt8Local(LTopDictIdxOff + 2);
  LTopDictLastOff := 0;
  for LI2 := 0 to LTopDictOffSz - 1 do
    LTopDictLastOff := (LTopDictLastOff shl 8) or ReadUInt8Local(LTopDictIdxOff + 3 + LTopDictCount * LTopDictOffSz + LI2);
  LStringIdxOff := LTopDictIdxOff + 3 + (LTopDictCount + 1) * LTopDictOffSz + LTopDictLastOff - 1;

  // 解析 String INDEX
  ParseCffIndex(LStringIdxOff, LStringCount);
  // String INDEX 结束位置 → Global Subr INDEX header 位置
  if LStringCount > 0 then
  begin
    LStrOffSz := ReadUInt8Local(LStringIdxOff + 2);
    LStrLastOff := 0;
    for LI2 := 0 to LStrOffSz - 1 do
      LStrLastOff := (LStrLastOff shl 8) or ReadUInt8Local(LStringIdxOff + 3 + LStringCount * LStrOffSz + LI2);
    FCffGlobalSubrIdxPos := LStringIdxOff + 3 + (LStringCount + 1) * LStrOffSz + LStrLastOff - 1;
  end
  else
    FCffGlobalSubrIdxPos := LStringIdxOff + 2; // count=0 时 header 长度为 2

  ParseCffIndex(FCffGlobalSubrIdxPos, FCffGlobalSubrCount);
  // 计算 Global Subr bias
  if FCffGlobalSubrCount < 1240 then
    FCffGlobalSubrBias := 107
  else if FCffGlobalSubrCount < 33900 then
    FCffGlobalSubrBias := 1131
  else
    FCffGlobalSubrBias := 32768;

  // Local Subrs — 从 Private DICT op 19 获取偏移
  FCffLocalSubrIdxPos := 0;
  FCffLocalSubrCount := 0;
  FCffLocalSubrBias := 107;
  if (LPrivateSize > 0) and (LPrivateOff > 0) then
  begin
    LPrivateAbs := LCffOff + LPrivateOff;
    LSubrsOff := ParseCffDictInt(LPrivateAbs, LPrivateSize, 19);
    if LSubrsOff > 0 then
    begin
      FCffLocalSubrIdxPos := LPrivateAbs + LSubrsOff;
      ParseCffIndex(FCffLocalSubrIdxPos, FCffLocalSubrCount);
      if FCffLocalSubrCount < 1240 then
        FCffLocalSubrBias := 107
      else if FCffLocalSubrCount < 33900 then
        FCffLocalSubrBias := 1131
      else
        FCffLocalSubrBias := 32768;
    end;
  end;

  FCffValid := True;
end;

function TTFontFace.GlyphOutlineCff(AGlyphIndex: UInt32): TFontGlyphOutline;
type
  TCffCallEntry = record
    DataOff: Int32;   // 子程序数据起始（绝对文件偏移）
    DataLen: Int32;   // 子程序数据长度
    RetPos: Int32;    // 返回位置（调用点之后的下一字节）
  end;
var
  LItemOff, LItemLen, LI, LB, LOp: Int32;
  LStack: array[0..47] of Int32;
  LST: Int32;  // stack top
  LCx, LCy: Int32;
  LHasWidth: Boolean;
  LWidth: Int32;
  LPointCount, LEndCount: Int32;
  LStartX, LStartY, LMx, LMy, LDx, LDy: Int32;
  LIdxOff, LOffSz, LVal1, LVal2, LDataStart: Int32;
  LI2: Int32;
  { call stack }
  LCallStack: array[0..9] of TCffCallEntry;
  LCallDepth: Int32;
  LCurDataOff, LCurDataEnd: Int32;  // 当前执行的 charstring 范围
  LSubrIdx, LSubrOff, LSubrLen: Int32;
  LSubrIdxPos, LSubrCount, LSubrBias: Int32;

  LPoints: array of TFontContourPoint;
  LEnds: array of UInt16;

  procedure EmitP(AX, AY: Int32; AOn: Boolean);
  begin
    if LPointCount >= Length(LPoints) then
      SetLength(LPoints, LPointCount + 64);
    LPoints[LPointCount].X := AX;
    LPoints[LPointCount].Y := AY;
    LPoints[LPointCount].OnCurve := AOn;
    Inc(LPointCount);
  end;

  procedure EndCtr;
  begin
    if LPointCount > 0 then
    begin
      if LEndCount >= Length(LEnds) then
        SetLength(LEnds, LEndCount + 8);
      LEnds[LEndCount] := LPointCount - 1;
      Inc(LEndCount);
    end;
  end;

  procedure CheckWidth;
  begin
    if (not LHasWidth) and (LST > 0) and (LST mod 2 = 1) then
    begin
      LWidth := FCffNominalWidthX + LStack[0];
      LHasWidth := True;
    end;
  end;

  procedure CubicToQuad(AX0, AY0, ADx1, ADy1, ADx2, ADy2, ADx3, ADy3: Int32);
  var
    LP1x, LP1y, LP2x, LP2y: Int32;
    LMx2, LMy2: Int32;
    LQ1x, LQ1y, LQ2x, LQ2y: Int32;
  begin
    LP1x := AX0 + ADx1; LP1y := AY0 + ADy1;
    LP2x := LP1x + ADx2; LP2y := LP1y + ADy2;
    LMx2 := LP2x + ADx3; LMy2 := LP2y + ADy3;
    LDx := (AX0 + 3 * LP1x + 3 * LP2x + LMx2) div 8;
    LDy := (AY0 + 3 * LP1y + 3 * LP2y + LMy2) div 8;
    LQ1x := 2 * LP1x - (AX0 + LDx + 1) div 2;
    LQ1y := 2 * LP1y - (AY0 + LDy + 1) div 2;
    LQ2x := 2 * LP2x - (LMx2 + LDx + 1) div 2;
    LQ2y := 2 * LP2y - (LMy2 + LDy + 1) div 2;
    EmitP(LQ1x, LQ1y, False);
    EmitP(LDx, LDy, True);
    EmitP(LQ2x, LQ2y, False);
    EmitP(LMx2, LMy2, True);
  end;

begin
  FontGlyphOutlineClear(Result);
  if not FCffValid then
    Exit;
  if AGlyphIndex >= UInt32(FCffCharStringsCount) then
    Exit;

  // 获取 charstring 数据偏移
  begin
    LIdxOff := FCffOff + FCffCharStringsOff;
    LOffSz := FCffCharStringsOffSize;
    LDataStart := LIdxOff + 3 + (FCffCharStringsCount + 1) * LOffSz;
    LVal1 := 0;
    for LI := 0 to LOffSz - 1 do
      LVal1 := (LVal1 shl 8) or ReadUInt8(LIdxOff + 3 + AGlyphIndex * LOffSz + LI);
    LVal2 := 0;
    for LI := 0 to LOffSz - 1 do
      LVal2 := (LVal2 shl 8) or ReadUInt8(LIdxOff + 3 + (AGlyphIndex + 1) * LOffSz + LI);
    LItemOff := LDataStart + LVal1 - 1;
    LItemLen := LVal2 - LVal1;
  end;
  if LItemLen <= 0 then
    Exit;

  LST := 0;
  LCx := 0; LCy := 0;
  LHasWidth := False;
  LWidth := FCffDefaultWidthX;
  LPointCount := 0; LEndCount := 0;
  LCallDepth := 0;
  LCurDataOff := LItemOff;
  LCurDataEnd := LItemOff + LItemLen;
  SetLength(LPoints, 128);
  SetLength(LEnds, 16);

  LI := LCurDataOff;
  while LI < LCurDataEnd do
  begin
    LB := ReadUInt8(LI);

    // 操作数
    if (LB >= 32) and (LB <= 246) then
    begin
      if LST < 48 then begin LStack[LST] := LB - 139; Inc(LST); end;
      Inc(LI); Continue;
    end
    else if (LB >= 247) and (LB <= 250) then
    begin
      if LST < 48 then begin LStack[LST] := (LB - 247) * 256 + ReadUInt8(LI + 1) + 108; Inc(LST); end;
      Inc(LI, 2); Continue;
    end
    else if (LB >= 251) and (LB <= 254) then
    begin
      if LST < 48 then begin LStack[LST] := -((LB - 251) * 256) - ReadUInt8(LI + 1) - 108; Inc(LST); end;
      Inc(LI, 2); Continue;
    end
    else if LB = 28 then
    begin
      if LST < 48 then begin LStack[LST] := ReadInt16BE(LI + 1); Inc(LST); end;
      Inc(LI, 3); Continue;
    end
    else if LB = 255 then
    begin
      if LST < 48 then begin LStack[LST] := Int32(ReadUInt32BE(LI + 1)) div 65536; Inc(LST); end;
      Inc(LI, 5); Continue;
    end;

    // 操作符
    LOp := LB;
    Inc(LI);
    if LB = 12 then begin LOp := (12 shl 8) or ReadUInt8(LI); Inc(LI); end;

    case LOp of
      1, 3, 18, 23: begin CheckWidth; LST := 0; end; // hstem, vstem, hstemhm, vstemhm

      19, 20: begin // hintmask, cntrmask
        CheckWidth; LST := 0;
        Inc(LI); // skip mask byte
      end;

      4: begin // vmoveto
        CheckWidth;
        if LST >= 1 then begin EndCtr; Inc(LCy, LStack[LST - 1]); EmitP(LCx, LCy, True); end;
        LST := 0;
      end;
      21: begin // rmoveto
        CheckWidth;
        if LST >= 2 then begin EndCtr; Inc(LCx, LStack[LST - 2]); Inc(LCy, LStack[LST - 1]); EmitP(LCx, LCy, True); end;
        LST := 0;
      end;
      22: begin // hmoveto
        CheckWidth;
        if LST >= 1 then begin EndCtr; Inc(LCx, LStack[LST - 1]); EmitP(LCx, LCy, True); end;
        LST := 0;
      end;

      5: begin // rlineto
        while LST >= 2 do begin Dec(LST, 2); Inc(LCx, LStack[LST]); Inc(LCy, LStack[LST + 1]); EmitP(LCx, LCy, True); end;
        LST := 0;
      end;
      6: begin // hlineto
        while LST >= 1 do begin
          Dec(LST); Inc(LCx, LStack[LST]); EmitP(LCx, LCy, True);
          if LST >= 1 then begin Dec(LST); Inc(LCy, LStack[LST]); EmitP(LCx, LCy, True); end;
        end;
        LST := 0;
      end;
      7: begin // vlineto
        while LST >= 1 do begin
          Dec(LST); Inc(LCy, LStack[LST]); EmitP(LCx, LCy, True);
          if LST >= 1 then begin Dec(LST); Inc(LCx, LStack[LST]); EmitP(LCx, LCy, True); end;
        end;
        LST := 0;
      end;

      8: begin // rrcurveto (cubic Bézier → 两段 quadratic)
        while LST >= 6 do begin
          Dec(LST, 6);
          LStartX := LCx; LStartY := LCy;
          CubicToQuad(LStartX, LStartY,
            LStack[LST], LStack[LST + 1], LStack[LST + 2],
            LStack[LST + 3], LStack[LST + 4], LStack[LST + 5]);
          LCx := LStartX + LStack[LST] + LStack[LST + 2] + LStack[LST + 4];
          LCy := LStartY + LStack[LST + 1] + LStack[LST + 3] + LStack[LST + 5];
        end;
        LST := 0;
      end;

      27: begin // hhcurveto
        while LST >= 4 do begin
          LStartX := LCx; LStartY := LCy;
          if LST mod 2 = 1 then begin
            CubicToQuad(LStartX, LStartY, LStack[1], LStack[0], LStack[2], LStack[3], LStack[4], 0);
            LCx := LStartX + LStack[1] + LStack[2] + LStack[4];
            LCy := LStartY + LStack[0] + LStack[3];
          end else begin
            CubicToQuad(LStartX, LStartY, LStack[0], 0, LStack[1], LStack[2], LStack[3], 0);
            LCx := LStartX + LStack[0] + LStack[1] + LStack[3];
            LCy := LStartY + LStack[2];
          end;
          LST := 0;
        end;
        LST := 0;
      end;

      31: begin // vvcurveto
        while LST >= 4 do begin
          LStartX := LCx; LStartY := LCy;
          if LST mod 2 = 1 then begin
            CubicToQuad(LStartX, LStartY, LStack[0], LStack[1], 0, LStack[2], 0, LStack[3]);
            LCx := LStartX + LStack[0];
            LCy := LStartY + LStack[1] + LStack[2] + LStack[3];
          end else begin
            CubicToQuad(LStartX, LStartY, 0, LStack[0], 0, LStack[1], 0, LStack[2]);
            LCx := LStartX;
            LCy := LStartY + LStack[0] + LStack[1] + LStack[2];
          end;
          LST := 0;
        end;
        LST := 0;
      end;

      30: begin // vhcurveto
        while LST >= 4 do begin
          LStartX := LCx; LStartY := LCy;
          if LST >= 5 then begin
            CubicToQuad(LStartX, LStartY, 0, LStack[0], LStack[1], LStack[2], LStack[3], LStack[4]);
            LCx := LStartX + LStack[1] + LStack[3];
            LCy := LStartY + LStack[0] + LStack[2] + LStack[4];
          end else begin
            CubicToQuad(LStartX, LStartY, 0, LStack[0], LStack[1], LStack[2], LStack[3], 0);
            LCx := LStartX + LStack[1] + LStack[3];
            LCy := LStartY + LStack[0] + LStack[2];
          end;
          LST := 0;
        end;
        LST := 0;
      end;

      29, 10: begin // callsubr (10), callgsubr (29)
        if LST > 0 then
        begin
          Dec(LST);
          // 计算带偏移的子程序索引
          if LOp = 10 then
          begin
            // callsubr — Local Subrs
            LSubrIdxPos := FCffLocalSubrIdxPos;
            LSubrCount := FCffLocalSubrCount;
            LSubrBias := FCffLocalSubrBias;
          end
          else
          begin
            // callgsubr — Global Subrs
            LSubrIdxPos := FCffGlobalSubrIdxPos;
            LSubrCount := FCffGlobalSubrCount;
            LSubrBias := FCffGlobalSubrBias;
          end;
          LSubrIdx := LStack[LST] + LSubrBias;
          if (LSubrIdx >= 0) and (LSubrIdx < LSubrCount) and (LCallDepth < 10) then
          begin
            // 获取子程序数据
            begin
              LIdxOff := LSubrIdxPos;
              LOffSz := ReadUInt8(LIdxOff + 2);
              LDataStart := LIdxOff + 3 + (LSubrCount + 1) * LOffSz;
              LVal1 := 0;
              for LI2 := 0 to LOffSz - 1 do
                LVal1 := (LVal1 shl 8) or ReadUInt8(LIdxOff + 3 + LSubrIdx * LOffSz + LI2);
              LVal2 := 0;
              for LI2 := 0 to LOffSz - 1 do
                LVal2 := (LVal2 shl 8) or ReadUInt8(LIdxOff + 3 + (LSubrIdx + 1) * LOffSz + LI2);
              LSubrOff := LDataStart + LVal1 - 1;
              LSubrLen := LVal2 - LVal1;
            end;
            if LSubrLen > 0 then
            begin
              // 保存当前执行上下文
              LCallStack[LCallDepth].DataOff := LCurDataOff;
              LCallStack[LCallDepth].DataLen := LCurDataEnd - LCurDataOff;
              LCallStack[LCallDepth].RetPos := LI;
              Inc(LCallDepth);
              // 跳转到子程序
              LCurDataOff := LSubrOff;
              LCurDataEnd := LSubrOff + LSubrLen;
              LI := LCurDataOff;
              Continue;
            end;
          end;
        end;
      end;
      11: begin // return — 从子程序返回
        if LCallDepth > 0 then
        begin
          Dec(LCallDepth);
          LCurDataOff := LCallStack[LCallDepth].DataOff;
          LCurDataEnd := LCurDataOff + LCallStack[LCallDepth].DataLen;
          LI := LCallStack[LCallDepth].RetPos;
          Continue;
        end;
      end;

      14: begin // endchar
        CheckWidth;
        EndCtr;
        LST := 0;
        Break;
      end;

      15, 16: LST := 0; // vsindex, blend
      (12 shl 8) or 34: begin // hflex — 7 args: dx1 dx2 dy2 dx3 dx4 dx5 dx6
        if LST >= 7 then begin
          LStartX := LCx; LStartY := LCy;
          // 第一段: dx1,0 dx2,dy2 dx3,0
          CubicToQuad(LStartX, LStartY, LStack[0], 0, LStack[1], LStack[2], LStack[3], 0);
          LCx := LStartX + LStack[0] + LStack[1] + LStack[3];
          LCy := LStartY + LStack[2];
          // 第二段: dx4,0 dx5,-dy2 dx6,0
          CubicToQuad(LCx, LCy, LStack[4], 0, LStack[5], -LStack[2], LStack[6], 0);
          LCx := LCx + LStack[4] + LStack[5] + LStack[6];
        end;
        LST := 0;
      end;
      (12 shl 8) or 35: begin // flex — 13 args: dx1..dy6 depth
        if LST >= 13 then begin
          LStartX := LCx; LStartY := LCy;
          // 第一段: dx1,dy1 dx2,dy2 dx3,dy3
          CubicToQuad(LStartX, LStartY, LStack[0], LStack[1], LStack[2], LStack[3], LStack[4], LStack[5]);
          LCx := LStartX + LStack[0] + LStack[2] + LStack[4];
          LCy := LStartY + LStack[1] + LStack[3] + LStack[5];
          // 第二段: dx4,dy4 dx5,dy5 dx6,dy6
          CubicToQuad(LCx, LCy, LStack[6], LStack[7], LStack[8], LStack[9], LStack[10], LStack[11]);
          LCx := LCx + LStack[6] + LStack[8] + LStack[10];
          LCy := LCy + LStack[7] + LStack[9] + LStack[11];
        end;
        LST := 0;
      end;
      (12 shl 8) or 36: begin // hflex1 — 9 args: dx1 dy1 dx2 dy2 dx3 dx4 dx5 dy5 dx6
        if LST >= 9 then begin
          LStartX := LCx; LStartY := LCy;
          // 第一段: dx1,dy1 dx2,dy2 dx3,0
          CubicToQuad(LStartX, LStartY, LStack[0], LStack[1], LStack[2], LStack[3], LStack[4], 0);
          LCx := LStartX + LStack[0] + LStack[2] + LStack[4];
          LCy := LStartY + LStack[1] + LStack[3];
          // 第二段: dx4,0 dx5,dy5 dx6,0
          CubicToQuad(LCx, LCy, LStack[5], 0, LStack[6], LStack[7], LStack[8], 0);
          LCx := LCx + LStack[5] + LStack[6] + LStack[8];
        end;
        LST := 0;
      end;
      (12 shl 8) or 37: begin // flex1 — 11 args: dx1 dy1 dx2 dy2 dx3 dy3 dx4 dy4 dx5 dy5 d6
        if LST >= 11 then begin
          LStartX := LCx; LStartY := LCy;
          // 第一段: dx1,dy1 dx2,dy2 dx3,dy3
          CubicToQuad(LStartX, LStartY, LStack[0], LStack[1], LStack[2], LStack[3], LStack[4], LStack[5]);
          LCx := LStartX + LStack[0] + LStack[2] + LStack[4];
          LCy := LStartY + LStack[1] + LStack[3] + LStack[5];
          // 判断 d6 是 dx 还是 dy（基于两段曲线的总位移）
          if Abs(LStack[0] + LStack[2] + LStack[4] + LStack[6] + LStack[8]) >
             Abs(LStack[1] + LStack[3] + LStack[5] + LStack[7] + LStack[9]) then
          begin
            // d6 = dy6, dx6 = 0
            CubicToQuad(LCx, LCy, LStack[6], LStack[7], LStack[8], LStack[9], 0, LStack[10]);
            LCy := LCy + LStack[7] + LStack[9] + LStack[10];
          end
          else
          begin
            // d6 = dx6, dy6 = 0
            CubicToQuad(LCx, LCy, LStack[6], LStack[7], LStack[8], LStack[9], LStack[10], 0);
            LCx := LCx + LStack[6] + LStack[8] + LStack[10];
          end;
        end;
        LST := 0;
      end;
    else
      LST := 0;
    end;
  end;

  EndCtr;
  SetLength(LPoints, LPointCount);
  SetLength(LEnds, LEndCount);
  Result.ContourCount := LEndCount;
  Result.Points := LPoints;
  Result.ContourEnds := LEnds;
end;

end.
