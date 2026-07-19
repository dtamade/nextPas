program test_tui_widget_chat_theme;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.widget.chat_theme,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestDefaultDarkNotNil;
var
  LTheme: TTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(not ColorEquals(LTheme.BgPrimary, RgbColor(0, 0, 0)),
    'BgPrimary should not be black');
end;

procedure TestDefaultDarkBackgrounds;
var
  LTheme: TTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorEquals(LTheme.BgPrimary, RgbColor(30, 30, 30)), 'BgPrimary = (30,30,30)');
  Check(ColorEquals(LTheme.BgSecondary, RgbColor(40, 40, 40)), 'BgSecondary = (40,40,40)');
  Check(ColorEquals(LTheme.BgInput, RgbColor(35, 35, 35)), 'BgInput = (35,35,35)');
  Check(ColorEquals(LTheme.BgCode, RgbColor(25, 25, 25)), 'BgCode = (25,25,25)');
end;

procedure TestDefaultDarkForegrounds;
var
  LTheme: TTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorEquals(LTheme.FgPrimary, RgbColor(224, 224, 224)), 'FgPrimary = (224,224,224)');
  Check(ColorEquals(LTheme.FgSecondary, RgbColor(160, 160, 160)), 'FgSecondary = (160,160,160)');
  Check(ColorEquals(LTheme.FgMuted, RgbColor(100, 100, 100)), 'FgMuted = (100,100,100)');
end;

procedure TestDefaultDarkAccents;
var
  LTheme: TTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorEquals(LTheme.AccentUser, RgbColor(97, 175, 239)), 'AccentUser blue');
  Check(ColorEquals(LTheme.AccentAi, RgbColor(152, 195, 121)), 'AccentAi green');
  Check(ColorEquals(LTheme.AccentTool, RgbColor(229, 192, 123)), 'AccentTool yellow');
  Check(ColorEquals(LTheme.AccentBrand, RgbColor(198, 120, 221)), 'AccentBrand purple');
end;

procedure TestDefaultDarkStatus;
var
  LTheme: TTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorEquals(LTheme.StatusSuccess, RgbColor(152, 195, 121)), 'StatusSuccess green');
  Check(ColorEquals(LTheme.StatusError, RgbColor(224, 108, 117)), 'StatusError red');
  Check(ColorEquals(LTheme.StatusWarning, RgbColor(229, 192, 123)), 'StatusWarning yellow');
  Check(ColorEquals(LTheme.StatusInfo, RgbColor(97, 175, 239)), 'StatusInfo blue');
end;

procedure TestPrimaryTextStyle;
var
  LTheme: TTheme;
  LStyle: TStyle;
begin
  LTheme := ThemeDefaultDark;
  LStyle := LTheme.PrimaryText;
  Check(ColorEquals(LStyle.Fg, LTheme.FgPrimary), 'PrimaryText fg = FgPrimary');
end;

procedure TestMutedTextStyle;
var
  LTheme: TTheme;
  LStyle: TStyle;
begin
  LTheme := ThemeDefaultDark;
  LStyle := LTheme.MutedText;
  Check(ColorEquals(LStyle.Fg, LTheme.FgMuted), 'MutedText fg = FgMuted');
  Check(mbItalic in LStyle.AddMod, 'MutedText has italic modifier');
end;

procedure TestUserLabelStyle;
var
  LTheme: TTheme;
  LStyle: TStyle;
begin
  LTheme := ThemeDefaultDark;
  LStyle := LTheme.UserLabel;
  Check(ColorEquals(LStyle.Fg, LTheme.AccentUser), 'UserLabel fg = AccentUser');
  Check(mbBold in LStyle.AddMod, 'UserLabel has bold modifier');
end;

procedure TestStatusBarStyle;
var
  LTheme: TTheme;
  LStyle: TStyle;
begin
  LTheme := ThemeDefaultDark;
  LStyle := LTheme.StatusBarStyle;
  Check(ColorEquals(LStyle.Fg, LTheme.FgSecondary), 'StatusBar fg = FgSecondary');
  Check(ColorEquals(LStyle.Bg, LTheme.BgSecondary), 'StatusBar bg = BgSecondary');
end;

procedure TestInputBorderStyles;
var
  LTheme: TTheme;
  LFocus, LBlur: TStyle;
begin
  LTheme := ThemeDefaultDark;
  LFocus := LTheme.InputBorderFocused;
  LBlur := LTheme.InputBorderBlurred;
  Check(ColorEquals(LFocus.Fg, LTheme.BorderFocus), 'Focused border uses BorderFocus color');
  Check(ColorEquals(LBlur.Fg, LTheme.BorderNormal), 'Blurred border uses BorderNormal color');
  Check(not ColorEquals(LFocus.Fg, LBlur.Fg), 'Focused and blurred borders differ');
end;

begin
  T := TTestSuite.Create('tui_widget_chat_theme');
  T.Test('ThemeDefaultDark not nil', @TestDefaultDarkNotNil);
  T.Test('DefaultDark backgrounds', @TestDefaultDarkBackgrounds);
  T.Test('DefaultDark foregrounds', @TestDefaultDarkForegrounds);
  T.Test('DefaultDark accents', @TestDefaultDarkAccents);
  T.Test('DefaultDark status colors', @TestDefaultDarkStatus);
  T.Test('PrimaryText style', @TestPrimaryTextStyle);
  T.Test('MutedText style', @TestMutedTextStyle);
  T.Test('UserLabel style', @TestUserLabelStyle);
  T.Test('StatusBar style', @TestStatusBarStyle);
  T.Test('InputBorder styles', @TestInputBorderStyles);
  if not T.Run then Halt(1);
end.
