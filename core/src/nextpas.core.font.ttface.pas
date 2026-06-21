unit nextpas.core.font.ttface;
{**
 * @desc 纯 Pascal TTF/OTF 字体文件解析器。
 *       支持 sfnt 表目录、head/hhea/maxp/cmap/loca/glyf/hmtx/os2 表。
 *       只支持 TrueType glyf 轮廓，不支持 CFF/CFF2。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  nextpas.core.base,
  nextpas.core.font.base;

type
  {** 纯 Pascal TrueType 字体面 }
  TTFontFace = class
  private
    FData: array of Byte;           // 完整文件数据
    FDataLength: Int32;
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
  LStream: TFileStream;
  LSize: Int32;
begin
  inherited Create;
  FValid := False;
  FHasFmt4 := False;
  FHasFmt12 := False;
  FLastError := '';

  if not FileExists(AFilePath) then
    Exit;

  try
    LStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyNone);
    try
      LSize := LStream.Size;
      if LSize < 12 then
        Exit;
      SetLength(FData, LSize);
      FDataLength := LSize;
      LStream.ReadBuffer(FData[0], LSize);
    finally
      LStream.Free;
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
begin
  FFormat := fffUnknown;
  LMagic := ReadUInt32BE(0);
  if LMagic = FONT_MAGIC_TRUETYPE then
    FFormat := fffTrueType
  else if LMagic = FONT_MAGIC_OTTO then
    FFormat := fffOpenTypeCff;
end;

procedure TTFontFace.ParseTableDirectory;
var
  I: Int32;
  LOffset: Int32;
begin
  FTableCount := ReadUInt16BE(4);
  if (FTableCount < 1) or (FTableCount > 256) then
    raise EFontError.Create('Invalid table count');

  SetLength(FTables, FTableCount);
  LOffset := 12; // 跳过 TTC header (sfVersion + numTables + searchRange + entrySelector + rangeShift)
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
{ 公共 API                                                                   }
{ ========================================================================= }

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
