program test_tui_color_wine;
{ Wine runtime smoke for TColor — pure value ops, no TTY.
  truth=wine-runtime-smoke; not real Windows console evidence. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestRgbEquals;
var
  A, B: TColor;
begin
  A := RgbColor(10, 20, 30);
  B := RgbColor(10, 20, 30);
  Check(ColorEquals(A, B), 'rgb equal');
end;

procedure TestRgbDiffers;
begin
  Check(not ColorEquals(RgbColor(1, 2, 3), RgbColor(3, 2, 1)), 'rgb differ');
end;

procedure TestIndexed;
var
  C: TColor;
begin
  C := IndexedColor(42);
  Check(ColorEquals(C, IndexedColor(42)), 'indexed equal');
  Check(not ColorEquals(C, IndexedColor(7)), 'indexed differ');
end;

procedure TestResetNotRgb;
begin
  Check(not ColorEquals(ResetColor, RgbColor(0, 0, 0)), 'reset != black rgb');
end;

procedure TestNamedConstants;
begin
  Check(not ColorEquals(TUI_RED, TUI_BLUE), 'named red != blue');
end;

procedure TestRgbNotIndexed;
begin
  Check(not ColorEquals(RgbColor(255, 0, 0), IndexedColor(1)), 'rgb != indexed red');
end;

procedure TestUnsetNotReset;
begin
  Check(not ColorEquals(UnsetColor, ResetColor), 'unset != reset');
end;

procedure TestWhiteBlackNamed;
begin
  Check(not ColorEquals(TUI_WHITE, TUI_BLACK), 'white != black');
end;

procedure TestColorIsSetRgb;
begin
  Check(ColorIsSet(RgbColor(1, 2, 3)), 'rgb is set');
  Check(not ColorIsSet(UnsetColor), 'unset not set');
end;

procedure TestIndexedZero;
begin
  Check(ColorEquals(IndexedColor(0), IndexedColor(0)), 'index 0 equal');
end;

procedure TestRgbComponentsDistinct;
begin
  Check(not ColorEquals(RgbColor(1, 0, 0), RgbColor(0, 1, 0)), 'r != g');
  Check(not ColorEquals(RgbColor(0, 0, 1), RgbColor(0, 0, 2)), 'b1 != b2');
end;

procedure TestIndexedHigh;
begin
  Check(ColorEquals(IndexedColor(255), IndexedColor(255)), '255 equal');
  Check(not ColorEquals(IndexedColor(254), IndexedColor(255)), '254 != 255');
end;

begin
  T := TTestSuite.Create('tui_color_wine');
  T.Test('rgb equals', @TestRgbEquals);
  T.Test('rgb differs', @TestRgbDiffers);
  T.Test('indexed', @TestIndexed);
  T.Test('reset not rgb', @TestResetNotRgb);
  T.Test('named constants', @TestNamedConstants);
  T.Test('rgb not indexed', @TestRgbNotIndexed);
  T.Test('unset not reset', @TestUnsetNotReset);
  T.Test('white black named', @TestWhiteBlackNamed);
  T.Test('color is set rgb', @TestColorIsSetRgb);
  T.Test('indexed zero', @TestIndexedZero);
  T.Test('rgb components distinct', @TestRgbComponentsDistinct);
  T.Test('indexed high', @TestIndexedHigh);
  if not T.Run then Halt(1);
end.
