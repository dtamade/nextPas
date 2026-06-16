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
    // typed accessor visible from ext facade
    LApp.specialize GetShared<TObject>;
    LScreen.specialize GetShared<TObject>;
    Check(True, 'ext facade exposes typed GetShared accessor');
  finally
    LSharedState.Free;
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestExtAppTaskSurface;
var
  LApp: TApp;
  LTaskId: TTaskId;
  LTaskStatus: TTaskStatus;
  LTaskResult: TTaskResult;
  LCompletion: TCompletionSlot;
  LLoading: TLoadingGroup;
begin
  LApp := TApp.Create;
  try
    LTaskId := 1;
    LTaskStatus := tsQueued;
    LTaskResult := Default(TTaskResult);
    LTaskResult.Status := tsCompleted;
    LCompletion.Id := LTaskId;
    LCompletion.Result := LTaskResult;
    LLoading := TLoadingGroup.Empty;
    LLoading.Start(0, LCompletion.Id, 100);
    LLoading.Update([LCompletion], 1);

    Check(LApp.Tasks <> nil, 'ext facade exposes app task manager slot');
    CheckEqual(Int64(Ord(tsQueued)), Int64(Ord(LTaskStatus)),
      'ext facade exposes task status constants');
    CheckEqual(Int64(Ord(lpSuccess)), Int64(Ord(LLoading.GetPhase(0))),
      'ext facade exposes loading group contract');
  finally
    LApp.Free;
  end;
end;

procedure TestExtFacadeExposesTuiExceptions;
var
  LBackend: ETuiBackend;
  LTui: ETui;
  LCaught: Boolean;
begin
  LBackend := ETuiBackend.Create('ext facade backend');
  try
    LTui := LBackend;
    Check(LTui is ETuiBackend,
      'ext facade exposes ETuiBackend as an ETui subtype');
  finally
    LBackend.Free;
  end;

  LCaught := False;
  try
    raise ETuiBackend.Create('ext facade catch');
  except
    on E: ETui do
      LCaught := E is ETuiBackend;
  end;
  Check(LCaught, 'ext facade lets app code catch backend failures as ETui');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.ext_facade');
  T.Run('ext surface', @TestExtSurface);
  T.Run('ext app task surface', @TestExtAppTaskSurface);
  T.Run('ext facade exposes tui exceptions', @TestExtFacadeExposesTuiExceptions);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
