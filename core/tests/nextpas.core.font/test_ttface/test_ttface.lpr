program test_ttface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem,
  nextpas.core.base,
  nextpas.core.font.base,
  nextpas.core.font.ttface;

const
  TEST_FONT_PATH = '/usr/share/fonts/truetype/freefont/FreeMono.ttf';

var
  T: TTestRunner;

{ ========================================================================= }
{ 基本加载测试                                                               }
{ ========================================================================= }

procedure TestLoadValidFont;
var
  LFace: TTFontFace;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid: ' + LFace.LastError);
    Check(LFace.Format = fffTrueType, 'format should be TrueType');
    Check(LFace.GlyphCount > 0, 'should have glyphs');
  finally
    LFace.Free;
  end;
end;

procedure TestLoadMissingFile;
var
  LFace: TTFontFace;
begin
  LFace := TTFontFace.Create('/nonexistent/font.ttf');
  try
    Check(not LFace.IsValid, 'missing file should not be valid');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 指标测试                                                                   }
{ ========================================================================= }

procedure TestFontMetrics;
var
  LFace: TTFontFace;
  LMetrics: TFontMetrics;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LMetrics := LFace.Metrics;
    Check(LMetrics.UnitsPerEm > 0, 'UnitsPerEm should be positive');
    Check(LMetrics.UnitsPerEm <= 16384, 'UnitsPerEm should be reasonable');
    Check(LMetrics.Ascender > 0, 'Ascender should be positive');
    Check(LMetrics.Descender < 0, 'Descender should be negative');
    Check(LMetrics.XMin < LMetrics.XMax, 'XMin should be < XMax');
    Check(LMetrics.YMin < LMetrics.YMax, 'YMin should be < YMax');
  finally
    LFace.Free;
  end;
end;

procedure TestGlyphCount;
var
  LFace: TTFontFace;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    Check(LFace.GlyphCount > 100, 'FreeMono should have > 100 glyphs');
    Check(LFace.GlyphCount < 65536, 'glyph count should be < 65536');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ cmap 查找测试                                                              }
{ ========================================================================= }

procedure TestCmapLookupAscii;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');

    // ASCII 字母应该映射到非零字形
    LGlyphIdx := LFace.LookupCodepoint(Ord('A'));
    Check(LGlyphIdx > 0, '"A" should map to non-zero glyph');

    LGlyphIdx := LFace.LookupCodepoint(Ord('z'));
    Check(LGlyphIdx > 0, '"z" should map to non-zero glyph');

    // 空格
    LGlyphIdx := LFace.LookupCodepoint(Ord(' '));
    Check(LGlyphIdx > 0, 'space should map to non-zero glyph');
  finally
    LFace.Free;
  end;
end;

procedure TestCmapLookupDigits;
var
  LFace: TTFontFace;
  I: Int32;
  LGlyphIdx: UInt32;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    for I := 0 to 9 do
    begin
      LGlyphIdx := LFace.LookupCodepoint(Ord('0') + I);
      Check(LGlyphIdx > 0, Format('digit %d should map to non-zero glyph', [I]));
    end;
  finally
    LFace.Free;
  end;
end;

procedure TestCmapLookupUnmappedCodepoint;
var
  LFace: TTFontFace;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    // 使用一个不太可能在 FreeMono 中映射的私有使用区 codepoint
    LFace.LookupCodepoint($F0001);
    // 应该返回 0（.notdef）或非零（如果字体支持）
    // 关键是不崩溃
    Check(True, 'unmapped codepoint lookup should not crash');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 字形水平度量测试                                                            }
{ ========================================================================= }

procedure TestGlyphHorizontalMetric;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
  LHMetric: TFontHorizontalMetric;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LGlyphIdx := LFace.LookupCodepoint(Ord('A'));
    Check(LGlyphIdx > 0, '"A" should have glyph');

    LHMetric := LFace.GlyphHorizontalMetric(LGlyphIdx);
    Check(LHMetric.AdvanceWidth > 0, 'advance width should be positive');
    // FreeMono 是等宽字体，所有字形 advance 应该相同
  finally
    LFace.Free;
  end;
end;

procedure TestGlyphHorizontalMetricBoundaries;
var
  LFace: TTFontFace;
  LHMetric: TFontHorizontalMetric;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    // Glyph 0（.notdef）应该有度量
    LHMetric := LFace.GlyphHorizontalMetric(0);
    Check(LHMetric.AdvanceWidth > 0, '.notdef should have advance width');

    // 超出范围的字形索引不应该崩溃
    LHMetric := LFace.GlyphHorizontalMetric($FFFFFFF);
    Check(True, 'out-of-range glyph index should not crash');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 字形轮廓测试                                                               }
{ ========================================================================= }

procedure TestGlyphOutlineSimple;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
  LOutline: TFontGlyphOutline;
  LOnCurveCount, LI: Int32;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LGlyphIdx := LFace.LookupCodepoint(Ord('A'));
    Check(LGlyphIdx > 0, '"A" should have glyph');

    LOutline := LFace.GlyphOutline(LGlyphIdx);
    Check(LOutline.ContourCount > 0, '"A" should have contours');
    Check(Length(LOutline.Points) > 0, '"A" should have points');
    Check(Length(LOutline.ContourEnds) = LOutline.ContourCount,
      'contour ends count should match');

    // 检查 on-curve 标志被正确设置
    LOnCurveCount := 0;
    for LI := 0 to High(LOutline.Points) do
      if LOutline.Points[LI].OnCurve then
        Inc(LOnCurveCount);
    Check(LOnCurveCount > 0, '"A" should have on-curve points');

    // 边界框应合理
    Check(LOutline.XMin < LOutline.XMax, 'XMin should be < XMax');
    Check(LOutline.YMin < LOutline.YMax, 'YMin should be < YMax');
  finally
    LFace.Free;
  end;
end;

procedure TestGlyphOutlineSpace;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
  LOutline: TFontGlyphOutline;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LGlyphIdx := LFace.LookupCodepoint(Ord(' '));
    Check(LGlyphIdx > 0, 'space should have glyph');

    LOutline := LFace.GlyphOutline(LGlyphIdx);
    // 空格通常没有轮廓（空字形）
    Check(LOutline.ContourCount = 0, 'space glyph should have no contours');
  finally
    LFace.Free;
  end;
end;

procedure TestGlyphOutlineMultipleGlyphs;
var
  LFace: TTFontFace;
  LOutline: TFontGlyphOutline;
  LChars: AnsiString;
  I, LTotalPoints: Int32;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LChars := 'ABCDWMmgpq';
    LTotalPoints := 0;
    for I := 1 to Length(LChars) do
    begin
      LOutline := LFace.GlyphOutline(
        LFace.LookupCodepoint(Ord(LChars[I])));
      if LOutline.ContourCount > 0 then
        Inc(LTotalPoints, Length(LOutline.Points));
    end;
    Check(LTotalPoints > 50, 'collective points should be > 50');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 字形指标测试                                                                }
{ ========================================================================= }

procedure TestGlyphMetricsFromOutline;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
  LGMetrics: TFontGlyphMetrics;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LGlyphIdx := LFace.LookupCodepoint(Ord('A'));
    Check(LGlyphIdx > 0, '"A" should have glyph');

    LGMetrics := LFace.GlyphMetrics(LGlyphIdx);
    Check(LGMetrics.AdvanceWidth > 0, 'advance width should be positive');
    Check(LGMetrics.Width > 0, 'width should be positive for "A"');
    Check(LGMetrics.Height > 0, 'height should be positive for "A"');
  finally
    LFace.Free;
  end;
end;

procedure TestGlyphMetricsConsistency;
var
  LFace: TTFontFace;
  LGlyphIdx: UInt32;
  LGMetrics: TFontGlyphMetrics;
  LHMetric: TFontHorizontalMetric;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LGlyphIdx := LFace.LookupCodepoint(Ord('I'));
    Check(LGlyphIdx > 0, '"I" should have glyph');

    LGMetrics := LFace.GlyphMetrics(LGlyphIdx);
    LHMetric := LFace.GlyphHorizontalMetric(LGlyphIdx);
    // advance width 应该一致
    Check(LGMetrics.AdvanceWidth = LHMetric.AdvanceWidth,
      'advance width should be consistent');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 等宽字体一致性测试                                                          }
{ ========================================================================= }

procedure TestMonospaceConsistency;
var
  LFace: TTFontFace;
  LChars: AnsiString;
  I: Int32;
  LGlyphIdx: UInt32;
  LFirstAdvance, LCurrentAdvance: Int32;
begin
  LFace := TTFontFace.Create(TEST_FONT_PATH);
  try
    Check(LFace.IsValid, 'font should be valid');
    LChars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    LFirstAdvance := -1;
    for I := 1 to Length(LChars) do
    begin
      LGlyphIdx := LFace.LookupCodepoint(Ord(LChars[I]));
      if LGlyphIdx = 0 then
        Continue;
      LCurrentAdvance := LFace.GlyphHorizontalMetric(LGlyphIdx).AdvanceWidth;
      if LFirstAdvance < 0 then
        LFirstAdvance := LCurrentAdvance
      else
        Check(LCurrentAdvance = LFirstAdvance,
          Format('glyph "%s" advance should match first glyph (%d vs %d)',
            [LChars[I], LCurrentAdvance, LFirstAdvance]));
    end;
    Check(LFirstAdvance > 0, 'advance width should be positive');
  finally
    LFace.Free;
  end;
end;

{ ========================================================================= }
{ 内存管理测试                                                               }
{ ========================================================================= }

procedure TestFaceCreateDestroy;
var
  I: Int32;
  LFace: TTFontFace;
begin
  // 多次创建/销毁不应泄漏
  for I := 1 to 10 do
  begin
    LFace := TTFontFace.Create(TEST_FONT_PATH);
    try
      Check(LFace.IsValid, 'font should be valid on iteration');
      LFace.LookupCodepoint(Ord('A'));
      LFace.GlyphOutline(LFace.LookupCodepoint(Ord('A')));
    finally
      LFace.Free;
    end;
  end;
end;

{ ========================================================================= }
{ main                                                                      }
{ ========================================================================= }

begin
  T := TTestRunner.Create('nextpas.core.font.ttface');

  T.Run('Load: Valid font', @TestLoadValidFont);
  T.Run('Load: Missing file', @TestLoadMissingFile);

  T.Run('Metrics: Font metrics', @TestFontMetrics);
  T.Run('Metrics: Glyph count', @TestGlyphCount);

  T.Run('Cmap: ASCII lookup', @TestCmapLookupAscii);
  T.Run('Cmap: Digit lookup', @TestCmapLookupDigits);
  T.Run('Cmap: Unmapped codepoint', @TestCmapLookupUnmappedCodepoint);

  T.Run('Hmtx: Horizontal metric', @TestGlyphHorizontalMetric);
  T.Run('Hmtx: Boundary conditions', @TestGlyphHorizontalMetricBoundaries);

  T.Run('Outline: Simple glyph', @TestGlyphOutlineSimple);
  T.Run('Outline: Space glyph', @TestGlyphOutlineSpace);
  T.Run('Outline: Multiple glyphs', @TestGlyphOutlineMultipleGlyphs);

  T.Run('GlyphMetrics: From outline', @TestGlyphMetricsFromOutline);
  T.Run('GlyphMetrics: Consistency', @TestGlyphMetricsConsistency);

  T.Run('Monospace: Consistency', @TestMonospaceConsistency);

  T.Run('Memory: Create/Destroy cycle', @TestFaceCreateDestroy);

  T.Summary;
end.
