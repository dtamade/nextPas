program test_tui_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.full,
  nextpas.core.testing;

type
  TFullFacadeRenderHost = class
    procedure Render(AApp: TApp; var AFrame: TFrame);
  end;

  TFullFacadeScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
  end;

var
  T: TTestRunner;

procedure TFullFacadeRenderHost.Render(AApp: TApp; var AFrame: TFrame);
begin
  AFrame.Buffer.SetString(0, 0, 'x', StyleDefault);
  AApp.RequestAnimationFrame;
end;

procedure TFullFacadeScreen.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  ABuffer.SetString(AArea.X, AArea.Y, 'screen', StyleDefault);
end;

procedure TestCoreFacadeTypes;
var
  LArea: TRect;
  LSize: TSize;
  LColor: TColor;
  LStyle: TStyle;
  LEvent: TEvent;
begin
  LArea := TRect.Make(1, 2, 10, 4);
  LSize := SizeMake(10, 4);
  LColor := RgbColor(10, 20, 30);
  LStyle := TStyle.Default.WithFg(LColor);
  LEvent := ResizeEvent(LSize.Width, LSize.Height);

  CheckEqual(LongWord(40), LArea.Area, 'TRect facade alias works');
  CheckEqual(Word(10), LSize.Width, 'TSize facade alias works');
  Check(ColorEquals(LColor, LStyle.Fg), 'TColor/TStyle facade aliases work');
  Check(IsResize(LEvent), 'TEvent helper is reachable from facade');
end;

procedure TestWidgetFacadeTypes;
var
  LAdapterRender: TWidgetRenderFn;
  LAdapterWidget: IWidget;
  LBlock: IBlock;
  LParagraph: IParagraph;
  LList: IListWidget;
  LTable: ITable;
  LGauge: IGauge;
  LTabs: ITabsWidget;
  LScrollbar: IScrollbar;
  LCheckbox: ICheckbox;
  LRadio: IRadioGroup;
  LToast: IToastManager;
  LWidget: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Box');
  LAdapterRender :=
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      ABuffer.FillRect(AArea, '.', StyleDefault);
    end;
  LAdapterWidget := TWidgetAdapter.Create(LAdapterRender);
  LParagraph := TParagraph.FromString('hello').WithBlock(LBlock);
  LList := TListWidget.FromStrings(['one', 'two']).WithBlock(LBlock);
  LTable := TTable.New([TTableColumn.Make('Name', LengthConstraint(8))])
    .WithRows([TTableRow.Make(['Ada'])])
    .WithBlock(LBlock);
  LGauge := TGauge.New.WithRatio(0.5).WithBlock(LBlock);
  LTabs := TTabsWidget.New(['One', 'Two']);
  LScrollbar := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(20);
  LCheckbox := TCheckbox.New('Accept', False);
  LRadio := TRadioGroup.New(['A', 'B']);
  LToast := TToastManager.New;

  Check(LParagraph <> nil, 'paragraph facade type is usable');
  Check(LAdapterWidget <> nil, 'widget adapter facade type is usable');
  Check(LList <> nil, 'list facade type is usable');
  Check(LTable <> nil, 'table facade type is usable');
  Check(LGauge <> nil, 'gauge facade type is usable');
  Check(LTabs <> nil, 'tabs facade interface is usable');
  CheckEqual(Ord(shNone), Ord(LScrollbar.HitAt(TRect.Make(0, 0, 1, 10), 20)),
    'scrollbar facade interface is usable');
  Check(not LCheckbox.IsChecked, 'checkbox facade type is usable');
  LRadio.Select(1);
  CheckEqual(1, LRadio.GetSelected, 'radio facade type is usable');
  LToast.Push('Saved', tlSuccess);
  CheckEqual(1, LToast.Count, 'toast manager facade type is usable');

  LWidget := LBlock as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 3));
  try
    LWidget.Render(TRect.Make(0, 0, 12, 3), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('Box', LLines[0]) > 0, 'facade widget renders');
  finally
    LBuf.Free;
  end;
end;

procedure TestFacadeConstantsAndHelpers;
var
  LStyle: TStyle;
  LArea: TRect;
  LRects: TRectArray;
  LGrid: TGridResult;
  LPanel: IPanel;
  LPanelGrid: TPanelGrid;
  LCell: TRect;
  LHit: TSepHit;
  LWrap: TWrap;
  LAlign: TContentAlign;
  LTableColumn: TTableColumn;
  LColumn: TKanbanColumn;
  LMdLines: TMdLineArray;
  LChatTheme: TChatTheme;
  LClipboard: TClipboard;
  LClipboardMethod: TClipboardMethod;
  LImageProtocol: TImageProtocol;
  LInputState: TInputState;
  LTokens: TTokenArray;
begin
  Check(ColorEquals(TUI_CYAN, IndexedColor(6)), 'named color constants are re-exported');
  Check(ModifierIsEmpty(MODIFIER_NONE), 'modifier constants are re-exported');
  Check(BorderSetRounded.TopLeft <> '', 'border set presets are re-exported');
  Check(BorderSetPlain.Horizontal <> '', 'plain border set is re-exported');

  LStyle := TStyle.Default.WithFg(TUI_LIGHT_BLUE).WithModifier([mbBold]);
  Check(ColorEquals(TUI_LIGHT_BLUE, LStyle.Fg), 'named colors work in styles');

  LWrap := WRAP_TRIM;
  Check(LWrap.Trim, 'paragraph wrap type and preset are re-exported');
  LAlign := caRight;
  LTableColumn := TTableColumn.Make('Name', Fixed(8)).WithAlign(LAlign);
  CheckEqual(Ord(caRight), Ord(LTableColumn.Align), 'table alignment type and constants are re-exported');

  LArea := TRect.Make(0, 0, 12, 6);
  LRects := H(LArea, [Fixed(4), Flex(1)]);
  CheckEqual(Word(4), LRects[0].Width, 'layout DSL H/Fixed/Flex helpers are re-exported');
  LRects := V(LArea, [Pct(50), AtLeast(1), AtMost(1)]);
  CheckEqual(3, Length(LRects), 'layout DSL V/Pct/AtLeast/AtMost helpers are re-exported');
  CheckEqual(2, Length(Even(2)), 'layout DSL Even helper is re-exported');

  LGrid := Grid(LArea, 2, 2);
  CheckEqual(2, LGrid.Rows, 'grid helper is re-exported');
  CheckEqual(Word(6), LGrid.Cell(0, 0).Width, 'grid result type is re-exported');

  LPanel := TPanel.Grid(2, 2).WithEdges(PanelEdgesAll).WithPadding(1);
  LPanelGrid := LPanel.Layout(LArea);
  LCell := PanelCell(LPanelGrid, 0, 0);
  Check(LCell.Width > 0, 'panel cell helper is re-exported');
  LCell := PanelCellSpan(LPanelGrid, 0, 0, 2, 1);
  Check(LCell.Width > 0, 'panel span helper is re-exported');
  LHit := PanelHitTestSep(LPanelGrid, LPanelGrid.ColOffsets[1] - 1, LPanelGrid.RowOffsets[0]);
  Check(LHit.Found, 'panel separator hit-test helper is re-exported');
  Check(PanelEdgesNone = [], 'panel edge constants are re-exported');

  CheckEqual('2 KB', FormatBytes(2048), 'format helper is re-exported');
  CheckEqual('1 MB', FormatBytesKB(1024), 'KB format helper is re-exported');
  LImageProtocol := DetectImageProtocol;
  Check(Ord(LImageProtocol) >= Ord(ipKitty), 'image protocol helper is re-exported');
  LClipboardMethod := cmOSC52;
  CheckEqual(Ord(cmOSC52), Ord(LClipboardMethod), 'clipboard method constants are re-exported');
  LClipboard := TClipboard.Detect;
  Check(Ord(LClipboard.Method) >= Ord(cmOSC52), 'clipboard contract is re-exported');

  LColumn := MakeColumn('Todo', [TKanbanCard.Make('Ship')]);
  CheckEqual('Todo', LColumn.Title, 'kanban helper is re-exported');
  CheckEqual(1, Length(LColumn.Cards), 'kanban helper copies cards');

  LMdLines := ParseMarkdownLines('# Title'#10'- item');
  CheckEqual(2, Length(LMdLines), 'markdown parser helper is re-exported');
  CheckEqual(Ord(mlH1), Ord(LMdLines[0].Kind), 'markdown line kind is re-exported');

  LChatTheme := ThemeDefaultDark;
  Check(ColorIsSet(LChatTheme.FgPrimary), 'chat theme preset is re-exported');

  Check(FuzzyMatch('sv', 'Save File'), 'command palette fuzzy match is re-exported');
  Check(FuzzyScore('sf', 'Save File') > 0, 'command palette fuzzy score is re-exported');

  LInputState := TInputState.WithText('abc');
  LInputState.MoveLeft;
  CheckEqual(2, LInputState.Cursor, 'input state type is re-exported');

  LTokens := TokenizePascal('begin end');
  Check(Length(LTokens) >= 2, 'syntax tokenizer helper is re-exported');
  Check(IsPascalKeyword('begin'), 'syntax keyword helper is re-exported');
end;

procedure TestCompatibilityAliasesRemain;
var
  LArea: TTuiRect;
  LWidget: ITuiWidget;
begin
  LArea := TTuiRect.Make(0, 0, 1, 1);
  LWidget := TClearWidget.New;
  CheckEqual(LongWord(1), LArea.Area, 'TTuiRect compatibility alias remains');
  Check(LWidget <> nil, 'ITuiWidget compatibility alias remains');
end;

procedure TestFullFacadeCoversExtAndExperimentalSurface;
var
  LCompatApp: TTuiApp;
  LCompatScreen: TTuiScreen;
  LCompatStack: TTuiScreenStack;
  LCompatTheme: TTheme;
  LCompatChatTheme: TChatTheme;
  LCompatPanel: IPanel;
  LCompatGrid: TPanelGrid;
  LCompatRect: TRect;
  LCompatHit: TSepHit;
  LCompatEdges: TPanelEdges;
  LCompatEdge: TPanelEdge;
  LCompatTitle: TSepTitle;
  LCompatProtocol: TImageProtocol;
  LCompatClipboard: TClipboard;
  LCompatClipboardMethod: TClipboardMethod;
begin
  LCompatApp := TTuiApp.Create;
  LCompatStack := TTuiScreenStack.Create;
  try
    LCompatScreen := TFullFacadeScreen.Create;
    LCompatStack.Push(LCompatScreen);
    Check(LCompatStack.Top = LCompatScreen, 'full facade exposes app-first screen aliases');

    LCompatTheme := TTheme.Dark;
    LCompatChatTheme := ThemeDefaultDark;
    LCompatEdges := PanelEdgesOuter + PanelEdgesInner;
    LCompatEdge := peInnerV;
    LCompatTitle := Default(TSepTitle);
    LCompatPanel := TPanel.Grid(1, 1).WithEdges(LCompatEdges);
    LCompatGrid := LCompatPanel.Layout(TRect.Make(0, 0, 8, 4));
    LCompatRect := PanelCell(LCompatGrid, 0, 0);
    LCompatRect := PanelCellSpan(LCompatGrid, 0, 0, 1, 1);
    LCompatHit := PanelHitTestSep(LCompatGrid, LCompatGrid.ColOffsets[0], LCompatGrid.RowOffsets[0]);
    LCompatProtocol := ipSixel;
    LCompatClipboardMethod := cmNone;
    LCompatClipboard := TClipboard.Detect;

    Check(LCompatApp <> nil, 'full facade exposes TTuiApp compatibility alias');
    Check(SizeOf(TTuiFrame) > 0, 'full facade exposes TTuiFrame compatibility alias');
    Check(SizeOf(TScreenStack) > 0, 'full facade exposes TScreenStack alias');
    Check(ColorIsSet(LCompatTheme.Primary.Fg), 'full facade exposes stable TTheme record');
    Check(ColorIsSet(LCompatChatTheme.FgPrimary), 'full facade exposes stable chat theme preset');
    Check(LCompatEdge = peInnerV, 'full facade exposes panel edge constants');
    Check(LCompatEdges = PanelEdgesAll, 'full facade exposes panel edge sets');
    Check(not LCompatTitle.HasTitle, 'full facade exposes panel separator title record');
    Check(LCompatRect.Width > 0, 'full facade exposes panel layout helpers');
    Check(not LCompatHit.Found, 'full facade exposes panel separator hit type');
    CheckEqual(Ord(ipSixel), Ord(LCompatProtocol), 'full facade exposes experimental image constants');
    LCompatProtocol := ipHalfBlock;
    CheckEqual(Ord(ipHalfBlock), Ord(LCompatProtocol), 'full facade exposes fallback image protocol constant');
    CheckEqual(Ord(cmNone), Ord(LCompatClipboardMethod), 'full facade exposes clipboard method constants');
    Check(Ord(LCompatClipboard.Method) >= Ord(cmOSC52), 'full facade exposes experimental clipboard contract');
    LCompatProtocol := DetectImageProtocol;
    Check(Ord(LCompatProtocol) >= Ord(ipAuto), 'full facade exposes experimental image helper');
  finally
    LCompatStack.Free;
    LCompatApp.Free;
  end;
end;

procedure TestFullFacadeCoversAppTaskRuntimeSurface;
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
    LTaskStatus := tsRunning;
    LTaskResult := Default(TTaskResult);
    LTaskResult.Status := tsCompleted;
    LCompletion.Id := LTaskId;
    LCompletion.Result := LTaskResult;
    LLoading := TLoadingGroup.Empty;
    LLoading.Start(0, LCompletion.Id, 100);
    LLoading.Update([LCompletion], 1);

    Check(LApp.Tasks <> nil, 'full facade exposes app task manager slot');
    CheckEqual(Int64(Ord(tsRunning)), Int64(Ord(LTaskStatus)),
      'full facade exposes task status constants');
    CheckEqual(Int64(Ord(lpSuccess)), Int64(Ord(LLoading.GetPhase(0))),
      'full facade exposes loading group contract');
  finally
    LApp.Free;
  end;
end;

procedure TestFullFacadeAdvancedWidgetCatalogRemainsUsable;
var
  LSparkline: ISparkline;
  LBarChart: IBarChart;
  LCanvas: ICanvas;
  LTree: ITree;
  LDialog: IDialog;
  LMenu: IMenu;
  LTreeState: TTreeState;
  LMenuState: TMenuState;
  LArea: TRect;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LSparkline := TSparkline.New([1.0, 5.0, 2.0]).WithStyle(StyleDefault.WithFg(TUI_CYAN));
  LBarChart := TBarChart.New([
    TBarData.Make('A', 3.0),
    TBarData.Make('B', 7.0)
  ]).WithBarWidth(2).WithShowValues(False);
  LCanvas := TCanvas.New(4, 2).WithStyle(StyleDefault.WithFg(TUI_GREEN));
  LCanvas.DrawLine(0, 0, LCanvas.Width - 1, LCanvas.Height - 1);
  LTree := TTree.New([
    TTreeNode.Make('Root').WithChildren([
      TTreeNode.Make('Child')
    ])
  ]).WithIndent(3);
  LDialog := TDialog.New('Confirm', 'Ship now?')
    .WithButtons(['Yes', 'No'])
    .WithWidth(24)
    .WithHeight(7);
  LMenu := TMenu.New([
    TMenuItem.Action('Open'),
    TMenuItem.Separator,
    TMenuItem.Action('Quit')
  ]).WithWidth(16);

  LTreeState := TTreeState.Empty;
  LTreeState.Toggle(0);
  LMenuState := TMenuState.Default;
  LMenu.MoveDown(LMenuState);
  LArea := TRect.Make(0, 0, 24, 8);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    (LSparkline as IWidget).Render(TRect.Make(0, 0, 8, 2), LBuf);
    (LBarChart as IWidget).Render(TRect.Make(0, 2, 8, 6), LBuf);
    (LCanvas as IWidget).Render(TRect.Make(9, 0, 4, 2), LBuf);
    LTree.RenderStateful(TRect.Make(14, 0, 10, 4), LBuf, LTreeState);
    LMenu.RenderStateful(TRect.Make(14, 4, 10, 3), LBuf, LMenuState);
    LDialog.Render(LArea, LBuf);
    LLines := LBuf.AsLines;

    Check(LSparkline <> nil, 'full facade exposes sparkline contract');
    Check(LBarChart <> nil, 'full facade exposes barchart contract');
    CheckEqual(8, LCanvas.Width, 'full facade exposes canvas dimension contract');
    Check(LCanvas.GetDot(0, 0), 'full facade exposes canvas drawing contract');
    Check(LTreeState.IsOpen(0), 'full facade exposes tree state contract');
    CheckEqual(2, LMenuState.Selected, 'full facade exposes menu navigation contract');
    CheckEqual(2, LMenu.SelectableCount, 'full facade exposes menu selection contract');
    CheckEqual(Word(24), LDialog.CenteredArea(TRect.Make(0, 0, 30, 12)).Width,
      'full facade exposes dialog sizing contract');
    Check(Pos('Confirm', LLines[0]) > 0, 'full facade advanced widgets still render into buffer');
  finally
    LBuf.Free;
  end;
end;

procedure TestReadmeQuickStartCompiles;
var
  LApp: TTuiApp;
  LHost: TFullFacadeRenderHost;
begin
  LApp := TTuiApp.Create;
  LHost := TFullFacadeRenderHost.Create;
  try
    LApp.OnRenderCb := @LHost.Render;
    Check(True, 'full facade app callback wiring compiles');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

procedure TestFullFacadeExposesTuiExceptions;
var
  LBackend: ETuiBackend;
  LTui: ETui;
  LCaught: Boolean;
begin
  LBackend := ETuiBackend.Create('full facade backend');
  try
    LTui := LBackend;
    Check(LTui is ETuiBackend,
      'full facade exposes ETuiBackend as an ETui subtype');
  finally
    LBackend.Free;
  end;

  LCaught := False;
  try
    raise ETuiBackend.Create('full facade catch');
  except
    on E: ETui do
      LCaught := E is ETuiBackend;
  end;
  Check(LCaught, 'full facade lets app code catch backend failures as ETui');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.facade');
  T.Run('core facade types', @TestCoreFacadeTypes);
  T.Run('widget facade types', @TestWidgetFacadeTypes);
  T.Run('facade constants and helpers', @TestFacadeConstantsAndHelpers);
  T.Run('compatibility aliases remain', @TestCompatibilityAliasesRemain);
  T.Run('full facade covers ext and experimental contract', @TestFullFacadeCoversExtAndExperimentalSurface);
  T.Run('full facade covers app task runtime surface', @TestFullFacadeCoversAppTaskRuntimeSurface);
  T.Run('full facade advanced widget catalog remains usable', @TestFullFacadeAdvancedWidgetCatalogRemainsUsable);
  T.Run('full facade app callback wiring compiles', @TestReadmeQuickStartCompiles);
  T.Run('full facade exposes tui exceptions', @TestFullFacadeExposesTuiExceptions);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
