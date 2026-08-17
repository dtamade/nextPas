program test_tui_theme;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.modifier,
  nextpas.core.tui.theme,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestThemeDark;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dark;
  Check(LTheme.Bg.Fg.Kind = ckUnset, 'Dark Bg should have no Fg');
  Check(LTheme.Fg.Fg.Kind <> ckUnset, 'Dark Fg should have Fg set');
end;

procedure TestThemeLight;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Light;
  Check(LTheme.Bg.Fg.Kind = ckUnset, 'Light Bg should have no Fg');
  Check(LTheme.Fg.Fg.Kind <> ckUnset, 'Light Fg should have Fg set');
end;

procedure TestThemeNord;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Nord;
  Check(LTheme.Bg.Bg.Kind = ckRgb, 'Nord Bg should use RGB color');
  Check(LTheme.Fg.Fg.Kind = ckRgb, 'Nord Fg should use RGB color');
end;

procedure TestThemeDracula;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dracula;
  Check(LTheme.Bg.Bg.Kind = ckRgb, 'Dracula Bg should use RGB color');
  Check(LTheme.Fg.Fg.Kind = ckRgb, 'Dracula Fg should use RGB color');
end;

procedure TestThemeDarkHasAllSlots;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dark;
  Check(LTheme.Border.Fg.Kind <> ckUnset, 'Dark Border should have Fg');
  Check(LTheme.BorderFocused.Fg.Kind <> ckUnset, 'Dark BorderFocused should have Fg');
  Check(LTheme.Title.Fg.Kind <> ckUnset, 'Dark Title should have Fg');
  Check(LTheme.Highlight.Fg.Kind <> ckUnset, 'Dark Highlight should have Fg');
  Check(LTheme.Primary.Fg.Kind <> ckUnset, 'Dark Primary should have Fg');
  Check(LTheme.Secondary.Fg.Kind <> ckUnset, 'Dark Secondary should have Fg');
  Check(LTheme.Success.Fg.Kind <> ckUnset, 'Dark Success should have Fg');
  Check(LTheme.Warning.Fg.Kind <> ckUnset, 'Dark Warning should have Fg');
  Check(LTheme.Error_.Fg.Kind <> ckUnset, 'Dark Error should have Fg');
  Check(LTheme.Muted.Fg.Kind <> ckUnset, 'Dark Muted should have Fg');
  Check(LTheme.Header.Fg.Kind <> ckUnset, 'Dark Header should have Fg');
  Check(LTheme.StatusBar.Fg.Kind <> ckUnset, 'Dark StatusBar should have Fg');
  Check(LTheme.Button.Fg.Kind <> ckUnset, 'Dark Button should have Fg');
  Check(LTheme.ButtonActive.Fg.Kind <> ckUnset, 'Dark ButtonActive should have Fg');
end;

procedure TestThemeBorderFocusedHasBold;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dark;
  Check(mbBold in LTheme.BorderFocused.AddMod, 'Dark BorderFocused should have bold');
end;

procedure TestThemeTitleHasBold;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dark;
  Check(mbBold in LTheme.Title.AddMod, 'Dark Title should have bold');
end;

procedure TestThemeHeaderHasBold;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Dark;
  Check(mbBold in LTheme.Header.AddMod, 'Dark Header should have bold');
end;

procedure TestThemeLightBorderFocusedHasBold;
var
  LTheme: TTheme;
begin
  LTheme := TTheme.Light;
  Check(mbBold in LTheme.BorderFocused.AddMod, 'Light BorderFocused should have bold');
end;

procedure TestThemeDifferentPresets;
var
  LDark, LLight, LNord, LDracula: TTheme;
begin
  LDark := TTheme.Dark;
  LLight := TTheme.Light;
  LNord := TTheme.Nord;
  LDracula := TTheme.Dracula;
  Check(not StyleEquals(LDark.Bg, LLight.Bg), 'Dark and Light Bg should differ');
  Check(not StyleEquals(LDark.Bg, LNord.Bg), 'Dark and Nord Bg should differ');
  Check(not StyleEquals(LDark.Bg, LDracula.Bg), 'Dark and Dracula Bg should differ');
end;


procedure TestThemeLightSuccessError;
var
  L: TTheme;
begin
  L := TTheme.Light;
  Check(not StyleEquals(L.Success, L.Error_), 'Light Success != Error');
  Check(not StyleEquals(L.Warning, L.Muted), 'Light Warning != Muted');
end;

procedure TestThemeNordDraculaPrimaryDiffer;
var
  N, D: TTheme;
begin
  N := TTheme.Nord;
  D := TTheme.Dracula;
  Check(not StyleEquals(N.Primary, D.Primary), 'Nord/Dracula Primary differ');
  Check(not StyleEquals(N.Bg, D.Bg), 'Nord/Dracula Bg differ');
end;

procedure TestThemeInterp;
var
  A, B, R: TTheme;
begin
  A := TTheme.Nord;
  B := TTheme.Dracula;
  { T=0 恒等 A }
  R := ThemeInterp(A, B, 0);
  Check(ColorEquals(R.Bg.Bg, A.Bg.Bg), 'T=0 bg');
  Check(ColorEquals(R.Success.Fg, A.Success.Fg), 'T=0 success');
  { T=1 恒等 B }
  R := ThemeInterp(A, B, 1);
  Check(ColorEquals(R.Error_.Fg, B.Error_.Fg), 'T=1 error');
  Check(ColorEquals(R.ButtonActive.Bg, B.ButtonActive.Bg), 'T=1 button active');
  { T=0.5 中点：RGB 插值，非端槽位仍有效 }
  R := ThemeInterp(A, B, 0.5);
  Check(R.Primary.Fg.Kind = ckRgb, 'midpoint primary fg is rgb');
  Check(R.Muted.Fg.Kind = ckRgb, 'midpoint muted fg is rgb');
  Check(R.StatusBar.Bg.Kind = ckRgb, 'midpoint statusbar bg is rgb');
end;


begin
  T := TTestSuite.Create('tui_theme');
  T.Test('TTheme.Dark creates valid theme', @TestThemeDark);
  T.Test('TTheme.Light creates valid theme', @TestThemeLight);
  T.Test('TTheme.Nord uses RGB colors', @TestThemeNord);
  T.Test('TTheme.Dracula uses RGB colors', @TestThemeDracula);
  T.Test('TTheme.Dark has all style slots', @TestThemeDarkHasAllSlots);
  T.Test('TTheme.Dark BorderFocused has bold', @TestThemeBorderFocusedHasBold);
  T.Test('TTheme.Dark Title has bold', @TestThemeTitleHasBold);
  T.Test('TTheme.Dark Header has bold', @TestThemeHeaderHasBold);
  T.Test('TTheme.Light BorderFocused has bold', @TestThemeLightBorderFocusedHasBold);
  T.Test('Different presets have different styles', @TestThemeDifferentPresets);
    T.Test('Light Success != Error', @TestThemeLightSuccessError);
  T.Test('Nord Dracula Primary differ', @TestThemeNordDraculaPrimaryDiffer);
  T.Test('ThemeInterp', @TestThemeInterp);
  if not T.Run then Halt(1);
end.
