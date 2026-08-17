unit nextpas.core.tui.theme;

// Lightweight theme system providing named style slots for consistent
// UI appearance.  Each TTheme is a plain record of TStyle values —
// no heap, no inheritance, no registry.  Consumers pick a preset
// (Dark/Light/Nord/Dracula) or build their own by value.

{$I nextpas.core.settings.inc}


interface

uses
  nextpas.core.tui.color, nextpas.core.tui.modifier, nextpas.core.tui.style;

type
  TTheme = record
    // Base styles
    Bg: TStyle;
    Fg: TStyle;
    // Widget styles
    Border: TStyle;
    BorderFocused: TStyle;
    Title: TStyle;
    Highlight: TStyle;
    // Semantic styles
    Primary: TStyle;
    Secondary: TStyle;
    Success: TStyle;
    Warning: TStyle;
    Error_: TStyle;
    Muted: TStyle;
    // Component-specific
    Header: TStyle;
    StatusBar: TStyle;
    Button: TStyle;
    ButtonActive: TStyle;

    class function Dark: TTheme; static;
    class function Light: TTheme; static;
    class function Nord: TTheme; static;
    class function Dracula: TTheme; static;
  end;

{ 主题插值：16 槽逐 StyleInterp（t∈[0,1]，0=A、1=B）。
  主题过渡动画用；非 RGB 端点按 ColorInterp 回退语义处理 }
function ThemeInterp(const A, B: TTheme; T: Double): TTheme;

implementation

function ThemeInterp(const A, B: TTheme; T: Double): TTheme;
begin
  Result.Bg            := StyleInterp(A.Bg, B.Bg, T);
  Result.Fg            := StyleInterp(A.Fg, B.Fg, T);
  Result.Border        := StyleInterp(A.Border, B.Border, T);
  Result.BorderFocused := StyleInterp(A.BorderFocused, B.BorderFocused, T);
  Result.Title         := StyleInterp(A.Title, B.Title, T);
  Result.Highlight     := StyleInterp(A.Highlight, B.Highlight, T);
  Result.Primary       := StyleInterp(A.Primary, B.Primary, T);
  Result.Secondary     := StyleInterp(A.Secondary, B.Secondary, T);
  Result.Success       := StyleInterp(A.Success, B.Success, T);
  Result.Warning       := StyleInterp(A.Warning, B.Warning, T);
  Result.Error_        := StyleInterp(A.Error_, B.Error_, T);
  Result.Muted         := StyleInterp(A.Muted, B.Muted, T);
  Result.Header        := StyleInterp(A.Header, B.Header, T);
  Result.StatusBar     := StyleInterp(A.StatusBar, B.StatusBar, T);
  Result.Button        := StyleInterp(A.Button, B.Button, T);
  Result.ButtonActive  := StyleInterp(A.ButtonActive, B.ButtonActive, T);
end;

class function TTheme.Dark: TTheme;
begin
  Result.Bg            := TStyle.Default.WithBg(TUI_BLACK);
  Result.Fg            := TStyle.Default.WithFg(TUI_WHITE);
  Result.Border        := TStyle.Default.WithFg(TUI_CYAN);
  Result.BorderFocused := TStyle.Default.WithFg(TUI_LIGHT_CYAN).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(TUI_WHITE).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(TUI_BLACK).WithBg(TUI_BLUE);
  Result.Primary       := TStyle.Default.WithFg(TUI_BLUE);
  Result.Secondary     := TStyle.Default.WithFg(TUI_GRAY);
  Result.Success       := TStyle.Default.WithFg(TUI_GREEN);
  Result.Warning       := TStyle.Default.WithFg(TUI_YELLOW);
  Result.Error_        := TStyle.Default.WithFg(TUI_RED);
  Result.Muted         := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.Header        := TStyle.Default.WithFg(TUI_WHITE).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_DARK_GRAY);
  Result.Button        := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_BLUE);
  Result.ButtonActive  := TStyle.Default.WithFg(TUI_BLACK).WithBg(TUI_LIGHT_BLUE);
end;

class function TTheme.Light: TTheme;
begin
  Result.Bg            := TStyle.Default.WithBg(TUI_WHITE);
  Result.Fg            := TStyle.Default.WithFg(TUI_BLACK);
  Result.Border        := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.BorderFocused := TStyle.Default.WithFg(TUI_BLACK).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(TUI_BLACK).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_BLUE);
  Result.Primary       := TStyle.Default.WithFg(TUI_BLUE);
  Result.Secondary     := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.Success       := TStyle.Default.WithFg(TUI_GREEN);
  Result.Warning       := TStyle.Default.WithFg(TUI_YELLOW);
  Result.Error_        := TStyle.Default.WithFg(TUI_RED);
  Result.Muted         := TStyle.Default.WithFg(TUI_GRAY);
  Result.Header        := TStyle.Default.WithFg(TUI_BLACK).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(TUI_BLACK).WithBg(TUI_GRAY);
  Result.Button        := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_BLUE);
  Result.ButtonActive  := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_LIGHT_BLUE);
end;

class function TTheme.Nord: TTheme;
begin
  // Nord palette
  Result.Bg            := TStyle.Default.WithBg(RgbColor(46, 52, 64));
  Result.Fg            := TStyle.Default.WithFg(RgbColor(236, 239, 244));
  Result.Border        := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.BorderFocused := TStyle.Default.WithFg(RgbColor(136, 192, 208)).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(136, 192, 208));
  Result.Primary       := TStyle.Default.WithFg(RgbColor(136, 192, 208));
  Result.Secondary     := TStyle.Default.WithFg(RgbColor(129, 161, 193));
  Result.Success       := TStyle.Default.WithFg(RgbColor(163, 190, 140));
  Result.Warning       := TStyle.Default.WithFg(RgbColor(235, 203, 139));
  Result.Error_        := TStyle.Default.WithFg(RgbColor(191, 97, 106));
  Result.Muted         := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.Header        := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithBg(RgbColor(59, 66, 82));
  Result.Button        := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(136, 192, 208));
  Result.ButtonActive  := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(129, 161, 193));
end;

class function TTheme.Dracula: TTheme;
begin
  // Dracula palette
  Result.Bg            := TStyle.Default.WithBg(RgbColor(40, 42, 54));
  Result.Fg            := TStyle.Default.WithFg(RgbColor(248, 248, 242));
  Result.Border        := TStyle.Default.WithFg(RgbColor(98, 114, 164));
  Result.BorderFocused := TStyle.Default.WithFg(RgbColor(189, 147, 249)).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(189, 147, 249));
  Result.Primary       := TStyle.Default.WithFg(RgbColor(189, 147, 249));
  Result.Secondary     := TStyle.Default.WithFg(RgbColor(139, 233, 253));
  Result.Success       := TStyle.Default.WithFg(RgbColor(80, 250, 123));
  Result.Warning       := TStyle.Default.WithFg(RgbColor(241, 250, 140));
  Result.Error_        := TStyle.Default.WithFg(RgbColor(255, 85, 85));
  Result.Muted         := TStyle.Default.WithFg(RgbColor(98, 114, 164));
  Result.Header        := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithBg(RgbColor(68, 71, 90));
  Result.Button        := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(189, 147, 249));
  Result.ButtonActive  := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(139, 233, 253));
end;

end.
