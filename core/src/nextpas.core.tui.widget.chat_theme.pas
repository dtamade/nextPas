unit nextpas.core.tui.widget.chat_theme;

// Theme record — a flat collection of named colors matching the
// cli888 TuiTheme structure.  Consumers pick colors by semantic name
// (bg_primary, accent_user, etc.) rather than hardcoding RGB values.
//
// Ships with one preset: DefaultDark (the cli888 default).  Adding
// more presets is trivial — just fill a new TTheme record.

{$I nextpas.core.settings.inc}

{$packenum 1}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style;

type
  TTheme = record
    // Backgrounds.
    BgPrimary:    TColor;   // main background
    BgSecondary:  TColor;   // status bar, panels
    BgInput:      TColor;   // input box interior
    BgHighlight:  TColor;   // selected/highlighted row
    BgUserMsg:    TColor;   // user message row background
    BgAiMsg:      TColor;   // AI message row background
    BgThinking:   TColor;   // thinking block background
    BgTool:       TColor;   // tool call background
    BgSystem:     TColor;   // system message background
    BgCode:       TColor;   // code block background

    // Foregrounds.
    FgPrimary:    TColor;   // main text
    FgSecondary:  TColor;   // secondary text
    FgMuted:      TColor;   // placeholder, weak text

    // Accents.
    AccentUser:   TColor;   // user indicator, focused border
    AccentAi:     TColor;   // AI indicator
    AccentTool:   TColor;   // tool indicator
    AccentBrand:  TColor;   // brand / purple accent

    // Status.
    StatusSuccess: TColor;
    StatusError:   TColor;
    StatusWarning: TColor;
    StatusInfo:    TColor;

    // Borders.
    BorderNormal: TColor;
    BorderFocus:  TColor;

    // Convenience style builders.
    function PrimaryText: TStyle;
    function SecondaryText: TStyle;
    function MutedText: TStyle;
    function UserLabel: TStyle;
    function AiLabel: TStyle;
    function ToolLabel: TStyle;
    function SystemLabel: TStyle;
    function InfoLabel: TStyle;
    function InputBorderFocused: TStyle;
    function InputBorderBlurred: TStyle;
    function StatusBarStyle: TStyle;
  end;

function ThemeDefaultDark: TTheme;

implementation

function TTheme.PrimaryText: TStyle;
begin Result := TStyle.Default.WithFg(FgPrimary); end;

function TTheme.SecondaryText: TStyle;
begin Result := TStyle.Default.WithFg(FgSecondary); end;

function TTheme.MutedText: TStyle;
begin Result := TStyle.Default.WithFg(FgMuted).WithModifier([mbItalic]); end;

function TTheme.UserLabel: TStyle;
begin Result := TStyle.Default.WithFg(AccentUser).WithModifier([mbBold]); end;

function TTheme.AiLabel: TStyle;
begin Result := TStyle.Default.WithFg(AccentAi).WithModifier([mbBold]); end;

function TTheme.ToolLabel: TStyle;
begin Result := TStyle.Default.WithFg(AccentTool).WithModifier([mbBold]); end;

function TTheme.SystemLabel: TStyle;
begin Result := TStyle.Default.WithFg(AccentBrand); end;

function TTheme.InfoLabel: TStyle;
begin Result := TStyle.Default.WithFg(StatusInfo); end;

function TTheme.InputBorderFocused: TStyle;
begin Result := TStyle.Default.WithFg(BorderFocus); end;

function TTheme.InputBorderBlurred: TStyle;
begin Result := TStyle.Default.WithFg(BorderNormal); end;

function TTheme.StatusBarStyle: TStyle;
begin Result := TStyle.Default.WithBg(BgSecondary).WithFg(FgSecondary); end;

function ThemeDefaultDark: TTheme;
begin
  // Backgrounds — cli888 presets.rs DefaultDark values.
  Result.BgPrimary   := RgbColor(30, 30, 30);
  Result.BgSecondary := RgbColor(40, 40, 40);
  Result.BgInput     := RgbColor(35, 35, 35);
  Result.BgHighlight := RgbColor(60, 60, 60);
  Result.BgUserMsg   := RgbColor(35, 45, 55);
  Result.BgAiMsg     := RgbColor(40, 50, 40);
  Result.BgThinking  := RgbColor(45, 45, 50);
  Result.BgTool      := RgbColor(50, 45, 40);
  Result.BgSystem    := RgbColor(45, 40, 40);
  Result.BgCode      := RgbColor(25, 25, 25);

  // Foregrounds.
  Result.FgPrimary   := RgbColor(224, 224, 224);
  Result.FgSecondary := RgbColor(160, 160, 160);
  Result.FgMuted     := RgbColor(100, 100, 100);

  // Accents.
  Result.AccentUser  := RgbColor(97, 175, 239);
  Result.AccentAi    := RgbColor(152, 195, 121);
  Result.AccentTool  := RgbColor(229, 192, 123);
  Result.AccentBrand := RgbColor(198, 120, 221);

  // Status.
  Result.StatusSuccess := RgbColor(152, 195, 121);
  Result.StatusError   := RgbColor(224, 108, 117);
  Result.StatusWarning := RgbColor(229, 192, 123);
  Result.StatusInfo    := RgbColor(97, 175, 239);

  // Borders.
  Result.BorderNormal := RgbColor(80, 80, 80);
  Result.BorderFocus  := RgbColor(97, 175, 239);
end;

end.
