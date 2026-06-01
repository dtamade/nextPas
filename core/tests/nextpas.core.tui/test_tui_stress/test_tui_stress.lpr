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
  nextpas.core.testing;
var T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.tui.stress');
  T.Run('4K buffer create', @TestLargeBuffer);
  T.Run('4K buffer diff (3 changed rows)', @TestLargeBufferDiff);
  T.Run('4K buffer diff (identical)', @TestLargeBufferIdenticalDiff);
  T.Run('10000 item list render', @TestLargeListRender);
  T.Run('20-col 100-row table render', @TestLargeTableRender);
  T.Run('10KB string render', @TestLongStringRender);
  T.Run('10KB paragraph wrap', @TestParagraphWrapLong);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
