program test_tui_chat_theme;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.widget.chat_theme,
  nextpas.core.testing;

var T: TTestRunner;

{ === ThemeDefaultDark === }

procedure TestDefaultDarkFactory;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(ColorIsSet(Theme.BgPrimary), 'BgPrimary is set');
  Check(ColorIsSet(Theme.FgPrimary), 'FgPrimary is set');
  Check(ColorIsSet(Theme.AccentUser), 'AccentUser is set');
  Check(ColorIsSet(Theme.AccentAi), 'AccentAi is set');
  Check(ColorIsSet(Theme.BorderFocus), 'BorderFocus is set');
end;

procedure TestDefaultDarkBgColors;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(Theme.BgPrimary.Kind = ckRgb, 'BgPrimary is RGB');
  Check(Theme.BgSecondary.Kind = ckRgb, 'BgSecondary is RGB');
  Check(Theme.BgInput.Kind = ckRgb, 'BgInput is RGB');
  Check(Theme.BgHighlight.Kind = ckRgb, 'BgHighlight is RGB');
  Check(Theme.BgUserMsg.Kind = ckRgb, 'BgUserMsg is RGB');
  Check(Theme.BgAiMsg.Kind = ckRgb, 'BgAiMsg is RGB');
  Check(Theme.BgThinking.Kind = ckRgb, 'BgThinking is RGB');
  Check(Theme.BgTool.Kind = ckRgb, 'BgTool is RGB');
  Check(Theme.BgSystem.Kind = ckRgb, 'BgSystem is RGB');
  Check(Theme.BgCode.Kind = ckRgb, 'BgCode is RGB');
end;

procedure TestDefaultDarkFgColors;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(Theme.FgPrimary.Kind = ckRgb, 'FgPrimary is RGB');
  Check(Theme.FgSecondary.Kind = ckRgb, 'FgSecondary is RGB');
  Check(Theme.FgMuted.Kind = ckRgb, 'FgMuted is RGB');
end;

procedure TestDefaultDarkAccents;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(Theme.AccentUser.Kind = ckRgb, 'AccentUser is RGB');
  Check(Theme.AccentAi.Kind = ckRgb, 'AccentAi is RGB');
  Check(Theme.AccentTool.Kind = ckRgb, 'AccentTool is RGB');
  Check(Theme.AccentBrand.Kind = ckRgb, 'AccentBrand is RGB');
end;

procedure TestDefaultDarkStatus;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(Theme.StatusSuccess.Kind = ckRgb, 'StatusSuccess is RGB');
  Check(Theme.StatusError.Kind = ckRgb, 'StatusError is RGB');
  Check(Theme.StatusWarning.Kind = ckRgb, 'StatusWarning is RGB');
  Check(Theme.StatusInfo.Kind = ckRgb, 'StatusInfo is RGB');
end;

procedure TestDefaultDarkBorders;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(Theme.BorderNormal.Kind = ckRgb, 'BorderNormal is RGB');
  Check(Theme.BorderFocus.Kind = ckRgb, 'BorderFocus is RGB');
end;

{ === Style Builders === }

procedure TestPrimaryText;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.PrimaryText;
  Check(ColorEquals(S.Fg, Theme.FgPrimary), 'PrimaryText fg = FgPrimary');
end;

procedure TestSecondaryText;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.SecondaryText;
  Check(ColorEquals(S.Fg, Theme.FgSecondary), 'SecondaryText fg = FgSecondary');
end;

procedure TestMutedText;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.MutedText;
  Check(ColorEquals(S.Fg, Theme.FgMuted), 'MutedText fg = FgMuted');
  Check(mbItalic in S.AddMod, 'MutedText has italic modifier');
end;

procedure TestUserLabel;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.UserLabel;
  Check(ColorEquals(S.Fg, Theme.AccentUser), 'UserLabel fg = AccentUser');
  Check(mbBold in S.AddMod, 'UserLabel has bold modifier');
end;

procedure TestAiLabel;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.AiLabel;
  Check(ColorEquals(S.Fg, Theme.AccentAi), 'AiLabel fg = AccentAi');
  Check(mbBold in S.AddMod, 'AiLabel has bold modifier');
end;

procedure TestToolLabel;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.ToolLabel;
  Check(ColorEquals(S.Fg, Theme.AccentTool), 'ToolLabel fg = AccentTool');
  Check(mbBold in S.AddMod, 'ToolLabel has bold modifier');
end;

procedure TestSystemLabel;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.SystemLabel;
  Check(ColorEquals(S.Fg, Theme.AccentBrand), 'SystemLabel fg = AccentBrand');
end;

procedure TestInfoLabel;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.InfoLabel;
  Check(ColorEquals(S.Fg, Theme.StatusInfo), 'InfoLabel fg = StatusInfo');
end;

procedure TestInputBorderFocused;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.InputBorderFocused;
  Check(ColorEquals(S.Fg, Theme.BorderFocus), 'InputBorderFocused fg = BorderFocus');
end;

procedure TestInputBorderBlurred;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.InputBorderBlurred;
  Check(ColorEquals(S.Fg, Theme.BorderNormal), 'InputBorderBlurred fg = BorderNormal');
end;

procedure TestStatusBarStyle;
var Theme: TTheme; S: TStyle;
begin
  Theme := ThemeDefaultDark;
  S := Theme.StatusBarStyle;
  Check(ColorEquals(S.Bg, Theme.BgSecondary), 'StatusBar bg = BgSecondary');
  Check(ColorEquals(S.Fg, Theme.FgSecondary), 'StatusBar fg = FgSecondary');
end;

{ === Distinct color checks === }

procedure TestUserAiToolDistinct;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(not ColorEquals(Theme.AccentUser, Theme.AccentAi), 'User != Ai accent');
  Check(not ColorEquals(Theme.AccentUser, Theme.AccentTool), 'User != Tool accent');
  Check(not ColorEquals(Theme.AccentAi, Theme.AccentTool), 'Ai != Tool accent');
end;

procedure TestStatusColorsDistinct;
var Theme: TTheme;
begin
  Theme := ThemeDefaultDark;
  Check(not ColorEquals(Theme.StatusSuccess, Theme.StatusError), 'Success != Error');
  Check(not ColorEquals(Theme.StatusWarning, Theme.StatusInfo), 'Warning != Info');
end;

begin
  T := TTestRunner.Create('test_tui_chat_theme');
  try
    { Factory }
    T.Run('default dark factory', @TestDefaultDarkFactory);
    T.Run('default dark bg colors', @TestDefaultDarkBgColors);
    T.Run('default dark fg colors', @TestDefaultDarkFgColors);
    T.Run('default dark accents', @TestDefaultDarkAccents);
    T.Run('default dark status', @TestDefaultDarkStatus);
    T.Run('default dark borders', @TestDefaultDarkBorders);

    { Style builders }
    T.Run('PrimaryText', @TestPrimaryText);
    T.Run('SecondaryText', @TestSecondaryText);
    T.Run('MutedText', @TestMutedText);
    T.Run('UserLabel', @TestUserLabel);
    T.Run('AiLabel', @TestAiLabel);
    T.Run('ToolLabel', @TestToolLabel);
    T.Run('SystemLabel', @TestSystemLabel);
    T.Run('InfoLabel', @TestInfoLabel);
    T.Run('InputBorderFocused', @TestInputBorderFocused);
    T.Run('InputBorderBlurred', @TestInputBorderBlurred);
    T.Run('StatusBarStyle', @TestStatusBarStyle);

    { Distinct checks }
    T.Run('user/ai/tool accents distinct', @TestUserAiToolDistinct);
    T.Run('status colors distinct', @TestStatusColorsDistinct);

    WriteLn;
    T.Summary;
  finally
  end;
end.
