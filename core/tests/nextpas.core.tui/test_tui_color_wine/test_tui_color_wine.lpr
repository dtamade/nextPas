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

begin
  T := TTestSuite.Create('tui_color_wine');
  T.Test('rgb equals', @TestRgbEquals);
  T.Test('rgb differs', @TestRgbDiffers);
  T.Test('indexed', @TestIndexed);
  T.Test('reset not rgb', @TestResetNotRgb);
  T.Test('named constants', @TestNamedConstants);
  if not T.Run then Halt(1);
end.
