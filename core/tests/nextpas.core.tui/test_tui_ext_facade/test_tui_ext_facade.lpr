program test_tui_ext_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,  { 必须第一：链接 tui.task（线程前置契约，见 CONTRACT §4） }
  nextpas.core.tui.ext,
  nextpas.core.test;

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
  T: TTestSuite;

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


procedure TestExtThemeAccent;
var
  LTheme: TChatTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorIsSet(LTheme.AccentUser), 'accent user');
  Check(ColorIsSet(LTheme.BgPrimary), 'bg primary');
  Check(ColorIsSet(LTheme.FgPrimary), 'fg primary set');
  Check(ColorIsSet(LTheme.FgMuted), 'fg muted set');
end;

procedure TestExtPanelGrid;
var
  LPanel: IPanel;
begin
  LPanel := TPanel.Grid(2, 2);
  Check(LPanel <> nil, '2x2 panel');
end;

procedure TestExtAppScreensEmpty;
var
  LApp: TApp;
begin
  LApp := TApp.Create;
  try
    Check(LApp.Screens.Count = 0, 'screens empty');
    Check(LApp.Screens.IsEmpty, 'IsEmpty');
  finally
    LApp.Free;
  end;
end;

procedure TestExtLoadingEmptyAllDone;
var
  LLoading: TLoadingGroup;
begin
  LLoading := TLoadingGroup.Empty;
  Check(LLoading.AllDone, 'empty all done');
  Check(not LLoading.AnyLoading, 'not loading');
end;

procedure TestExtScreenRenderCount;
var
  LApp: TApp;
  LScreen: TExtScreen;
begin
  LApp := TApp.Create;
  LScreen := TExtScreen.Create;
  try
    LApp.Screens.Push(LScreen);
    Check(LApp.Screens.Count = 1, 'one screen');
    Check(LScreen.RenderCount = 0, 'render not auto-called');
  finally
    LApp.Free;
  end;
end;

procedure TestExtThemeDarkFields;
var
  LTheme: TChatTheme;
begin
  LTheme := ThemeDefaultDark;
  Check(ColorIsSet(LTheme.FgPrimary), 'dark fg primary');
  Check(ColorIsSet(LTheme.BgPrimary), 'dark bg primary');
  Check(ColorIsSet(LTheme.AccentUser), 'dark accent user');
end;

procedure TestExtAppRequestAnimationFrame;
var
  LApp: TApp;
begin
  LApp := TApp.Create;
  try
    LApp.RequestAnimationFrame;
    Check(LApp <> nil, 'request animation frame keeps app');
    Check(LApp.Screens.IsEmpty, 'screens still empty');
  finally
    LApp.Free;
  end;
end;

procedure TestExtLoadingStartPhase;
var
  LLoading: TLoadingGroup;
  LCompletion: TCompletionSlot;
  LResult: TTaskResult;
begin
  LLoading := TLoadingGroup.Empty;
  LResult := Default(TTaskResult);
  LResult.Status := tsCompleted;
  LCompletion.Id := 7;
  LCompletion.Result := LResult;
  LLoading.Start(0, LCompletion.Id, 50);
  Check(LLoading.AnyLoading, 'started loading');
  Check(LLoading.GetPhase(0) <> lpSuccess, 'not success before update');
  LLoading.Update([LCompletion], 1);
  CheckEqual(Int64(Ord(lpSuccess)), Int64(Ord(LLoading.GetPhase(0))),
    'complete to success');
end;

procedure TestExtPanelGridOneByOne;
var
  LPanel: IPanel;
begin
  LPanel := TPanel.Grid(1, 1);
  Check(LPanel <> nil, '1x1 panel');
end;

procedure TestExtScrollViewSurface;
var
  LView: IScrollView;
  LState: TScrollViewState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LView := TScrollView.New;
  Check(LView <> nil, 'ext exposes TScrollView');
  LState := TScrollViewState.Empty;
  LState.ScrollDown(2);
  CheckEqual(2, LState.OffsetY, 'scroll state via ext');
  LArea := TRect.Make(0, 0, 20, 8);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LView.RenderStateful(LArea, LBuf, LState);
    Check(True, 'scrollview render stateful');
  finally
    LBuf.Free;
  end;
end;

procedure TestExtModalSurface;
var
  LModal: IModal;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LModal := TModal.New.WithSize(10, 4).WithVisible(True);
  Check(LModal <> nil, 'ext exposes TModal');
  LArea := TRect.Make(0, 0, 40, 20);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LModal.Render(LArea, LBuf);
    Check(True, 'modal render via ext');
  finally
    LBuf.Free;
  end;
end;

procedure TestExtDialogSurface;
var
  LDialog: IDialog;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LDialog := TDialog.New('Confirm', 'Proceed?').WithButtons(['OK', 'Cancel']);
  Check(LDialog <> nil, 'ext exposes TDialog');
  LArea := TRect.Make(0, 0, 40, 20);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LDialog.Render(LArea, LBuf);
    Check(True, 'dialog render via ext');
  finally
    LBuf.Free;
  end;
end;

procedure TestExtSplitPaneSurface;
var
  LSplit: ISplitPane;
  LState: TSplitPaneState;
  LArea, LPane1, LPane2, LDiv: TRect;
  LBuf: TBuffer;
begin
  LSplit := TSplitPane.Horizontal.WithMinSize1(2).WithMinSize2(2);
  Check(LSplit <> nil, 'ext exposes TSplitPane');
  LState := TSplitPaneState.Default;
  LArea := TRect.Make(0, 0, 40, 20);
  Check(LSplit.Split(LArea, LState, LPane1, LPane2, LDiv), 'split ok');
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LSplit.RenderDivider(LDiv, LBuf);
    Check(True, 'split_pane divider via ext');
  finally
    LBuf.Free;
  end;
end;

procedure TestExtSelectSurface;
var
  LSelect: ISelect;
  LState: TSelectState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LSelect := TSelect.New(['A', 'B', 'C']).WithPlaceholder('pick');
  Check(LSelect <> nil, 'ext exposes TSelect');
  LState := TSelectState.Empty;
  LArea := TRect.Make(0, 0, 40, 20);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LSelect.RenderStateful(LArea, LBuf, LState);
    Check(True, 'select render via ext');
  finally
    LBuf.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.ext_facade');
  T.Test('ext surface', @TestExtSurface);
  T.Test('ext app task surface', @TestExtAppTaskSurface);
  T.Test('ext facade exposes tui exceptions', @TestExtFacadeExposesTuiExceptions);
  T.Test('ext theme accent', @TestExtThemeAccent);
  T.Test('ext panel grid', @TestExtPanelGrid);
  T.Test('ext app screens empty', @TestExtAppScreensEmpty);
  T.Test('ext loading empty all done', @TestExtLoadingEmptyAllDone);
  T.Test('ext screen render count', @TestExtScreenRenderCount);
  T.Test('ext theme dark fields', @TestExtThemeDarkFields);
  T.Test('ext app request animation frame', @TestExtAppRequestAnimationFrame);
  T.Test('ext loading start phase', @TestExtLoadingStartPhase);
  T.Test('ext panel grid 1x1', @TestExtPanelGridOneByOne);
  T.Test('ext scrollview surface', @TestExtScrollViewSurface);
  T.Test('ext modal surface', @TestExtModalSurface);
  T.Test('ext dialog surface', @TestExtDialogSurface);
  T.Test('ext split_pane surface', @TestExtSplitPaneSurface);
  T.Test('ext select surface', @TestExtSelectSurface);
  if not T.Run then Halt(1);
end.
