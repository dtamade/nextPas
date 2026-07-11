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

begin
  T := TTestSuite.Create('tui_sixel');
  T.Test('EncodeSixelDCS small 2x2', @TestEncodeSixelDCSSmall);
  T.Test('EncodeSixelDCS 1x1 black', @TestEncodeSixelDCSBlack);
  T.Test('EncodeSixelDCS 1x1 transparent', @TestEncodeSixelDCSTransparent);
  T.Test('EncodeSixelDCS 5x2', @TestEncodeSixelDCSLarger);
  if not T.Run then Halt(1);
end.
