program test_tui_stress;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.layout,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.list,
  nextpas.core.tui.widget.table,
  nextpas.core.test;
var T: TTestSuite;

procedure TestLargeBuffer;
var LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 80));
  try
    Check(LBuf.Width = 300, '300 cols');
    Check(LBuf.Height = 80, '80 rows');
    Check(LBuf.Length_ = 24000, '24000 cells');
  finally LBuf.Free; end;
end;

procedure TestLargeBufferDiff;
var LPrev, LCurr: TBuffer; LPatches: TDiffEntries; LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 80));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 80));
  try
    LCurr.SetString(0, 0, 'changed', TStyle.Default);
    LCurr.SetString(0, 40, 'middle', TStyle.Default);
    LCurr.SetString(0, 79, 'bottom', TStyle.Default);
    LCount := LPrev.DiffInto(LCurr, LPatches);
    Check(LCount > 0, 'diff found changes');
    Check(LCount < 24000, 'diff not full redraw');
  finally LPrev.Free; LCurr.Free; end;
end;

procedure TestLargeBufferIdenticalDiff;
var LPrev, LCurr: TBuffer; LPatches: TDiffEntries; LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 80));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 80));
  try
    LCount := LPrev.DiffInto(LCurr, LPatches);
    Check(LCount = 0, 'identical 4K buffers = 0 patches');
  finally LPrev.Free; LCurr.Free; end;
end;

procedure TestLargeListRender;
var
  LList: IListWidget;
  LItems: array of TListItem;
  LState: TListState;
  LBuf: TBuffer;
  I: Integer;
begin
  SetLength(LItems, 10000);
  for I := 0 to 9999 do
    LItems[I] := TListItem.FromString('Item ' + Chr(48 + (I mod 10)) + Chr(48 + ((I div 10) mod 10)));
  LList := TListWidget.New(LItems);
  LState := TListState.Empty;
  LState.Select(5000);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 80, 40));
  try
    LList.RenderStateful(TRect.Make(0, 0, 80, 40), LBuf, LState);
    Check(True, '10000 item list renders');
  finally LBuf.Free; end;
end;

procedure TestLargeTableRender;
var
  LTable: ITable;
  LCols: array of TTableColumn;
  LRows: array of TTableRow;
  LState: TTableState;
  LBuf: TBuffer;
  I: Integer;
begin
  SetLength(LCols, 20);
  for I := 0 to 19 do
    LCols[I] := TTableColumn.Make('C' + Chr(48 + I mod 10), LengthConstraint(10));
  SetLength(LRows, 100);
  for I := 0 to 99 do
    LRows[I] := TTableRow.Make(['data']);
  LTable := TTable.New(LCols).WithRows(LRows);
  LState := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 200, 50));
  try
    LTable.RenderStateful(TRect.Make(0, 0, 200, 50), LBuf, LState);
    Check(True, '20-col 100-row table renders');
  finally LBuf.Free; end;
end;

procedure TestLongStringRender;
var LBuf: TBuffer; LStr: AnsiString; LWritten: Integer;
begin
  LStr := StringOfChar('x', 10000);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 300, 1));
  try
    LWritten := LBuf.SetStringN(0, 0, LStr, 300, TStyle.Default);
    Check(LWritten = 300, '10KB string clipped to 300 cols');
  finally LBuf.Free; end;
end;

procedure TestParagraphWrapLong;
var LP: IParagraph; LBuf: TBuffer; LStr: AnsiString;
begin
  LStr := StringOfChar('w', 5000) + ' ' + StringOfChar('x', 5000);
  LP := TParagraph.FromString(LStr);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 80, 200));
  try
    LP.Render(TRect.Make(0, 0, 80, 200), LBuf);
    Check(True, '10KB paragraph wraps without crash');
  finally LBuf.Free; end;
end;


procedure TestSingleCellDiffUpperBound;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 100, 40));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 100, 40));
  try
    LCurr.SetString(0, 0, 'X', TStyle.Default);
    LCount := LPrev.DiffInto(LCurr, LPatches);
    Check(LCount > 0, 'found change');
    Check(LCount < 50, 'single cell change small patch set');
  finally
    LPrev.Free; LCurr.Free;
  end;
end;

procedure TestDiffIdempotentSameInputs;
var
  LPrev, LCurr: TBuffer;
  LPatches1, LPatches2: TDiffEntries;
  C1, C2: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 80, 20));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 80, 20));
  try
    LCurr.SetString(0, 5, 'row', TStyle.Default);
    C1 := LPrev.DiffInto(LCurr, LPatches1);
    C2 := LPrev.DiffInto(LCurr, LPatches2);
    CheckEqual(Int64(C1), Int64(C2), 'diff count stable');
  finally
    LPrev.Free; LCurr.Free;
  end;
end;

procedure TestBufferResizeRoundTrip;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 50, 20));
  try
    LBuf.Resize(TRect.Make(0, 0, 30, 10));
    CheckEqual(30, LBuf.Area.Width, 'shrunk w');
    LBuf.Resize(TRect.Make(0, 0, 60, 25));
    CheckEqual(60, LBuf.Area.Width, 'grown w');
    CheckEqual(25, LBuf.Area.Height, 'grown h');
  finally
    LBuf.Free;
  end;
end;

procedure TestEmptyListRender;
var
  LList: IListWidget;
  LState: TListState;
  LBuf: TBuffer;
begin
  LList := TListWidget.FromStrings([]);
  LState := TListState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LList.RenderStateful(TRect.Make(0, 0, 40, 10), LBuf, LState);
    CheckEqual(40, LBuf.Area.Width, 'empty list keeps area');
  finally
    LBuf.Free;
  end;
end;

procedure TestFillThenIdenticalDiff;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  Y: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 100, 30));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 100, 30));
  try
    for Y := 0 to 29 do
    begin
      LPrev.SetString(0, Y, 'same row content', TStyle.Default);
      LCurr.SetString(0, Y, 'same row content', TStyle.Default);
    end;
    CheckEqual(0, LPrev.DiffInto(LCurr, LPatches), 'filled identical zero');
  finally
    LPrev.Free; LCurr.Free;
  end;
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.stress');
  T.Test('4K buffer create', @TestLargeBuffer);
  T.Test('4K buffer diff (3 changed rows)', @TestLargeBufferDiff);
  T.Test('4K buffer diff (identical)', @TestLargeBufferIdenticalDiff);
  T.Test('10000 item list render', @TestLargeListRender);
  T.Test('20-col 100-row table render', @TestLargeTableRender);
  T.Test('10KB string render', @TestLongStringRender);
  T.Test('10KB paragraph wrap', @TestParagraphWrapLong);
    T.Test('single cell diff upper bound', @TestSingleCellDiffUpperBound);
  T.Test('diff idempotent same inputs', @TestDiffIdempotentSameInputs);
  T.Test('buffer resize round trip', @TestBufferResizeRoundTrip);
  T.Test('empty list render', @TestEmptyListRender);
  T.Test('fill then identical diff', @TestFillThenIdenticalDiff);
if not T.Run then Halt(1);
end.
