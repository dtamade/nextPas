program test_tui_style;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestStyleEquals;
var
  LA, LB: TStyle;
begin
  LA := TStyle.Default.WithFg(TUI_RED);
  LB := TStyle.Default.WithFg(TUI_RED);
  Check(StyleEquals(LA, LB), 'same styles equal');
  LB := TStyle.Default.WithFg(TUI_BLUE);
  Check(not StyleEquals(LA, LB), 'different fg not equal');
end;

procedure TestPatchBothUnset;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default;
  LOther := TStyle.Default;
  LResult := LBase.Patch(LOther);
  Check(not ColorIsSet(LResult.Fg), 'both unset fg stays unset');
  Check(not ColorIsSet(LResult.Bg), 'both unset bg stays unset');
end;

procedure TestPatchSelfOnly;
var
  LBase, LResult: TStyle;
begin
  LBase := TStyle.Default.WithFg(TUI_RED);
  LResult := LBase.Patch(TStyle.Default);
  Check(ColorEquals(LResult.Fg, TUI_RED), 'self fg preserved when other unset');
end;

procedure TestPatchOtherOnly;
var
  LOther, LResult: TStyle;
begin
  LOther := TStyle.Default.WithBg(TUI_BLUE);
  LResult := TStyle.Default.Patch(LOther);
  Check(ColorEquals(LResult.Bg, TUI_BLUE), 'other bg applied when self unset');
end;

procedure TestWithFgBgChain;
var
  LS: TStyle;
begin
  LS := TStyle.Default.WithFg(TUI_RED).WithBg(TUI_BLUE).WithModifier([mbBold]);
  Check(ColorEquals(LS.Fg, TUI_RED), 'fg');
  Check(ColorEquals(LS.Bg, TUI_BLUE), 'bg');
  Check(mbBold in LS.AddMod, 'bold');
end;

procedure TestStyleInterp;
var
  A, B, R: TStyle;
begin
  A := TStyle.Default.WithFg(RgbColor(0, 0, 0)).WithModifier([mbBold]);
  B := TStyle.Default.WithFg(RgbColor(100, 100, 100));
  { T=0 端点取 A；修饰位取 A 侧 }
  R := StyleInterp(A, B, 0);
  Check(ColorEquals(R.Fg, A.Fg), 'T=0 takes A fg');
  Check(mbBold in R.AddMod, 'modifier kept from A');
  { T=1 端点取 B }
  R := StyleInterp(A, B, 1);
  Check(ColorEquals(R.Fg, B.Fg), 'T=1 takes B fg');
  { T=0.5 中点：RGB 线性插值 }
  R := StyleInterp(A, B, 0.5);
  Check(R.Fg.Kind = ckRgb, 'midpoint fg is rgb');
  CheckEqual(Int64(50), Int64(R.Fg.R), 'midpoint R');
  CheckEqual(Int64(50), Int64(R.Fg.G), 'midpoint G');
  CheckEqual(Int64(50), Int64(R.Fg.B), 'midpoint B');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.style');
  T.Test('default', @TestDefault);
  T.Test('with fg/bg', @TestWithFgBg);
  T.Test('with modifier', @TestWithModifier);
  T.Test('without modifier', @TestWithoutModifier);
  T.Test('patch colors', @TestPatchColors);
  T.Test('patch modifiers', @TestPatchModifiers);
  T.Test('size 16 bytes', @TestSize);
  T.Test('style equals', @TestStyleEquals);
  T.Test('patch both unset', @TestPatchBothUnset);
  T.Test('patch self only', @TestPatchSelfOnly);
  T.Test('patch other only', @TestPatchOtherOnly);
  T.Test('with fg bg chain', @TestWithFgBgChain);
  T.Test('style interp', @TestStyleInterp);
  if not T.Run then Halt(1);
end.
