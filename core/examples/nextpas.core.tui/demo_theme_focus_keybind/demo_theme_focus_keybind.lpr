program demo_theme_focus_keybind;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.ext,
  nextpas.core.tui.event,
  nextpas.core.tui.keybind;

type
  TMainScreen = class(TScreen)
  private
    FKeys: TKeybindManager;
    FCurrentTheme: Integer;
    FThemeNames: array[0..3] of AnsiString;
    procedure CycleTheme;
    procedure RequestQuit;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

{ TMainScreen }

constructor TMainScreen.Create;
begin
  inherited Create;
  FCurrentTheme := 0;
  FThemeNames[0] := 'Dark';
  FThemeNames[1] := 'Light';
  FThemeNames[2] := 'Nord';
  FThemeNames[3] := 'Dracula';
  FKeys := TKeybindManager.Create;
  FKeys.BindCharMethod(kmNormal, '1', @CycleTheme, 'Cycle theme');
  FKeys.BindCharMethod(kmNormal, 'q', @RequestQuit, 'Quit');
  FKeys.BindKeyMethod(kmNormal, kcEsc, @RequestQuit, 'Quit');
end;

destructor TMainScreen.Destroy;
begin
  FKeys.Free;
  inherited Destroy;
end;

procedure TMainScreen.CycleTheme;
begin
  FCurrentTheme := (FCurrentTheme + 1) mod 4;
end;

procedure TMainScreen.RequestQuit;
begin
  Stack.RequestQuit;
end;

procedure TMainScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  T: TTheme;
begin
  case FCurrentTheme of
    1: T := TTheme.Light;
    2: T := TTheme.Nord;
    3: T := TTheme.Dracula;
  else
    T := TTheme.Dark;
  end;

  ABuffer.SetString(0, 0, '=== Theme / Focus / Keybind Demo ===', T.Title);
  ABuffer.SetString(0, 2, 'Theme: ' + FThemeNames[FCurrentTheme], T.Primary);
  ABuffer.SetString(0, 3, 'Press 1 to cycle themes.', T.Fg);
  ABuffer.SetString(0, 5, 'Theme previews:', T.Muted);
  ABuffer.SetString(0, 6, '  Dark   Light  Nord   Dracula', T.Fg);

  { Theme color swatches }
  ABuffer.SetString(0,  8, '  Dark  ', TTheme.Dark.Button);
  ABuffer.SetString(9,  8, '  Light ', TTheme.Light.Button);
  ABuffer.SetString(18, 8, '  Nord  ', TTheme.Nord.Button);
  ABuffer.SetString(27, 8, ' Dracula', TTheme.Dracula.Button);

  ABuffer.SetString(0, 10, 'Active preview:', T.Muted);
  ABuffer.SetString(0, 11, '  Active  ', T.ButtonActive);

  ABuffer.SetString(0, 13, 'Keybinds:', T.Fg);
  ABuffer.SetString(0, 14, '  1 - Cycle themes', T.Fg);
  ABuffer.SetString(0, 15, '  Q/Esc - Quit', T.Fg);

  ABuffer.SetString(0, 17, 'Press Q or Esc to quit.', T.Muted);
end;

procedure TMainScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit
  else if Ev.Kind = evKey then
    FKeys.HandleKey(Ev.Key);
end;

var
  App: TApp;
begin
  App := TApp.Create;
  try
    App.Screens.Push(TMainScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end.