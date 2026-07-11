program test_tui_sixel;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.tui.sixel,
  nextpas.core.test;

var
  T: TTestSuite;

function BuilderToStr(const ABuilder: TStringBuilder): AnsiString;
var
  LView: TStringView;
begin
  LView := ABuilder.AsView;
  SetString(Result, LView.Data, LView.Len);
end;

procedure TestEncodeSixelDCSSmall;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..15] of Byte; // 2x2 RGBA
  LData: AnsiString;
begin
  // 2x2 red pixels (R=255, G=0, B=0, A=255)
  LPixels[0] := 255; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 255;
  LPixels[4] := 255; LPixels[5] := 0; LPixels[6] := 0; LPixels[7] := 255;
  LPixels[8] := 255; LPixels[9] := 0; LPixels[10] := 0; LPixels[11] := 255;
  LPixels[12] := 255; LPixels[13] := 0; LPixels[14] := 0; LPixels[15] := 255;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 2, 2);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'Output should not be empty');
  // Should start with ESC P (DCS)
  Check(LData[1] = #27, 'Should start with ESC');
  Check(LData[2] = 'P', 'Should have DCS P');
  // Should end with ESC \
  Check(LData[Length(LData)] = '\', 'Should end with backslash');
  Check(LData[Length(LData)-1] = #27, 'Should have ESC before backslash');
end;

procedure TestEncodeSixelDCSBlack;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte; // 1x1 black pixel
  LData: AnsiString;
begin
  LPixels[0] := 0; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 255;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'Output should not be empty');
  Check(LData[1] = #27, 'Should start with ESC');
end;

procedure TestEncodeSixelDCSTransparent;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte; // 1x1 transparent pixel
  LData: AnsiString;
begin
  LPixels[0] := 255; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 0; // A=0

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'Output should not be empty');
end;

procedure TestEncodeSixelDCSLarger;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..39] of Byte; // 5x2 RGBA
  LData: AnsiString;
  I: Integer;
begin
  // 5x2 blue pixels
  for I := 0 to 9 do
  begin
    LPixels[I*4] := 0;     // R
    LPixels[I*4+1] := 0;   // G
    LPixels[I*4+2] := 255; // B
    LPixels[I*4+3] := 255; // A
  end;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 5, 2);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'Output should not be empty');
  // Should contain palette definition
  Check(Pos('#0', LData) > 0, 'Should contain palette entry');
end;

procedure TestEncodeSixelDCSUniform;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..31] of Byte; // 4x2 all green
  LData: AnsiString;
  I: Integer;
begin
  for I := 0 to 7 do
  begin
    LPixels[I*4] := 0;     // R
    LPixels[I*4+1] := 255; // G
    LPixels[I*4+2] := 0;   // B
    LPixels[I*4+3] := 255; // A
  end;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 4, 2);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  // Should use run-length encoding for uniform color
  Check(Length(LData) > 0, 'Uniform: output not empty');
  // Should start with DCS header
  Check(LData[1] = #27, 'Uniform: starts with ESC');
  Check(LData[2] = 'P', 'Uniform: DCS P');
end;

procedure TestEncodeSixelDCSAllTransparent;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte; // 1x1 transparent
  LData: AnsiString;
begin
  LPixels[0] := 0; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 0;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  // All-transparent → PalCount=1, still produces valid DCS
  Check(Length(LData) > 0, 'AllTransparent: output not empty');
  Check(LData[1] = #27, 'AllTransparent: starts with ESC');
  // Should end with ESC \
  Check(LData[Length(LData)] = '\', 'AllTransparent: ends ST');
end;

procedure TestEncodeSixelDCSSingleRow;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..11] of Byte; // 3x1
  LData: AnsiString;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    LPixels[I*4] := 255; LPixels[I*4+1] := 255;
    LPixels[I*4+2] := 255; LPixels[I*4+3] := 255;
  end;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 3, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  // Single row → 1 band, no '-' separators
  Check(Length(LData) > 0, 'SingleRow: output not empty');
  Check(Pos('-', LData) = 0, 'SingleRow: no band separator');
end;

procedure TestEncodeSixelDCSPaletteLimit;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..255] of Byte; // 8x8, each pixel different color
  LData: AnsiString;
  I: Integer;
begin
  for I := 0 to 63 do
  begin
    LPixels[I*4] := Byte(I * 4);     // R varies
    LPixels[I*4+1] := Byte(255 - I * 4); // G varies
    LPixels[I*4+2] := 128;           // B constant
    LPixels[I*4+3] := 255;           // A opaque
  end;

  LBuilder.Init(2048);
  EncodeSixelDCS(LBuilder, @LPixels[0], 8, 8, 4); // limit to 4 colors
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'PaletteLimit: output not empty');
  // Should contain palette entries up to #3 (0..3)
  Check(Pos('#3', LData) > 0, 'PaletteLimit: has palette #3');
end;

procedure TestEncodeSixelDCSMixedColors;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..15] of Byte; // 2x2 checkerboard red/blue
  LData: AnsiString;
begin
  // Pixel (0,0) = red
  LPixels[0] := 255; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 255;
  // Pixel (1,0) = blue
  LPixels[4] := 0; LPixels[5] := 0; LPixels[6] := 255; LPixels[7] := 255;
  // Pixel (0,1) = blue
  LPixels[8] := 0; LPixels[9] := 0; LPixels[10] := 255; LPixels[11] := 255;
  // Pixel (1,1) = red
  LPixels[12] := 255; LPixels[13] := 0; LPixels[14] := 0; LPixels[15] := 255;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 2, 2);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  // Two distinct colors → palette should have 2 entries
  Check(Length(LData) > 0, 'Mixed: output not empty');
  Check(Pos('#0', LData) > 0, 'Mixed: palette #0');
  Check(Pos('#1', LData) > 0, 'Mixed: palette #1');
end;

procedure TestEncodeSixelDCSWhite;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte; // 1x1 white
  LData: AnsiString;
begin
  LPixels[0] := 255; LPixels[1] := 255; LPixels[2] := 255; LPixels[3] := 255;

  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;

  Check(Length(LData) > 0, 'White: output not empty');
  // White = 100% R,G,B in sixel percent encoding
  Check(Pos('100', LData) > 0, 'White: contains 100% component');
end;

procedure TestEncodeSixelDCSSixRows;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..23] of Byte; // 1x6 RGBA = 1 band exactly
  LData: AnsiString;
  I: Integer;
begin
  for I := 0 to 5 do
  begin
    LPixels[I*4] := 128; LPixels[I*4+1] := 128;
    LPixels[I*4+2] := 128; LPixels[I*4+3] := 255;
  end;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 6);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  // 6 rows = exactly 1 band, no '-' band separator
  Check(Pos('-', LData) = 0, 'SixRows: no band separator');
  Check(Length(LData) > 0, 'SixRows: output not empty');
end;

procedure TestEncodeSixelDCSSevenRows;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..27] of Byte; // 1x7 RGBA = 2 bands
  LData: AnsiString;
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    LPixels[I*4] := 200; LPixels[I*4+1] := 100;
    LPixels[I*4+2] := 50; LPixels[I*4+3] := 255;
  end;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 7);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  // 7 rows = 2 bands, should have '-'
  Check(Pos('-', LData) > 0, 'SevenRows: has band separator');
  Check(Length(LData) > 0, 'SevenRows: output not empty');
end;

procedure TestEncodeSixelDCSDimensions;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..15] of Byte; // 2x2
  LData: AnsiString;
begin
  FillChar(LPixels[0], 16, 0);
  LPixels[3] := 255; LPixels[7] := 255; // A=255 for first 2 pixels
  LPixels[11] := 255; LPixels[15] := 255; // A=255 for last 2 pixels
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 2, 2);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  // Header should contain dimensions "1;1;2;2"
  Check(Pos('2;2', LData) > 0, 'Dimensions: contains 2;2');
end;

procedure TestEncodeSixelDCSSmallPalette;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..15] of Byte; // 2x2, 2 distinct colors
  LData: AnsiString;
begin
  // Red pixel
  LPixels[0] := 255; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 255;
  LPixels[4] := 255; LPixels[5] := 0; LPixels[6] := 0; LPixels[7] := 255;
  // Blue pixel
  LPixels[8] := 0; LPixels[9] := 0; LPixels[10] := 255; LPixels[11] := 255;
  LPixels[12] := 0; LPixels[13] := 0; LPixels[14] := 255; LPixels[15] := 255;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 2, 2, 2); // MaxColors=2
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  Check(Length(LData) > 0, 'SmallPalette: output not empty');
  Check(Pos('#0', LData) > 0, 'SmallPalette: has palette #0');
  Check(Pos('#1', LData) > 0, 'SmallPalette: has palette #1');
  // Should NOT have #2 since MaxColors=2
  Check(Pos('#2', LData) = 0, 'SmallPalette: no palette #2');
end;

procedure TestEncodeSixelDCSMaxColorsOne;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..15] of Byte; // 2x2
  LData: AnsiString;
begin
  LPixels[0] := 255; LPixels[1] := 0; LPixels[2] := 0; LPixels[3] := 255;
  LPixels[4] := 0; LPixels[5] := 255; LPixels[6] := 0; LPixels[7] := 255;
  LPixels[8] := 0; LPixels[9] := 0; LPixels[10] := 255; LPixels[11] := 255;
  LPixels[12] := 255; LPixels[13] := 255; LPixels[14] := 0; LPixels[15] := 255;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 2, 2, 1); // Only 1 color
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  Check(Length(LData) > 0, 'MaxColors1: output not empty');
end;

procedure TestEncodeSixelDCSHasSTTerminator;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte;
  LData: AnsiString;
begin
  LPixels[0] := 100; LPixels[1] := 100; LPixels[2] := 100; LPixels[3] := 255;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  // Must end with ESC \ (ST = String Terminator)
  Check(Length(LData) >= 2, 'ST: sufficient length');
  Check(LData[Length(LData)] = '\', 'ST: ends with backslash');
  Check(LData[Length(LData)-1] = #27, 'ST: ESC before backslash');
end;

procedure TestEncodeSixelDCSHasDCSHeader;
var
  LBuilder: TStringBuilder;
  LPixels: array[0..3] of Byte;
  LData: AnsiString;
begin
  LPixels[0] := 50; LPixels[1] := 50; LPixels[2] := 50; LPixels[3] := 255;
  LBuilder.Init(1024);
  EncodeSixelDCS(LBuilder, @LPixels[0], 1, 1);
  LData := BuilderToStr(LBuilder);
  LBuilder.Done;
  // Must start with ESC P (DCS)
  Check(LData[1] = #27, 'DCS: starts with ESC');
  Check(LData[2] = 'P', 'DCS: P after ESC');
  // Then "0;0;0q"
  Check(Pos('0;0;0q', LData) > 0, 'DCS: has 0;0;0q');
end;

begin
  T := TTestSuite.Create('tui_sixel');
  T.Test('EncodeSixelDCS small 2x2', @TestEncodeSixelDCSSmall);
  T.Test('EncodeSixelDCS 1x1 black', @TestEncodeSixelDCSBlack);
  T.Test('EncodeSixelDCS 1x1 transparent', @TestEncodeSixelDCSTransparent);
  T.Test('EncodeSixelDCS 5x2', @TestEncodeSixelDCSLarger);
  T.Test('EncodeSixelDCS uniform color (RLE)', @TestEncodeSixelDCSUniform);
  T.Test('EncodeSixelDCS all transparent', @TestEncodeSixelDCSAllTransparent);
  T.Test('EncodeSixelDCS single row', @TestEncodeSixelDCSSingleRow);
  T.Test('EncodeSixelDCS palette limit', @TestEncodeSixelDCSPaletteLimit);
  T.Test('EncodeSixelDCS mixed colors', @TestEncodeSixelDCSMixedColors);
  T.Test('EncodeSixelDCS 1x1 white', @TestEncodeSixelDCSWhite);
  T.Test('EncodeSixelDCS 6 rows (1 band)', @TestEncodeSixelDCSSixRows);
  T.Test('EncodeSixelDCS 7 rows (2 bands)', @TestEncodeSixelDCSSevenRows);
  T.Test('EncodeSixelDCS dimensions in header', @TestEncodeSixelDCSDimensions);
  T.Test('EncodeSixelDCS small palette limit', @TestEncodeSixelDCSSmallPalette);
  T.Test('EncodeSixelDCS MaxColors=1', @TestEncodeSixelDCSMaxColorsOne);
  T.Test('EncodeSixelDCS has ST terminator', @TestEncodeSixelDCSHasSTTerminator);
  T.Test('EncodeSixelDCS has DCS header', @TestEncodeSixelDCSHasDCSHeader);
  if not T.Run then Halt(1);
end.
