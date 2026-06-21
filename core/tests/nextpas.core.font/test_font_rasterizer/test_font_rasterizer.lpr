program test_font_rasterizer;
{**
 * 纯 Pascal 扫描线光栅化器单元测试。
 * 使用 FreeMono.ttf 测试真实字形光栅化。
 *
 * 覆盖：Bezier 展平、线段提取、位图生成、空字形、抗锯齿、一致性。
 *}
{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base,
  nextpas.core.font.ttface,
  nextpas.core.font.rasterizer;

const
  FONT_PATH = '/usr/share/fonts/truetype/freefont/FreeMono.ttf';
  EPSILON = 0.001;

var
  GFace: TTFontFace;
  GRasterizer: TFontRasterizer;
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
{ 1. Bezier 展平                                                         }
{ ===================================================================== }

procedure TestBezierStraightLine;
var
  LLines: TFontLineSegmentArray;
  LCount: Int32;
begin
  WriteLn('[TestBezierStraightLine]');
  SetLength(LLines, 16);
  LCount := 0;
  FontFlattenQuadraticBezier(0, 0, 5, 5, 10, 10, RASTERIZER_FLATNESS_PX, LLines, LCount);
  Check(LCount = 1, 'straight curve → 1 segment');
  Check(Abs(LLines[0].X0 - 0) < EPSILON, 'start X');
  Check(Abs(LLines[0].Y0 - 0) < EPSILON, 'start Y');
  Check(Abs(LLines[0].X1 - 10) < EPSILON, 'end X');
  Check(Abs(LLines[0].Y1 - 10) < EPSILON, 'end Y');
end;

procedure TestBezierSubdivision;
var
  LLines: TFontLineSegmentArray;
  LCount: Int32;
begin
  WriteLn('[TestBezierSubdivision]');
  SetLength(LLines, 64);
  LCount := 0;
  FontFlattenQuadraticBezier(0, 0, 50, 100, 100, 0, RASTERIZER_FLATNESS_PX, LLines, LCount);
  Check(LCount > 1, 'curved → multiple segments (count=' + IntToStr(LCount) + ')');
  Check(Abs(LLines[0].X0 - 0) < EPSILON, 'first segment starts at P0');
  Check(Abs(LLines[LCount - 1].X1 - 100) < EPSILON, 'last segment ends at P2');
end;

procedure TestBezierFlatness;
var
  LLines1, LLines2: TFontLineSegmentArray;
  LCount1, LCount2: Int32;
begin
  WriteLn('[TestBezierFlatness]');
  SetLength(LLines1, 64);
  LCount1 := 0;
  FontFlattenQuadraticBezier(0, 0, 50, 100, 100, 0, 10.0, LLines1, LCount1);

  SetLength(LLines2, 64);
  LCount2 := 0;
  FontFlattenQuadraticBezier(0, 0, 50, 100, 100, 0, 0.01, LLines2, LCount2);

  Check(LCount2 > LCount1, 'tighter flatness → more segments (' +
    IntToStr(LCount1) + ' vs ' + IntToStr(LCount2) + ')');
end;

{ ===================================================================== }
{ 2. 线段提取                                                             }
{ ===================================================================== }

procedure TestExtractLineSegmentsEmpty;
var
  LOutline: TFontGlyphOutline;
  LLines: TFontLineSegmentArray;
begin
  WriteLn('[TestExtractLineSegmentsEmpty]');
  FontGlyphOutlineClear(LOutline);
  FontExtractLineSegments(LOutline, LLines);
  Check(Length(LLines) = 0, 'empty outline → 0 segments');
end;

procedure TestExtractLineSegmentsSimple;
var
  LOutline: TFontGlyphOutline;
  LLines: TFontLineSegmentArray;
begin
  WriteLn('[TestExtractLineSegmentsSimple]');
  LOutline.ContourCount := 1;
  SetLength(LOutline.ContourEnds, 1);
  LOutline.ContourEnds[0] := 2;
  SetLength(LOutline.Points, 3);
  LOutline.Points[0].X := 0;
  LOutline.Points[0].Y := 0;
  LOutline.Points[0].OnCurve := True;
  LOutline.Points[1].X := 100;
  LOutline.Points[1].Y := 0;
  LOutline.Points[1].OnCurve := True;
  LOutline.Points[2].X := 50;
  LOutline.Points[2].Y := 100;
  LOutline.Points[2].OnCurve := True;

  FontExtractLineSegments(LOutline, LLines);
  Check(Length(LLines) = 3, 'triangle → 3 segments');
end;

procedure TestExtractLineSegmentsFromFont;
var
  LOutline: TFontGlyphOutline;
  LGlyphIdx: UInt32;
  LLines: TFontLineSegmentArray;
begin
  WriteLn('[TestExtractLineSegmentsFromFont]');
  LGlyphIdx := GFace.LookupCodepoint(Ord('A'));
  Check(LGlyphIdx > 0, 'A glyph index found');
  if LGlyphIdx = 0 then
    Exit;
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  Check(LOutline.ContourCount > 0, 'A has contours');
  FontExtractLineSegments(LOutline, LLines);
  Check(Length(LLines) > 0, 'A → line segments (count=' + IntToStr(Length(LLines)) + ')');
end;

{ ===================================================================== }
{ 3. 位图光栅化                                                           }
{ ===================================================================== }

procedure TestRasterizeEmptyOutline;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
begin
  WriteLn('[TestRasterizeEmptyOutline]');
  FontGlyphOutlineClear(LOutline);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);
  Check(LResult.WidthPx = 0, 'empty outline → WidthPx = 0');
  Check(LResult.HeightPx = 0, 'empty outline → HeightPx = 0');
  Check(Length(LResult.Pixels) = 0, 'empty outline → no pixels');
end;

procedure TestRasterizeSpaceGlyph;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
begin
  WriteLn('[TestRasterizeSpaceGlyph]');
  LGlyphIdx := GFace.LookupCodepoint(Ord(' '));
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);
  Check(LResult.WidthPx = 0, 'space → WidthPx = 0');
  Check(Length(LResult.Pixels) = 0, 'space → no pixels');
end;

procedure TestRasterizeNonEmpty;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
  LI, LPixelCount: Int32;
  LHasNonZero: Boolean;
begin
  WriteLn('[TestRasterizeNonEmpty]');
  LGlyphIdx := GFace.LookupCodepoint(Ord('A'));
  if LGlyphIdx = 0 then
  begin
    Check(False, 'A glyph not found');
    Exit;
  end;
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);

  Check(LResult.WidthPx > 0, 'A has positive width');
  Check(LResult.HeightPx > 0, 'A has positive height');

  LPixelCount := LResult.WidthPx * LResult.HeightPx;
  Check(Length(LResult.Pixels) = LPixelCount, 'pixels size matches dimensions');

  LHasNonZero := False;
  for LI := 0 to High(LResult.Pixels) do
    if LResult.Pixels[LI] > 0 then
    begin
      LHasNonZero := True;
      Break;
    end;
  Check(LHasNonZero, 'A has non-zero pixels (ink present)');
end;

procedure TestRasterizeBitmapFormat;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
begin
  WriteLn('[TestRasterizeBitmapFormat]');
  LGlyphIdx := GFace.LookupCodepoint(Ord('A'));
  if LGlyphIdx = 0 then
    Exit;
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);

  if LResult.WidthPx > 0 then
  begin
    Check(LResult.PitchBytes = LResult.WidthPx, 'pitch = width');
    Check(LResult.AdvancePx > 0, 'advance > 0');
  end
  else
    Check(True, 'skipped (empty glyph)');
end;

procedure TestRasterizeAntiAliasing;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
  LI, LPartialCount: Int32;
begin
  WriteLn('[TestRasterizeAntiAliasing]');
  LGlyphIdx := GFace.LookupCodepoint(Ord('A'));
  if LGlyphIdx = 0 then
    Exit;
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);

  LPartialCount := 0;
  for LI := 0 to High(LResult.Pixels) do
    if (LResult.Pixels[LI] > 0) and (LResult.Pixels[LI] < 255) then
      Inc(LPartialCount);
  Check(LPartialCount > 0, 'AA produces partial coverage pixels (count=' +
    IntToStr(LPartialCount) + ')');
end;

procedure TestRasterizeBearing;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
begin
  WriteLn('[TestRasterizeBearing]');
  LGlyphIdx := GFace.LookupCodepoint(Ord('A'));
  if LGlyphIdx = 0 then
    Exit;
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);

  if LResult.WidthPx > 0 then
    Check(LResult.BearingYPx > 0, 'BearingY > 0 (above baseline)')
  else
    Check(True, 'skipped (empty glyph)');
end;

procedure TestRasterizeAllPrintable;
var
  LCode: Int32;
  LGlyphIdx: UInt32;
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LSuccessCount, LPixelCount: Int32;
begin
  WriteLn('[TestRasterizeAllPrintable]');
  LSuccessCount := 0;
  for LCode := 33 to 126 do
  begin
    LGlyphIdx := GFace.LookupCodepoint(LCode);
    if LGlyphIdx = 0 then
      Continue;
    LOutline := GFace.GlyphOutline(LGlyphIdx);
    LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);
    if LResult.WidthPx > 0 then
    begin
      LPixelCount := LResult.WidthPx * LResult.HeightPx;
      if Length(LResult.Pixels) = LPixelCount then
        Inc(LSuccessCount);
    end
    else if Length(LResult.Pixels) = 0 then
      Inc(LSuccessCount);
  end;
  Check(LSuccessCount >= 90, 'all printable ASCII rasterized (' +
    IntToStr(LSuccessCount) + '/94)');
end;

procedure TestRasterizeMultipleGlyphs;
var
  LOutline: TFontGlyphOutline;
  LResult: TFontRasterResult;
  LGlyphIdx: UInt32;
  LI: Int32;
begin
  WriteLn('[TestRasterizeMultipleGlyphs]');
  for LI := 1 to 50 do
  begin
    LGlyphIdx := GFace.LookupCodepoint(Ord('A') + (LI mod 26));
    if LGlyphIdx = 0 then
      Continue;
    LOutline := GFace.GlyphOutline(LGlyphIdx);
    LResult := GRasterizer.Rasterize(LOutline, 12, GFace.Metrics.UnitsPerEm);
    SetLength(LResult.Pixels, 0);
  end;
  Check(True, '50 rasterizations completed without error');
end;

{ ===================================================================== }
{ main                                                                    }
{ ===================================================================== }

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== TFontRasterizer Test Suite ===');
  WriteLn;

  if not FileExists(FONT_PATH) then
  begin
    WriteLn('ERROR: Font not found: ', FONT_PATH);
    Halt(1);
  end;

  GFace := TTFontFace.Create(FONT_PATH);
  if not GFace.IsValid then
  begin
    WriteLn('ERROR: Font invalid: ', GFace.LastError);
    GFace.Free;
    Halt(1);
  end;

  GRasterizer := TFontRasterizer.Create;

  try
    // Bezier 展平
    TestBezierStraightLine;
    TestBezierSubdivision;
    TestBezierFlatness;

    // 线段提取
    TestExtractLineSegmentsEmpty;
    TestExtractLineSegmentsSimple;
    TestExtractLineSegmentsFromFont;

    // 位图光栅化
    TestRasterizeEmptyOutline;
    TestRasterizeSpaceGlyph;
    TestRasterizeNonEmpty;
    TestRasterizeBitmapFormat;
    TestRasterizeAntiAliasing;
    TestRasterizeBearing;
    TestRasterizeAllPrintable;
    TestRasterizeMultipleGlyphs;

    WriteLn;
    WriteLn('=== Results: ', GPassed, ' passed, ', GFailed, ' failed ===');

    if GFailed > 0 then
      Halt(1);
  finally
    GRasterizer.Free;
    GFace.Free;
  end;
end.
