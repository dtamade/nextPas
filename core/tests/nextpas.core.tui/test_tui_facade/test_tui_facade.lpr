program test_tui_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui,
  nextpas.core.testing;

type
  TReadmeRenderHost = class
    procedure Render(AApp: TApp; var AFrame: TFrame);
  end;

var
  T: TTestRunner;

procedure TReadmeRenderHost.Render(AApp: TApp; var AFrame: TFrame);
begin
  AFrame.Buffer.SetString(0, 0, 'x', StyleDefault);
  AApp.RequestAnimationFrame;
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

procedure TestReadmeQuickStartCompiles;
var
  LApp: TTuiApp;
  LHost: TReadmeRenderHost;
begin
  LApp := TTuiApp.Create;
  LHost := TReadmeRenderHost.Create;
  try
    LApp.OnRenderCb := @LHost.Render;
    Check(True, 'README quick start callback wiring compiles against facade');
  finally
    LHost.Free;
    LApp.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.facade');
  T.Run('core facade types', @TestCoreFacadeTypes);
  T.Run('widget facade types', @TestWidgetFacadeTypes);
  T.Run('facade constants and helpers', @TestFacadeConstantsAndHelpers);
  T.Run('compatibility aliases remain', @TestCompatibilityAliasesRemain);
  T.Run('readme quick start compiles', @TestReadmeQuickStartCompiles);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
