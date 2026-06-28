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
    FLocaOffsets: array of UInt32;
    FOs2: TFontOs2Table;
    FPairPosSubtables: TFontPairPosSubtableArray;
    FPairPosFmt1Subtables: TFontPairPosFmt1SubtableArray;
    FLigatureSubtables: TFontLigatureSubtableArray;
    FSingleSubstSubtables: TFontSingleSubstSubtableArray;
    FSinglePosSubtables: TFontSinglePosSubtableArray;
    FMarkToBaseSubtables: TFontMarkToBaseSubtableArray;
    FMarkToMarkSubtables: TFontMarkToMarkSubtableArray;
    {** Feature-specific lookup indices }
    FKernLookups: TFontFeatureLookupIndexArray;     // GPOS 'kern'
    FMarkLookups: TFontFeatureLookupIndexArray;      // GPOS 'mark'
    FMkmkLookups: TFontFeatureLookupIndexArray;      // GPOS 'mkmk'
    FLigaLookups: TFontFeatureLookupIndexArray;      // GSUB 'liga'
    FCligLookups: TFontFeatureLookupIndexArray;      // GSUB 'clig'
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
    if not (FFormat in [fffTrueType]) then
      Exit;
    ParseTableDirectory;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseCmap;
    ParseLoca;
    ParseHmtx;
    ParseOs2;
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
  FLastError := '';

  LLen := Length(AData);
  if LLen < 12 then
    Exit;

  SetLength(FData, LLen);
  FDataLength := LLen;
  Move(AData[0], FData[0], LLen);

  try
    ParseHeader;
    if not (FFormat in [fffTrueType]) then
      Exit;
    ParseTableDirectory;
    ParseHead;
    ParseHhea;
    ParseMaxp;
    ParseCmap;
    ParseLoca;
    ParseHmtx;
    ParseOs2;
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
begin
  LIdx := FindTable(TABLE_TAG_CMAP);
  if LIdx < 0 then
    Exit; // 没有 cmap 不致命

  LOff := Int32(FTables[LIdx].Offset);
  LSubtableCount := ReadUInt16BE(LOff + 2);

  FHasFmt4 := False;
  FHasFmt12 := False;

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
  LEntrySize, LXAdvBit, LIdx: Int32;
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
  // Parse GPOS feature list for kern/mark/mkmk features.
  FKernLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_KERN]);
  FMarkLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_MARK]);
  FMkmkLookups := ParseFeatureLookups(LGposOff,
    [FEATURE_TAG_MKMK]);

  for LI := 0 to LLookupCount - 1 do
  begin
    if FDataLength < LLookupListOff + 4 + LI * 2 then
      Continue;
    LLookupOff := LLookupListOff + ReadUInt16BE(LLookupListOff + 2 + LI * 2);
    if FDataLength < LLookupOff + 6 then
      Continue;
    LLookupType := ReadUInt16BE(LLookupOff);

    // SinglePos (type 1).
    if LLookupType = GPOS_LOOKUP_SINGLE_POS then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
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
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
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

    // MarkBasePos (type 4).
    if LLookupType = GPOS_LOOKUP_MARK_TO_BASE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
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

    // MarkMarkPos (type 6).
    if LLookupType = GPOS_LOOKUP_MARK_TO_MARK then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
      for LJ := 0 to LSubtableCount - 1 do
      begin
        if FDataLength < LLookupOff + 8 + LJ * 2 then
          Continue;
        LSubOff := LLookupOff + ReadUInt16BE(LLookupOff + 6 + LJ * 2);
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
  end;
end;

procedure TTFontFace.ParseGsub;
var
  LTableIdx, LGsubOff: Int32;
  LLookupListOff, LLookupCount, LI, LJ: Int32;
  LLookupOff, LLookupType, LSubtableCount: Int32;
  LSubOff, LSub, LSubFmt, LCovOff, LLSCount, LIdx: Int32;
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

    // Single Substitution (type 1).
    if LLookupType = GSUB_LOOKUP_SINGLE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
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

    // Ligature Substitution (type 4).
    if LLookupType = GSUB_LOOKUP_LIGATURE then
    begin
      LSubtableCount := ReadUInt16BE(LLookupOff + 4);
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

end.
