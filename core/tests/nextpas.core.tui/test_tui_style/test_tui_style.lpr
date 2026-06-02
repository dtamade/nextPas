program test_tui_style;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestDefault;
var
  LS: TStyle;
begin
  LS := TStyle.Default;
  Check(not ColorIsSet(LS.Fg), 'default fg unset');
  Check(not ColorIsSet(LS.Bg), 'default bg unset');
  Check(ModifierIsEmpty(LS.AddMod), 'default addmod empty');
  Check(ModifierIsEmpty(LS.SubMod), 'default submod empty');
  Check(StyleEquals(LS, StyleDefault), 'free fn matches class fn');
end;

procedure TestWithFgBg;
var
  LS: TStyle;
begin
  LS := TStyle.Default.WithFg(TUI_RED).WithBg(TUI_BLUE);
  Check(ColorEquals(LS.Fg, TUI_RED), 'fg red');
  Check(ColorEquals(LS.Bg, TUI_BLUE), 'bg blue');
end;

procedure TestWithModifier;
var
  LS: TStyle;
begin
  LS := TStyle.Default.WithModifier([mbBold, mbItalic]);
  Check(ModifierEquals(LS.AddMod, [mbBold, mbItalic]), 'addmod set');
  Check(ModifierIsEmpty(LS.SubMod), 'submod empty');

  { WithModifier 同时从 SubMod 清除 }
  LS := TStyle.Default.WithoutModifier([mbBold]).WithModifier([mbBold]);
  Check(mbBold in LS.AddMod, 'bold in addmod');
  Check(not (mbBold in LS.SubMod), 'bold removed from submod');
end;

procedure TestWithoutModifier;
var
  LS: TStyle;
begin
  LS := TStyle.Default.WithModifier([mbBold]).WithoutModifier([mbBold]);
  Check(mbBold in LS.SubMod, 'bold in submod');
  Check(not (mbBold in LS.AddMod), 'bold removed from addmod');
end;

procedure TestPatchColors;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default.WithFg(TUI_RED).WithBg(TUI_BLUE);
  LOther := TStyle.Default.WithFg(TUI_GREEN);  { only fg set }
  LResult := LBase.Patch(LOther);
  Check(ColorEquals(LResult.Fg, TUI_GREEN), 'other fg wins');
  Check(ColorEquals(LResult.Bg, TUI_BLUE), 'base bg kept (other unset)');
end;

procedure TestPatchModifiers;
var
  LBase, LOther, LResult: TStyle;
begin
  { base 加 Bold；other 减 Bold 加 Italic -> 结果应只有 Italic }
  LBase := TStyle.Default.WithModifier([mbBold]);
  LOther := TStyle.Default.WithModifier([mbItalic]).WithoutModifier([mbBold]);
  LResult := LBase.Patch(LOther);
  Check(mbItalic in LResult.AddMod, 'italic added');
  Check(not (mbBold in LResult.AddMod), 'bold removed by other submod');
  { 不变量：同一位不可能同时在 AddMod 和 SubMod }
  Check(ModifierIsEmpty(LResult.AddMod * LResult.SubMod), 'addmod/submod disjoint');
end;

procedure TestSize;
begin
  { 3*TColor(4) + 2*TModifier(2) = 12 + 4 = 16 }
  CheckEqual(Int64(16), Int64(SizeOf(TStyle)), 'TStyle 16 bytes');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.style');
  T.Run('default', @TestDefault);
  T.Run('with fg/bg', @TestWithFgBg);
  T.Run('with modifier', @TestWithModifier);
  T.Run('without modifier', @TestWithoutModifier);
  T.Run('patch colors', @TestPatchColors);
  T.Run('patch modifiers', @TestPatchModifiers);
  T.Run('size 16 bytes', @TestSize);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
