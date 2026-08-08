program test_tui_color;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestRgbShortcut;
var
  LC: TColor;
begin
  LC := Rgb(100, 200, 50);
  Check(LC.Kind = ckRgb, 'rgb kind');
  CheckEqual(Int64(100), Int64(LC.R), 'R');
  CheckEqual(Int64(200), Int64(LC.G), 'G');
  CheckEqual(Int64(50), Int64(LC.B), 'B');
end;

procedure TestIdxShortcut;
var
  LC: TColor;
begin
  LC := Idx(42);
  Check(LC.Kind = ckIndexed, 'indexed kind');
  CheckEqual(Int64(42), Int64(LC.Index), 'index 42');
end;

procedure TestHexColor;
var
  LC: TColor;
begin
  LC := HexColor('#FF8000');
  Check(LC.Kind = ckRgb, 'hex kind rgb');
  CheckEqual(Int64(255), Int64(LC.R), 'hex R');
  CheckEqual(Int64(128), Int64(LC.G), 'hex G');
  CheckEqual(Int64(0), Int64(LC.B), 'hex B');
end;

procedure TestHexColorWithoutHash;
var
  LC: TColor;
begin
  LC := HexColor('00FF00');
  Check(LC.Kind = ckRgb, 'hex without hash');
  CheckEqual(Int64(0), Int64(LC.R), 'R=0');
  CheckEqual(Int64(255), Int64(LC.G), 'G=255');
  CheckEqual(Int64(0), Int64(LC.B), 'B=0');
end;

procedure TestHexColorEmpty;
var
  LC: TColor;
begin
  LC := HexColor('');
  Check(LC.Kind = ckReset, 'empty hex returns reset');
end;

procedure TestHexColorShort;
var
  LC: TColor;
begin
  LC := HexColor('#FFF');
  Check(LC.Kind = ckReset, 'short hex returns reset');
end;

procedure TestAllNamedColors;
begin
  Check(TUI_BLACK.Index = 0, 'black=0');
  Check(TUI_RED.Index = 1, 'red=1');
  Check(TUI_GREEN.Index = 2, 'green=2');
  Check(TUI_YELLOW.Index = 3, 'yellow=3');
  Check(TUI_BLUE.Index = 4, 'blue=4');
  Check(TUI_MAGENTA.Index = 5, 'magenta=5');
  Check(TUI_CYAN.Index = 6, 'cyan=6');
  Check(TUI_GRAY.Index = 7, 'gray=7');
  Check(TUI_DARK_GRAY.Index = 8, 'dark gray=8');
  Check(TUI_LIGHT_RED.Index = 9, 'light red=9');
  Check(TUI_LIGHT_GREEN.Index = 10, 'light green=10');
  Check(TUI_LIGHT_YELLOW.Index = 11, 'light yellow=11');
  Check(TUI_LIGHT_BLUE.Index = 12, 'light blue=12');
  Check(TUI_LIGHT_MAGENTA.Index = 13, 'light magenta=13');
  Check(TUI_LIGHT_CYAN.Index = 14, 'light cyan=14');
  Check(TUI_WHITE.Index = 15, 'white=15');
end;

procedure TestColorEqualsCrossKind;
begin
  Check(not ColorEquals(UnsetColor, ResetColor), 'unset != reset');
  Check(not ColorEquals(IndexedColor(0), RgbColor(0, 0, 0)), 'indexed != rgb');
  Check(not ColorEquals(ResetColor, IndexedColor(0)), 'reset != indexed');
end;

procedure TestColorInterp;
var
  LC: TColor;
begin
  LC := ColorInterp(Rgb(0, 0, 0), Rgb(10, 20, 30), 0.5);
  Check(LC.Kind = ckRgb, 'interp kind rgb');
  CheckEqual(Int64(5), Int64(LC.R), 'interp R mid');
  CheckEqual(Int64(10), Int64(LC.G), 'interp G mid');
  CheckEqual(Int64(15), Int64(LC.B), 'interp B mid');

  LC := ColorInterp(Rgb(0, 0, 0), Rgb(100, 100, 100), 0);
  Check(ColorEquals(LC, Rgb(0, 0, 0)), 'interp t=0');

  LC := ColorInterp(Rgb(0, 0, 0), Rgb(100, 100, 100), 1);
  Check(ColorEquals(LC, Rgb(100, 100, 100)), 'interp t=1');

  { 非 RGB 输入退化为 BColor }
  LC := ColorInterp(IndexedColor(3), Rgb(10, 20, 30), 0.5);
  Check(LC.Kind = ckRgb, 'non-rgb A falls back to B');
  CheckEqual(Int64(10), Int64(LC.R), 'fallback R');
  LC := ColorInterp(Rgb(10, 20, 30), ResetColor, 0.5);
  CheckEqual(Int64(0), Int64(LC.Index), 'non-rgb B falls back to B');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.color');
  T.Test('constructors', @TestConstructors);
  T.Test('equality', @TestEquality);
  T.Test('is set', @TestIsSet);
  T.Test('named colors', @TestNamedColors);
  T.Test('size 4 bytes', @TestSize);
  T.Test('Rgb shortcut', @TestRgbShortcut);
  T.Test('Idx shortcut', @TestIdxShortcut);
  T.Test('HexColor', @TestHexColor);
  T.Test('HexColor without hash', @TestHexColorWithoutHash);
  T.Test('HexColor empty', @TestHexColorEmpty);
  T.Test('HexColor short', @TestHexColorShort);
  T.Test('all named colors', @TestAllNamedColors);
  T.Test('color equals cross kind', @TestColorEqualsCrossKind);
  T.Test('ColorInterp', @TestColorInterp);
  if not T.Run then Halt(1);
end.
