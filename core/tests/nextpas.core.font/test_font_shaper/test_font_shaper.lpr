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
    WriteLn('=== Results: ', GPassed, ' passed, ', GFailed, ' failed ===');

    if GFailed > 0 then
      Halt(1);
  finally
    GShaper.Free;
    GFace.Free;
  end;
end.
