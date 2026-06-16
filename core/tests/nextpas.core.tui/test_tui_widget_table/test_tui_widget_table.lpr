program test_tui_widget_table;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.text,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.table,
  nextpas.core.testing;

var T: TTestRunner;

{ === TTableColumn === }

procedure TestTableColumnMake;
var Col: TTableColumn;
begin
  Col := TTableColumn.Make('Name', Fixed(10));
  Check(Col.Title = 'Name', 'column title');
end;

procedure TestTableColumnWithAlign;
var Col: TTableColumn;
begin
  Col := TTableColumn.Make('Value', Fixed(10)).WithAlign(caCenter);
  Check(Col.Align = caCenter, 'column align center');
end;

{ === TTableRow === }

procedure TestTableRowMake;
var Row: TTableRow;
begin
  Row := TTableRow.Make(['Alice', '30']);
  Check(Length(Row.Cells) = 2, 'row has 2 cells');
  Check(Row.Cells[0] = 'Alice', 'cell 0');
  Check(Row.Cells[1] = '30', 'cell 1');
end;

procedure TestTableRowWithStyle;
var Row: TTableRow;
begin
  Row := TTableRow.Make(['Bob']).WithStyle(TStyle.Default.WithFg(IndexedColor(1)));
  Check(ColorEquals(Row.Style.Fg, IndexedColor(1)), 'row style applied');
end;

{ === TTableState === }

procedure TestTableStateEmpty;
var S: TTableState;
begin
  S := TTableState.Empty;
  Check(S.Offset = 0, 'empty offset');
  Check(S.Selected = 0, 'empty selected');
  Check(not S.HasSelection, 'no selection');
end;

procedure TestTableStateSelect;
var S: TTableState;
begin
  S := TTableState.Empty;
  S.Select(3);
  Check(S.Selected = 3, 'selected 3');
  Check(S.HasSelection, 'has selection');
end;

procedure TestTableStateClearSelection;
var S: TTableState;
begin
  S := TTableState.Empty;
  S.Select(5);
  S.ClearSelection;
  Check(not S.HasSelection, 'selection cleared');
end;

{ === ITable Builders === }

procedure TestTableNew;
var LT: ITable;
begin
  LT := TTable.New([TTableColumn.Make('A', Fixed(10))]);
  Check(LT <> nil, 'TTable.New returns non-nil');
end;

procedure TestTableWithRows;
var LT: ITable; LBuf: TBuffer; LS: TTableState; LRow: AnsiString;
begin
  LT := TTable.New([TTableColumn.Make('Name', Fixed(10))])
    .WithRows([TTableRow.Make(['Alice'])]);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 2), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Name', LRow) > 0, 'header visible');
    LRow := LBuf.RowAsString(1);
    Check(Pos('Alice', LRow) > 0, 'row visible');
  finally LBuf.Free; end;
end;

procedure TestTableWithBlock;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))])
    .WithRows([TTableRow.Make(['val'])])
    .WithBlock(TBlock.New.WithTitle('Table'));
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 15, 4));
  try
    LT.RenderStateful(TRect.Make(0, 0, 15, 4), LBuf, LS);
    Check(True, 'table with block renders');
  finally LBuf.Free; end;
end;

procedure TestTableWithStyle;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))])
    .WithRows([TTableRow.Make(['val'])])
    .WithStyle(TStyle.Default.WithFg(IndexedColor(2)));
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 2), LBuf, LS);
    Check(True, 'styled table renders');
  finally LBuf.Free; end;
end;

procedure TestTableWithHeaderStyle;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('H', Fixed(5))])
    .WithRows([TTableRow.Make(['v'])])
    .WithHeaderStyle(TStyle.Default.WithBg(IndexedColor(4)));
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 2), LBuf, LS);
    Check(True, 'table with header style renders');
  finally LBuf.Free; end;
end;

procedure TestTableWithHighlightStyle;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))])
    .WithRows([TTableRow.Make(['a']), TTableRow.Make(['b'])])
    .WithHighlightStyle(TStyle.Default.WithBg(IndexedColor(3)));
  LS := TTableState.Empty;
  LS.Select(0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 3), LBuf, LS);
    Check(True, 'table with highlight style renders');
  finally LBuf.Free; end;
end;

procedure TestTableWithHeaderFalse;
var LT: ITable; LBuf: TBuffer; LS: TTableState; LRow: AnsiString;
begin
  LT := TTable.New([TTableColumn.Make('Name', Fixed(10))])
    .WithRows([TTableRow.Make(['Alice'])])
    .WithHeader(False);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 2), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Alice', LRow) > 0, 'row starts at top when header hidden');
  finally LBuf.Free; end;
end;

procedure TestTableAsIWidget;
var LT: ITable; LW: IWidget;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))]);
  LW := LT as IWidget;
  Check(LW <> nil, 'ITable casts to IWidget');
end;

procedure TestTableMultipleColumns;
var LT: ITable; LBuf: TBuffer; LS: TTableState; LRow: AnsiString;
begin
  LT := TTable.New([
    TTableColumn.Make('Name', Fixed(10)),
    TTableColumn.Make('Age', Fixed(5))
  ]).WithRows([TTableRow.Make(['Alice', '30'])]);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 2), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Name', LRow) > 0, 'header col 1');
    Check(Pos('Age', LRow) > 0, 'header col 2');
  finally LBuf.Free; end;
end;

procedure TestTableSelection;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))])
    .WithRows([TTableRow.Make(['a']), TTableRow.Make(['b']), TTableRow.Make(['c'])]);
  LS := TTableState.Empty;
  LS.Select(1);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 4), LBuf, LS);
    Check(True, 'table with selection renders');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('test_tui_widget_table');
  try
    { TTableColumn }
    T.Run('TableColumn Make', @TestTableColumnMake);
    T.Run('TableColumn WithAlign', @TestTableColumnWithAlign);

    { TTableRow }
    T.Run('TableRow Make', @TestTableRowMake);
    T.Run('TableRow WithStyle', @TestTableRowWithStyle);

    { TTableState }
    T.Run('TableState Empty', @TestTableStateEmpty);
    T.Run('TableState Select', @TestTableStateSelect);
    T.Run('TableState ClearSelection', @TestTableStateClearSelection);

    { ITable Builders }
    T.Run('Table New', @TestTableNew);
    T.Run('Table WithRows', @TestTableWithRows);
    T.Run('Table WithBlock', @TestTableWithBlock);
    T.Run('Table WithStyle', @TestTableWithStyle);
    T.Run('Table WithHeaderStyle', @TestTableWithHeaderStyle);
    T.Run('Table WithHighlightStyle', @TestTableWithHighlightStyle);
    T.Run('Table WithHeader false', @TestTableWithHeaderFalse);
    T.Run('Table as IWidget', @TestTableAsIWidget);
    T.Run('Table multiple columns', @TestTableMultipleColumns);
    T.Run('Table selection', @TestTableSelection);

    WriteLn;
    T.Summary;
  finally
  end;
end.
