program test_tui_ext_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext,
  nextpas.core.testing;

type
  TExtRenderHost = class
    procedure Render(AApp: TApp; var AFrame: TFrame);
  end;

  TExtScreen = class(TScreen)
  public
    RenderCount: Integer;
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
  end;

var
  T: TTestRunner;

procedure TExtRenderHost.Render(AApp: TApp; var AFrame: TFrame);
begin
  AFrame.Buffer.SetString(0, 0, 'x', StyleDefault);
  AApp.RequestAnimationFrame;
end;

procedure TExtScreen.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  Inc(RenderCount);
  ABuffer.SetString(0, 0, 'screen', StyleDefault);
end;

procedure TestExtSurface;
var
  LApp: TApp;
  LTheme: TChatTheme;
  LPanel: IPanel;
  LHost: TExtRenderHost;
  LScreen: TExtScreen;
  LSharedState: TObject;
begin
  LApp := TApp.Create;
  LHost := TExtRenderHost.Create;
  LSharedState := TObject.Create;
  try
    LTheme := ThemeDefaultDark;
    LPanel := TPanel.Grid(1, 1);
    LScreen := TExtScreen.Create;
    Check(LApp <> nil, 'ext facade exposes app');
    LApp.OnRenderCb := @LHost.Render;
    Check(True, 'ext facade exposes app callback wiring');
    Check(ColorIsSet(LTheme.FgPrimary), 'ext facade exposes theme presets');
    Check(LPanel <> nil, 'ext facade exposes stable advanced widgets');
    LApp.SharedStateObject := LSharedState;
    Check(LApp.SharedStateObject = LSharedState,
      'ext facade exposes app-owned shared-state slot');
    LApp.Screens.Push(LScreen);
    Check(LApp.Screens.Top = LScreen, 'ext facade exposes screen-driven app path');
    Check(LScreen.SharedStateObject = LSharedState,
      'ext facade exposes screen shared-state view');
  finally
    LSharedState.Free;
    LHost.Free;
    LApp.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.ext_facade');
  T.Run('ext surface', @TestExtSurface);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
