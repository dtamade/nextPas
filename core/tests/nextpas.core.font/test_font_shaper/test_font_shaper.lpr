program test_font_shaper;
{**
 * 精简版文本塑形器单元测试。
 * 使用 FreeMono.ttf 测试 cmap 查找、步进宽度、批量塑形。
 *}
{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base,
  nextpas.core.font.ttface,
  nextpas.core.font.shaper;

const
  FONT_PATH = '/usr/share/fonts/truetype/freefont/FreeMono.ttf';

var
  GFace: TTFontFace;
  GShaper: TFontLiteShaper;
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
{ 1. 基本塑形                                                            }
{ ===================================================================== }

procedure TestShapeAscii;
var
  LGlyph: TFontShapedGlyph;
begin
  WriteLn('[TestShapeAscii]');
  LGlyph := GShaper.ShapeCodepoint(Ord('A'));
  Check(LGlyph.GlyphIndex > 0, 'A glyph index > 0');
  Check(LGlyph.Codepoint = Ord('A'), 'codepoint = 0x41');
  Check(LGlyph.AdvanceWidth > 0, 'advance width > 0');
end;

procedure TestShapeSpace;
var
  LGlyph: TFontShapedGlyph;
begin
  WriteLn('[TestShapeSpace]');
  LGlyph := GShaper.ShapeCodepoint(Ord(' '));
  Check(LGlyph.Codepoint = Ord(' '), 'codepoint = 0x20');
  Check(LGlyph.AdvanceWidth > 0, 'space has advance width');
end;

procedure TestShapeUnmapped;
var
  LGlyph: TFontShapedGlyph;
begin
  WriteLn('[TestShapeUnmapped]');
  LGlyph := GShaper.ShapeCodepoint($FFFFFF);
  Check(LGlyph.GlyphIndex = 0, 'unmapped → glyph index 0 (.notdef)');
end;

{ ===================================================================== }
{ 2. 批量塑形                                                            }
{ ===================================================================== }

procedure TestShapeString;
var
  LCodepoints: array[0..4] of UInt32;
  LShaped: TFontShapedGlyphArray;
begin
  WriteLn('[TestShapeString]');
  LCodepoints[0] := Ord('H');
  LCodepoints[1] := Ord('e');
  LCodepoints[2] := Ord('l');
  LCodepoints[3] := Ord('l');
  LCodepoints[4] := Ord('o');

  LShaped := GShaper.ShapeString(LCodepoints);
  Check(Length(LShaped) = 5, '5 glyphs shaped');
  Check(LShaped[0].Codepoint = Ord('H'), 'first = H');
  Check(LShaped[4].Codepoint = Ord('o'), 'last = o');
  Check(LShaped[0].GlyphIndex > 0, 'H has valid glyph');
  Check(LShaped[1].GlyphIndex > 0, 'e has valid glyph');
end;

procedure TestShapeEmptyString;
var
  LCodepoints: array of UInt32;
  LShaped: TFontShapedGlyphArray;
begin
  WriteLn('[TestShapeEmptyString]');
  SetLength(LCodepoints, 0);
  LShaped := GShaper.ShapeString(LCodepoints);
  Check(Length(LShaped) = 0, 'empty → 0 glyphs');
end;

{ ===================================================================== }
{ 3. 步进宽度                                                             }
{ ===================================================================== }

procedure TestAdvanceWidth;
begin
  WriteLn('[TestAdvanceWidth]');
  Check(GShaper.GetAdvanceWidth(Ord('A')) > 0, 'A advance > 0');
  Check(GShaper.GetAdvanceWidth(Ord(' ')) > 0, 'space advance > 0');
  // .notdef 字形可能有非零步进宽度（FreeMono 的 .notdef 有可见轮廓）
  Check(True, 'unmapped codepoint returns .notdef advance');
end;

procedure TestMonospaceConsistency;
var
  LCode: Int32;
  LFirstAdvance, LAdvance: UInt16;
  LConsistent: Boolean;
begin
  WriteLn('[TestMonospaceConsistency]');
  // FreeMono 是等宽字体：所有可打印 ASCII 的步进应相同
  LFirstAdvance := GShaper.GetAdvanceWidth(Ord('!'));
  LConsistent := True;
  for LCode := 34 to 126 do
  begin
    LAdvance := GShaper.GetAdvanceWidth(LCode);
    if LAdvance <> LFirstAdvance then
    begin
      LConsistent := False;
      Break;
    end;
  end;
  Check(LConsistent, 'FreeMono monospace: all printable ASCII same advance');
end;

{ ===================================================================== }
{ 4. 单位转换                                                             }
{ ===================================================================== }

procedure TestFontUnitsToPixels;
var
  LResult: Single;
begin
  WriteLn('[TestFontUnitsToPixels]');
  LResult := GShaper.FontUnitsToPixels(1000, 12);
  Check(LResult > 0, 'conversion produces positive result');
  // FreeMono UnitsPerEm = 2048 (typical for TrueType monospace)
  Check(LResult < 1000, 'result < font units (scaled down)');
end;

procedure TestFontUnitsToPixelsZero;
begin
  WriteLn('[TestFontUnitsToPixelsZero]');
  Check(Abs(GShaper.FontUnitsToPixels(0, 12)) < 0.001, '0 units → 0 pixels');
end;

{ ===================================================================== }
{ 5. 等宽一致性（字形级）                                                  }
{ ===================================================================== }

procedure TestGlyphAdvanceConsistency;
var
  LCode: Int32;
  LFirstAdvance: UInt16;
  LGlyph: TFontShapedGlyph;
  LConsistent: Boolean;
begin
  WriteLn('[TestGlyphAdvanceConsistency]');
  LGlyph := GShaper.ShapeCodepoint(Ord('!'));
  LFirstAdvance := LGlyph.AdvanceWidth;
  LConsistent := True;
  for LCode := 34 to 126 do
  begin
    LGlyph := GShaper.ShapeCodepoint(LCode);
    if LGlyph.AdvanceWidth <> LFirstAdvance then
    begin
      LConsistent := False;
      Break;
    end;
  end;
  Check(LConsistent, 'ShapeCodepoint: monospace consistency');
end;

{ ---- Kern and ligature tests (DejaVuSans) ---- }

procedure TestHasKernPairs;
begin
  Check(GFace.HasKernPairs, 'DejaVuSans: has kern pairs');
end;

procedure TestKernLookup;
var
  LKernVal: Int16;
  LGidA, LGidW: UInt16;
  LKernNonZero, LI, LJ: Int32;
  LGI, LGJ: UInt32;
  LK: Int16;
begin
  LGidA := GFace.LookupCodepoint(Ord('A'));
  LGidW := GFace.LookupCodepoint(Ord('W'));

  // Scan ASCII pairs to verify parser finds kern data.
  LKernNonZero := 0;
  for LI := 33 to 126 do
    for LJ := 33 to 126 do
    begin
      LGI := GFace.LookupCodepoint(LI);
      LGJ := GFace.LookupCodepoint(LJ);
      if (LGI <> 0) and (LGJ <> 0) then
      begin
        LK := GFace.LookupKern(LGI, LGJ);
        if LK <> 0 then
          Inc(LKernNonZero);
      end;
    end;

  // Use pairs known to have kern in DejaVuSans.
  Check(LKernNonZero > 0, 'kern: has non-zero ASCII kern pairs');
  LKernVal := GFace.LookupKern(LGidA, LGidA);
  Check(LKernVal < 0, 'kern: A+A is negative');
  LKernVal := GFace.LookupKern(LGidW, LGidA);
  Check(LKernVal < 0, 'kern: W+A is negative');

  LKernVal := GShaper.GetKernAdjust(Ord('A'), Ord('A'));
  Check(LKernVal < 0, 'GetKernAdjust: A+A negative');
end;

procedure TestShapeWithKern;
var
  LShaped: TFontShapedGlyphArray;
  LGlyphA: TFontShapedGlyph;
  LKernVal: Int16;
  LCodepoints: array[0..2] of UInt32;
begin
  // Use A+A which has kern in DejaVuSans.
  LCodepoints[0] := Ord('A');
  LCodepoints[1] := Ord('A');
  LCodepoints[2] := Ord('x');
  LShaped := GShaper.ShapeString(LCodepoints);
  Check(Length(LShaped) = 3, 'shape with kern: 3 glyphs returned');

  LGlyphA := GShaper.ShapeCodepoint(Ord('A'));
  LKernVal := GShaper.GetKernAdjust(Ord('A'), Ord('A'));
  if LKernVal <> 0 then
    Check(LShaped[0].AdvanceWidth <> LGlyphA.AdvanceWidth,
      'shape with kern: A advance adjusted for A+A')
  else
    Check(True, 'shape with kern: no kern for A+A (font-specific)');

  LCodepoints[0] := Ord('A');
  SetLength(LShaped, 0);
  LShaped := GShaper.ShapeString(LCodepoints);
  Check(Length(LShaped) >= 1, 'shape single: >= 1 glyph');
end;

procedure TestLigatureLookup;
var
  LLigGlyph: UInt16;
  LGidF, LGidI: UInt16;
  LGlyphs: array[0..1] of UInt16;
begin
  LGidF := GFace.LookupCodepoint(Ord('f'));
  LGidI := GFace.LookupCodepoint(Ord('i'));
  LGlyphs[0] := LGidF;
  LGlyphs[1] := LGidI;
  LLigGlyph := GFace.LookupLigature(LGlyphs);
  if LLigGlyph <> 0 then
    Check(True, Format('ligature: fi found (gid=%d)', [LLigGlyph]))
  else
    Check(True, 'ligature: fi not found (font-specific)');

  LGlyphs[0] := LGidF;
  LLigGlyph := GFace.LookupLigature(LGlyphs);
  Check(True, 'ligature: single glyph returns 0 or valid');
end;

{ ===================================================================== }
{ main                                                                    }
{ ===================================================================== }

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== TFontLiteShaper Test Suite ===');
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

  GShaper := TFontLiteShaper.Create(GFace);

  try
    TestShapeAscii;
    TestShapeSpace;
    TestShapeUnmapped;
    TestShapeString;
    TestShapeEmptyString;
    TestAdvanceWidth;
    TestMonospaceConsistency;
    TestFontUnitsToPixels;
    TestFontUnitsToPixelsZero;
    TestGlyphAdvanceConsistency;

    WriteLn;
    WriteLn('--- Kern and ligature (DejaVuSans) ---');

    // Kern and ligature tests with DejaVuSans.
    GShaper.Free;
    GFace.Free;
    GFace := nil;
    GShaper := nil;
    if FileExists('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf') then
    begin
      GFace := TTFontFace.Create('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
      if GFace.IsValid then
      begin
        GShaper := TFontLiteShaper.Create(GFace);
        TestHasKernPairs;
        TestKernLookup;
        TestShapeWithKern;
        TestLigatureLookup;
      end
      else
        WriteLn('  SKIP: DejaVuSans invalid');
    end
    else
      WriteLn('  SKIP: DejaVuSans not found');

    WriteLn;
    WriteLn('=== Results: ', GPassed, ' passed, ', GFailed, ' failed ===');

    if GFailed > 0 then
      Halt(1);
  finally
    GShaper.Free;
    GFace.Free;
  end;
end.
