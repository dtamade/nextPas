program test_tui_color;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestConstructors;
var
  LC: TColor;
begin
  LC := UnsetColor;
  Check(LC.Kind = ckUnset, 'unset kind');
  LC := ResetColor;
  Check(LC.Kind = ckReset, 'reset kind');
  LC := IndexedColor(42);
  Check(LC.Kind = ckIndexed, 'indexed kind');
  CheckEqual(Int64(42), Int64(LC.Index), 'indexed value');
  LC := RgbColor(10, 20, 30);
  Check(LC.Kind = ckRgb, 'rgb kind');
  CheckEqual(Int64(10), Int64(LC.R), 'rgb R');
  CheckEqual(Int64(20), Int64(LC.G), 'rgb G');
  CheckEqual(Int64(30), Int64(LC.B), 'rgb B');
end;

procedure TestEquality;
begin
  Check(ColorEquals(IndexedColor(5), IndexedColor(5)), 'equal indexed');
  Check(not ColorEquals(IndexedColor(5), IndexedColor(6)), 'unequal indexed');
  Check(ColorEquals(RgbColor(1, 2, 3), RgbColor(1, 2, 3)), 'equal rgb');
  Check(not ColorEquals(RgbColor(1, 2, 3), RgbColor(1, 2, 4)), 'unequal rgb');
  Check(not ColorEquals(UnsetColor, ResetColor), 'unset != reset');
end;

procedure TestIsSet;
begin
  Check(not ColorIsSet(UnsetColor), 'unset not set');
  Check(ColorIsSet(ResetColor), 'reset is set');
  Check(ColorIsSet(IndexedColor(0)), 'indexed is set');
  Check(ColorIsSet(RgbColor(0, 0, 0)), 'rgb is set');
end;

procedure TestNamedColors;
begin
  Check((TUI_BLACK.Kind = ckIndexed) and (TUI_BLACK.Index = 0), 'black=0');
  Check((TUI_RED.Kind = ckIndexed) and (TUI_RED.Index = 1), 'red=1');
  Check((TUI_CYAN.Kind = ckIndexed) and (TUI_CYAN.Index = 6), 'cyan=6');
  Check((TUI_WHITE.Kind = ckIndexed) and (TUI_WHITE.Index = 15), 'white=15');
  Check((TUI_LIGHT_MAGENTA.Kind = ckIndexed) and (TUI_LIGHT_MAGENTA.Index = 13), 'light magenta=13');
end;

procedure TestSize;
begin
  CheckEqual(Int64(4), Int64(SizeOf(TColor)), 'TColor 4 bytes');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.color');
  T.Run('constructors', @TestConstructors);
  T.Run('equality', @TestEquality);
  T.Run('is set', @TestIsSet);
  T.Run('named colors', @TestNamedColors);
  T.Run('size 4 bytes', @TestSize);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
