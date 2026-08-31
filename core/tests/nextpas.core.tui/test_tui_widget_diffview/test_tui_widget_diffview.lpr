program test_tui_widget_diffview;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.diffview,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestDiffLineKindEnum;
begin
  Check(Ord(dlContext) = 0, 'dlContext should be 0');
  Check(Ord(dlAdded) = 1, 'dlAdded should be 1');
  Check(Ord(dlRemoved) = 2, 'dlRemoved should be 2');
  Check(Ord(dlHeader) = 3, 'dlHeader should be 3');
end;

procedure TestDiffLineRecord;
var
  LLine: TDiffLine;
begin
  LLine.Kind := dlAdded;
  LLine.Text := '+ new line';
  LLine.OldNum := 0;
  LLine.NewNum := 1;
  Check(LLine.Kind = dlAdded, 'Kind should be dlAdded');
  Check(LLine.Text = '+ new line', 'Text should be + new line');
  Check(LLine.OldNum = 0, 'OldNum should be 0');
  Check(LLine.NewNum = 1, 'NewNum should be 1');
end;

procedure TestDiffViewStateEmpty;
var
  LState: TDiffViewState;
begin
  LState := TDiffViewState.Empty;
  Check(LState.ScrollY = 0, 'ScrollY should be 0');
  Check(LState.Selected = 0, 'Selected should be 0');
end;

procedure TestDiffViewStateScrollDown;
var
  LState: TDiffViewState;
begin
  LState := TDiffViewState.Empty;
  LState.ScrollDown;
  Check(LState.ScrollY = 1, 'ScrollY should be 1 after ScrollDown');
  LState.ScrollDown(5);
  Check(LState.ScrollY = 6, 'ScrollY should be 6 after ScrollDown(5)');
end;

procedure TestDiffViewStateScrollUp;
var
  LState: TDiffViewState;
begin
  LState := TDiffViewState.Empty;
  LState.ScrollY := 10;
  LState.ScrollUp;
  Check(LState.ScrollY = 9, 'ScrollY should be 9 after ScrollUp');
  LState.ScrollUp(5);
  Check(LState.ScrollY = 4, 'ScrollY should be 4 after ScrollUp(5)');
end;

procedure TestDiffViewStateScrollUpBoundary;
var
  LState: TDiffViewState;
begin
  LState := TDiffViewState.Empty;
  LState.ScrollUp;
  Check(LState.ScrollY = 0, 'ScrollY should not go below 0');
  LState.ScrollUp(10);
  Check(LState.ScrollY = 0, 'ScrollY should still be 0');
end;

procedure TestDiffViewNew;
var
  LDiffView: IDiffView;
  LLines: array[0..2] of TDiffLine;
begin
  LLines[0].Kind := dlContext;
  LLines[0].Text := ' context line';
  LLines[0].OldNum := 1;
  LLines[0].NewNum := 1;
  LLines[1].Kind := dlAdded;
  LLines[1].Text := '+ added line';
  LLines[1].OldNum := 0;
  LLines[1].NewNum := 2;
  LLines[2].Kind := dlRemoved;
  LLines[2].Text := '- removed line';
  LLines[2].OldNum := 2;
  LLines[2].NewNum := 0;
  LDiffView := TDiffView.New(LLines);
  Check(LDiffView <> nil, 'New diffview should not be nil');
end;

procedure TestDiffViewFromUnifiedDiff;
var
  LDiffView: IDiffView;
  LDiff: AnsiString;
begin
  LDiff := '--- a/file.pas' + LineEnding +
           '+++ b/file.pas' + LineEnding +
           '@@ -1,3 +1,3 @@' + LineEnding +
           ' line1' + LineEnding +
           '-line2' + LineEnding +
           '+line3' + LineEnding +
           ' line4';
  LDiffView := TDiffView.FromUnifiedDiff(LDiff);
  Check(LDiffView <> nil, 'FromUnifiedDiff should not return nil');
end;

procedure TestDiffViewWithStyle;
var
  LDiffView: IDiffView;
  LStyle: TStyle;
begin
  LDiffView := TDiffView.New([]);
  LStyle.Fg := IndexedColor(1);
  LDiffView := LDiffView.WithStyle(LStyle);
  Check(LDiffView <> nil, 'WithStyle should return diffview');
end;

procedure TestDiffViewWithAddedStyle;
var
  LDiffView: IDiffView;
  LStyle: TStyle;
begin
  LDiffView := TDiffView.New([]);
  LStyle.Fg := IndexedColor(2);
  LDiffView := LDiffView.WithAddedStyle(LStyle);
  Check(LDiffView <> nil, 'WithAddedStyle should return diffview');
end;

procedure TestDiffViewWithRemovedStyle;
var
  LDiffView: IDiffView;
  LStyle: TStyle;
begin
  LDiffView := TDiffView.New([]);
  LStyle.Fg := IndexedColor(3);
  LDiffView := LDiffView.WithRemovedStyle(LStyle);
  Check(LDiffView <> nil, 'WithRemovedStyle should return diffview');
end;

procedure TestDiffViewHeaderStyleApplied;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LLine: TDiffLine;
  LCell: PCell;
  LState: TDiffViewState;
begin
  { WithHeaderStyle 渲染级断言：dlHeader 行文本格 Fg 落自定义色 }
  LLine.Kind := dlHeader;
  LLine.Text := '## head';
  LLine.OldNum := 0;
  LLine.NewNum := 0;
  LDiffView := TDiffView.New([LLine])
    .WithHeaderStyle(TStyle.Default.WithFg(TUI_RED));
  LArea := TRect.Make(0, 0, 20, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TDiffViewState.Empty;
    LDiffView.RenderStateful(LArea, LBuffer, LState);
    LCell := LBuffer.CellAt(5, 0);   { TextX = Inner.X + GutterW(5) }
    Check(LCell <> nil, 'header text cell exists');
    if LCell <> nil then
      Check(ColorEquals(TUI_RED, LCell^.Fg), 'header style fg applied');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewLineNumStyleApplied;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LLine: TDiffLine;
  LCell: PCell;
  LState: TDiffViewState;
begin
  { WithLineNumStyle 渲染级断言：行号 gutter 格 Fg 落自定义色 }
  LLine.Kind := dlContext;
  LLine.Text := ' code';
  LLine.OldNum := 0;
  LLine.NewNum := 1;
  LDiffView := TDiffView.New([LLine])
    .WithLineNumStyle(TStyle.Default.WithFg(TUI_CYAN));
  LArea := TRect.Make(0, 0, 20, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TDiffViewState.Empty;
    LDiffView.RenderStateful(LArea, LBuffer, LState);
    LCell := LBuffer.CellAt(3, 0);   { NumBuf '   1' 末位（右对齐 4 宽）}
    Check(LCell <> nil, 'line num cell exists');
    if LCell <> nil then
      Check(ColorEquals(TUI_CYAN, LCell^.Fg), 'line num style fg applied');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewWithBlock;
var
  LDiffView: IDiffView;
  LBlock: IBlock;
begin
  LDiffView := TDiffView.New([]);
  LBlock := TBlock.New;
  LDiffView := LDiffView.WithBlock(LBlock);
  Check(LDiffView <> nil, 'WithBlock should return diffview');
end;

procedure TestDiffViewRender;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: array[0..0] of TDiffLine;
begin
  LLines[0].Kind := dlContext;
  LLines[0].Text := ' test';
  LLines[0].OldNum := 1;
  LLines[0].NewNum := 1;
  LDiffView := TDiffView.New(LLines);
  LArea := TRect.Make(0, 0, 20, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LDiffView.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewRenderStateful;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LState: TDiffViewState;
  LLines: array[0..0] of TDiffLine;
begin
  LLines[0].Kind := dlContext;
  LLines[0].Text := ' test';
  LLines[0].OldNum := 1;
  LLines[0].NewNum := 1;
  LDiffView := TDiffView.New(LLines);
  LArea := TRect.Make(0, 0, 20, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TDiffViewState.Empty;
    LDiffView.RenderStateful(LArea, LBuffer, LState);
    Check(True, 'RenderStateful should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewBuilderChaining;
var
  LDiffView: IDiffView;
  LStyle: TStyle;
begin
  LDiffView := TDiffView.New([]);
  LStyle.Fg := IndexedColor(1);
  LDiffView := LDiffView
    .WithStyle(LStyle)
    .WithAddedStyle(LStyle)
    .WithRemovedStyle(LStyle);
  Check(LDiffView <> nil, 'Builder chaining should work');
end;

procedure TestDiffViewNewEmpty;
var
  LDiffView: IDiffView;
begin
  LDiffView := TDiffView.New([]);
  Check(LDiffView <> nil, 'New with empty lines should not be nil');
end;

procedure TestDiffViewRenderEmpty;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LDiffView := TDiffView.New([]);
  LArea := TRect.Make(0, 0, 20, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LDiffView.Render(LArea, LBuffer);
    Check(True, 'Render empty diffview should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewRenderSmallArea;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: array[0..0] of TDiffLine;
begin
  LLines[0].Kind := dlAdded;
  LLines[0].Text := '+ test';
  LLines[0].OldNum := 0;
  LLines[0].NewNum := 1;
  LDiffView := TDiffView.New(LLines);
  LArea := TRect.Make(0, 0, 5, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LDiffView.Render(LArea, LBuffer);
    Check(True, 'Render in small area should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDiffViewFromUnifiedDiffEmpty;
var
  LDiffView: IDiffView;
begin
  LDiffView := TDiffView.FromUnifiedDiff('');
  Check(LDiffView <> nil, 'FromUnifiedDiff empty should not be nil');
end;

procedure TestUnifiedToLinesMultiHunkLineNumbers;
var
  LLines: TDiffLineArray;
  LDiff: AnsiString;
begin
  // two hunks: the real @@ start numbers must drive Old/NewNum — the old
  // inline parser reset to 1 for every hunk and misnumbered the second one
  LDiff := '@@ -5,2 +5,2 @@' + LineEnding +
           ' ctx' + LineEnding +
           '-old5' + LineEnding +
           '+new5' + LineEnding +
           '@@ -20,1 +21,1 @@' + LineEnding +
           '-old20' + LineEnding;
  LLines := TDiffView.UnifiedToLines(LDiff);
  Check(Length(LLines) = 6, 'multi-hunk line count');
  Check((LLines[0].Kind = dlHeader), 'hunk1 header present');
  Check((LLines[1].Kind = dlContext) and (LLines[1].OldNum = 5)
    and (LLines[1].NewNum = 5), 'hunk1 context uses real start numbers');
  Check((LLines[2].Kind = dlRemoved) and (LLines[2].OldNum = 6),
    'hunk1 removed number');
  Check((LLines[3].Kind = dlAdded) and (LLines[3].NewNum = 6),
    'hunk1 added number');
  Check(LLines[4].Kind = dlHeader, 'hunk2 header present');
  Check((LLines[5].Kind = dlRemoved) and (LLines[5].OldNum = 20),
    'hunk2 removed keeps its own start (regression for reset-to-1 bug)');
end;

procedure TestDiffViewMultipleLines;
var
  LDiffView: IDiffView;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: array[0..3] of TDiffLine;
begin
  LLines[0].Kind := dlHeader;
  LLines[0].Text := '--- a/file.pas';
  LLines[0].OldNum := 0;
  LLines[0].NewNum := 0;
  LLines[1].Kind := dlContext;
  LLines[1].Text := ' line1';
  LLines[1].OldNum := 1;
  LLines[1].NewNum := 1;
  LLines[2].Kind := dlRemoved;
  LLines[2].Text := '-line2';
  LLines[2].OldNum := 2;
  LLines[2].NewNum := 0;
  LLines[3].Kind := dlAdded;
  LLines[3].Text := '+line3';
  LLines[3].OldNum := 0;
  LLines[3].NewNum := 2;
  LDiffView := TDiffView.New(LLines);
  LArea := TRect.Make(0, 0, 30, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LDiffView.Render(LArea, LBuffer);
    Check(True, 'Render multiple lines should not raise');
  finally
    LBuffer.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.diffview');
  T.Test('TDiffLineKind enum', @TestDiffLineKindEnum);
  T.Test('TDiffLine record', @TestDiffLineRecord);
  T.Test('TDiffViewState.Empty', @TestDiffViewStateEmpty);
  T.Test('TDiffViewState.ScrollDown', @TestDiffViewStateScrollDown);
  T.Test('TDiffViewState.ScrollUp', @TestDiffViewStateScrollUp);
  T.Test('TDiffViewState.ScrollUp boundary', @TestDiffViewStateScrollUpBoundary);
  T.Test('TDiffView.New', @TestDiffViewNew);
  T.Test('TDiffView.FromUnifiedDiff', @TestDiffViewFromUnifiedDiff);
  T.Test('TDiffView.WithStyle', @TestDiffViewWithStyle);
  T.Test('TDiffView.WithAddedStyle', @TestDiffViewWithAddedStyle);
  T.Test('TDiffView.WithRemovedStyle', @TestDiffViewWithRemovedStyle);
  T.Test('TDiffView.WithHeaderStyle applied', @TestDiffViewHeaderStyleApplied);
  T.Test('TDiffView.WithLineNumStyle applied', @TestDiffViewLineNumStyleApplied);
  T.Test('TDiffView.WithBlock', @TestDiffViewWithBlock);
  T.Test('TDiffView.Render', @TestDiffViewRender);
  T.Test('TDiffView.RenderStateful', @TestDiffViewRenderStateful);
  T.Test('TDiffView builder chaining', @TestDiffViewBuilderChaining);
  T.Test('TDiffView.New empty', @TestDiffViewNewEmpty);
  T.Test('TDiffView.Render empty', @TestDiffViewRenderEmpty);
  T.Test('TDiffView.Render small area', @TestDiffViewRenderSmallArea);
  T.Test('TDiffView.FromUnifiedDiff empty', @TestDiffViewFromUnifiedDiffEmpty);
  T.Test('TDiffView.UnifiedToLines multi-hunk line numbers',
    @TestUnifiedToLinesMultiHunkLineNumbers);
  T.Test('TDiffView multiple lines', @TestDiffViewMultipleLines);
  if not T.Run then Halt(1);
end.
