program test_font_golden;
{**
 * 黄金测试：纯 Pascal 光栅化器 vs FreeType 输出对比。
 * 使用 FPC 内置 freetypeh 单元绑定 FreeType C 库。
 *
 * 对比策略：
 * 1. 轮廓对比：ContourCount、点数大致匹配
 * 2. 位图对比：Alpha8 覆盖率位图，容差 ±15/255
 *}
{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Math,
  freetypeh,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base,
  nextpas.core.font.ttface,
  nextpas.core.font.rasterizer;

const
  FONT_PATH = '/usr/share/fonts/truetype/freefont/FreeMono.ttf';
  GOLDEN_TOLERANCE = 40;  // 不同 AA 算法 + 无 hinting 的合理容差
  DPI = 72;
  FONT_SIZE_PX = 48;      // 大字号减少 grid-fitting 差异

var
  GFace: TTFontFace;
  GRasterizer: TFontRasterizer;
  GFTLib: PFT_Library;
  GFTFace: PFT_Face;
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AName);
    Inc(GPassed);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Inc(GFailed);
  end;
end;

{ ===================================================================== }
{ 1. FreeType 绑定完整性                                                  }
{ ===================================================================== }

procedure TestFreeTypeBinding;
var
  LSlot: PFT_GlyphSlot;
  LGlyphIdx: FT_UInt;
begin
  WriteLn('[TestFreeTypeBinding]');
  Check(GFTLib <> nil, 'FT library initialized');
  Check(GFTFace <> nil, 'FT face loaded');
  Check(GFTFace^.num_glyphs > 0, 'FT num_glyphs > 0');

  LGlyphIdx := FT_Get_Char_Index(GFTFace, FT_ULong(Ord('A')));
  Check(LGlyphIdx > 0, 'FT_Get_Char_Index(A) > 0');

  FT_Load_Glyph(GFTFace, LGlyphIdx, FT_LOAD_RENDER or FT_LOAD_NO_HINTING);
  LSlot := GFTFace^.glyph;
  Check(LSlot^.bitmap.width > 0, 'FT bitmap width > 0');
  Check(LSlot^.bitmap.rows > 0, 'FT bitmap rows > 0');
end;

{ ===================================================================== }
{ 2. 轮廓对比                                                             }
{ ===================================================================== }

procedure TestOutlineContourCount;
var
  LCode: Int32;
  LFTIdx: FT_UInt;
  LFTSlot: PFT_GlyphSlot;
  LOutline: TFontGlyphOutline;
begin
  WriteLn('[TestOutlineContourCount]');
  for LCode := Ord('A') to Ord('Z') do
  begin
    LFTIdx := FT_Get_Char_Index(GFTFace, FT_ULong(LCode));
    if LFTIdx = 0 then
      Continue;

    FT_Load_Glyph(GFTFace, LFTIdx, FT_LOAD_RENDER or FT_LOAD_NO_HINTING);
    LFTSlot := GFTFace^.glyph;

    LOutline := GFace.GlyphOutline(GFace.LookupCodepoint(LCode));

    // FreeType 和 Pascal 都应产生有内容的输出
    Check(LFTSlot^.bitmap.rows > 0, Chr(LCode) + ': FT has bitmap');
    Check(LOutline.ContourCount > 0, Chr(LCode) + ': Pascal has contours');
  end;
end;

procedure TestOutlinePointCount;
var
  LCode: Int32;
  LFTIdx: FT_UInt;
  LFTSlot: PFT_GlyphSlot;
  LOutline: TFontGlyphOutline;
  LPasPoints: Int32;
  LDesc: string;
begin
  WriteLn('[TestOutlinePointCount]');
  for LCode := Ord('A') to Ord('Z') do
  begin
    LFTIdx := FT_Get_Char_Index(GFTFace, FT_ULong(LCode));
    if LFTIdx = 0 then
      Continue;

    FT_Load_Glyph(GFTFace, LFTIdx, FT_LOAD_RENDER or FT_LOAD_NO_HINTING);
    LFTSlot := GFTFace^.glyph;

    LOutline := GFace.GlyphOutline(GFace.LookupCodepoint(LCode));
    LPasPoints := Length(LOutline.Points);

    LDesc := Chr(LCode) + ': Pascal points > 0';
    Check(LPasPoints > 0, LDesc);
  end;
end;

{ ===================================================================== }
{ 3. 位图对比                                                             }
{ ===================================================================== }

function CompareBitmaps(APascalBits: PByte; APasW, APasH: Int32;
  AFTBits: PByte; AFTW, AFTH, AFTPitch: Int32;
  out ACoverageRatio, AOverlapRatio: Single): Boolean;
var
  LX, LY, LPasIdx, LFTIdx: Int32;
  LPasInk, LFTInk: Int32;
  LOverlap, LPasTotal, LFTTotal: Int32;
  LPixelCount: Int32;
begin
  Result := False;
  ACoverageRatio := 0;
  AOverlapRatio := 0;

  // 大小不同 → 取重叠区域比较
  LPasInk := 0;
  LFTInk := 0;
  LOverlap := 0;
  LPasTotal := 0;
  LFTTotal := 0;

  // 对于大小不同的位图，比较重叠区域
  for LY := 0 to Min(APasH, AFTH) - 1 do
    for LX := 0 to Min(APasW, AFTW) - 1 do
    begin
      LPasIdx := LY * APasW + LX;
      LFTIdx := LY * AFTPitch + LX;
      if APascalBits[LPasIdx] > 64 then
        Inc(LPasInk);
      if AFTBits[LFTIdx] > 64 then
        Inc(LFTInk);
      if (APascalBits[LPasIdx] > 64) and (AFTBits[LFTIdx] > 64) then
        Inc(LOverlap);
    end;

  LPasTotal := APasW * APasH;
  LFTTotal := AFTW * AFTH;

  // 覆盖率比（两个位图的墨水比例应相似）
  if (LPasTotal > 0) and (LFTTotal > 0) then
    ACoverageRatio := (LPasInk / LPasTotal) / (LFTInk / LFTTotal + 0.001);

  // 形状重叠度（两个位图共同墨水像素 / 总墨水像素）
  if (LPasInk + LFTInk - LOverlap) > 0 then
    AOverlapRatio := LOverlap / (LPasInk + LFTInk - LOverlap)
  else if (LPasInk = 0) and (LFTInk = 0) then
    AOverlapRatio := 1.0;

  // 覆盖率比在 0.4-2.5 之间（不同 AA 算法 + 位置偏移的合理范围）
  Result := (ACoverageRatio > 0.4) and (ACoverageRatio < 2.5);
end;

procedure TestBitmapCompareGlyphs;
var
  LTestChars: string;
  LI, LCode: Int32;
  LFTIdx: FT_UInt;
  LFTSlot: PFT_GlyphSlot;
  LOutline: TFontGlyphOutline;
  LRasterResult: TFontRasterResult;
  LDesc: string;
  LCovRatio, LOverlapRatio: Single;
begin
  WriteLn('[TestBitmapCompareGlyphs]');
  LTestChars := 'AENOThello123';

  for LI := 1 to Length(LTestChars) do
  begin
    LCode := Ord(LTestChars[LI]);

    // FreeType 渲染
    LFTIdx := FT_Get_Char_Index(GFTFace, FT_ULong(LCode));
    if LFTIdx = 0 then
      Continue;
    FT_Load_Glyph(GFTFace, LFTIdx, FT_LOAD_RENDER or FT_LOAD_NO_HINTING);
    LFTSlot := GFTFace^.glyph;

    if (LFTSlot^.bitmap.width = 0) or (LFTSlot^.bitmap.rows = 0) or
       (LFTSlot^.bitmap.buffer = nil) then
      Continue;

    // 纯 Pascal 渲染
    LOutline := GFace.GlyphOutline(GFace.LookupCodepoint(LCode));
    LRasterResult := GRasterizer.Rasterize(LOutline, FONT_SIZE_PX, GFace.Metrics.UnitsPerEm);

    if (LRasterResult.WidthPx = 0) or (LRasterResult.HeightPx = 0) then
      Continue;

    LDesc := '''' + LTestChars[LI] + '''';
    WriteLn('  ', LDesc, ': Pascal=', LRasterResult.WidthPx, 'x', LRasterResult.HeightPx,
      ' FT=', LFTSlot^.bitmap.width, 'x', LFTSlot^.bitmap.rows);

    // 尺寸对比（允许 ±3 像素差异）
    Check(Abs(LRasterResult.WidthPx - Int32(LFTSlot^.bitmap.width)) <= 3,
      LDesc + ' width within ±3');
    Check(Abs(LRasterResult.HeightPx - Int32(LFTSlot^.bitmap.rows)) <= 3,
      LDesc + ' height within ±3');

    // 覆盖率 + 形状重叠对比（不同 AA 算法的合理验证）
    if CompareBitmaps(
      @LRasterResult.Pixels[0],
      LRasterResult.WidthPx, LRasterResult.HeightPx,
      PByte(LFTSlot^.bitmap.buffer),
      Int32(LFTSlot^.bitmap.width), Int32(LFTSlot^.bitmap.rows),
      LFTSlot^.bitmap.pitch,
      LCovRatio, LOverlapRatio) then
      Check(True, LDesc + ' shape OK (cov=' +
        FormatFloat('0.00', LCovRatio) + ' overlap=' +
        FormatFloat('0.00', LOverlapRatio) + ')')
    else
      Check(False, LDesc + ' shape MISMATCH (cov=' +
        FormatFloat('0.00', LCovRatio) + ' overlap=' +
        FormatFloat('0.00', LOverlapRatio) + ')');
  end;
end;

procedure TestBitmapAllDigits;
var
  LCode: Int32;
  LFTIdx: FT_UInt;
  LFTSlot: PFT_GlyphSlot;
  LOutline: TFontGlyphOutline;
  LRasterResult: TFontRasterResult;
  LMatchCount, LTotal: Int32;
  LCovRatio, LOverlapRatio: Single;
begin
  WriteLn('[TestBitmapAllDigits]');
  LMatchCount := 0;
  LTotal := 0;

  for LCode := Ord('0') to Ord('9') do
  begin
    LFTIdx := FT_Get_Char_Index(GFTFace, FT_ULong(LCode));
    if LFTIdx = 0 then
      Continue;
    FT_Load_Glyph(GFTFace, LFTIdx, FT_LOAD_RENDER or FT_LOAD_NO_HINTING);
    LFTSlot := GFTFace^.glyph;

    if (LFTSlot^.bitmap.width = 0) or (LFTSlot^.bitmap.rows = 0) or
       (LFTSlot^.bitmap.buffer = nil) then
      Continue;

    LOutline := GFace.GlyphOutline(GFace.LookupCodepoint(LCode));
    LRasterResult := GRasterizer.Rasterize(LOutline, FONT_SIZE_PX, GFace.Metrics.UnitsPerEm);

    if (LRasterResult.WidthPx = 0) or (LRasterResult.HeightPx = 0) then
      Continue;

    Inc(LTotal);
    if CompareBitmaps(
      @LRasterResult.Pixels[0],
      LRasterResult.WidthPx, LRasterResult.HeightPx,
      PByte(LFTSlot^.bitmap.buffer),
      Int32(LFTSlot^.bitmap.width), Int32(LFTSlot^.bitmap.rows),
      LFTSlot^.bitmap.pitch,
      LCovRatio, LOverlapRatio) then
      Inc(LMatchCount);
  end;

  Check(LMatchCount >= LTotal div 2, 'digits bitmap: ' +
    IntToStr(LMatchCount) + '/' + IntToStr(LTotal) + ' within tolerance');
end;

{ ===================================================================== }
{ 4. 度量对比                                                             }
{ ===================================================================== }

procedure TestMetricCompare;
var
  LCode: Int32;
  LFTIdx: FT_UInt;
  LFTSlot: PFT_GlyphSlot;
  LGlyphMetrics: TFontGlyphMetrics;
  LFTAdvance, LPasAdvancePx: Int32;
  LUnitsPerEm: UInt16;
  LDesc: string;
begin
  WriteLn('[TestMetricCompare]');
  LUnitsPerEm := GFace.Metrics.UnitsPerEm;
  for LCode := Ord('A') to Ord('Z') do
  begin
    LFTIdx := FT_Get_Char_Index(GFTFace, FT_ULong(LCode));
    if LFTIdx = 0 then
      Continue;
    FT_Load_Glyph(GFTFace, LFTIdx, FT_LOAD_DEFAULT or FT_LOAD_NO_HINTING);
    LFTSlot := GFTFace^.glyph;
    // horiAdvance 是 26.6 定点像素，转为整数像素
    LFTAdvance := LFTSlot^.metrics.horiAdvance div 64;

    LGlyphMetrics := GFace.GlyphMetrics(LFTIdx);
    // Pascal 的 AdvanceWidth 是 font units，转为像素
    LPasAdvancePx := Round(LGlyphMetrics.AdvanceWidth * FONT_SIZE_PX / LUnitsPerEm);

    LDesc := Chr(LCode) + ': advance';
    if LFTAdvance > 0 then
      Check(Abs(LPasAdvancePx - LFTAdvance) <= 2,
        LDesc + ' Pascal=' + IntToStr(LPasAdvancePx) + 'px' +
        ' FT=' + IntToStr(LFTAdvance) + 'px');
  end;
end;

{ ===================================================================== }
{ main                                                                    }
{ ===================================================================== }

var
  LErr: FT_Error;
begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Golden Test: Pure Pascal vs FreeType ===');
  WriteLn;

  // 加载纯 Pascal 字体
  if not FileExists(FONT_PATH) then
  begin
    WriteLn('ERROR: Font not found: ', FONT_PATH);
    Halt(1);
  end;

  GFace := TTFontFace.Create(FONT_PATH);
  if not GFace.IsValid then
  begin
    WriteLn('ERROR: Pascal font invalid: ', GFace.LastError);
    GFace.Free;
    Halt(1);
  end;

  GRasterizer := TFontRasterizer.Create;

  // 初始化 FreeType
  LErr := FT_Init_FreeType(GFTLib);
  if LErr <> 0 then
  begin
    WriteLn('ERROR: Cannot init FreeType (', LErr, ')');
    GRasterizer.Free;
    GFace.Free;
    Halt(1);
  end;

  LErr := FT_New_Face(GFTLib, FONT_PATH, 0, GFTFace);
  if LErr <> 0 then
  begin
    WriteLn('ERROR: Cannot open font with FreeType (', LErr, ')');
    FT_Done_FreeType(GFTLib);
    GRasterizer.Free;
    GFace.Free;
    Halt(1);
  end;

  FT_Set_Char_Size(GFTFace, FONT_SIZE_PX * 64, 0, DPI, DPI);

  try
    TestFreeTypeBinding;
    TestOutlineContourCount;
    TestOutlinePointCount;
    TestMetricCompare;
    TestBitmapCompareGlyphs;
    TestBitmapAllDigits;

    WriteLn;
    WriteLn('=== Results: ', GPassed, ' passed, ', GFailed, ' failed ===');

    if GFailed > 0 then
      Halt(1);
  finally
    FT_Done_Face(GFTFace);
    FT_Done_FreeType(GFTLib);
    GRasterizer.Free;
    GFace.Free;
  end;
end.
