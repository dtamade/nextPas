program test_tui_widget_table;
{$I nextpas.core.settings.inc}
uses
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
  nextpas.core.test;

var T: TTestSuite;

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

procedure TestTableRenderEmpty;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))]);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 2), LBuf, LS);
    Check(True, 'empty table renders');
  finally LBuf.Free; end;
end;

procedure TestTableRenderSmallArea;
var LT: ITable; LBuf: TBuffer; LS: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', Fixed(5))])
    .WithRows([TTableRow.Make(['a'])]);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 3, 1), LBuf, LS);
    Check(True, 'table renders in small area');
  finally LBuf.Free; end;
end;

procedure TestTableMultipleRows;
var LT: ITable; LBuf: TBuffer; LS: TTableState; LRow: AnsiString;
begin
  LT := TTable.New([TTableColumn.Make('Name', Fixed(10))])
    .WithRows([
      TTableRow.Make(['Alice']),
      TTableRow.Make(['Bob']),
      TTableRow.Make(['Charlie'])
    ]);
  LS := TTableState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 5), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Name', LRow) > 0, 'header visible');
    LRow := LBuf.RowAsString(1);
    Check(Pos('Alice', LRow) > 0, 'Alice visible');
  finally LBuf.Free; end;
end;

procedure TestTableStateSelectBoundary;
var S: TTableState;
begin
  S := TTableState.Empty;
  S.Select(0);
  Check(S.Selected = 0, 'select first');
  S.ClearSelection;
  Check(not S.HasSelection, 'clear after select');
end;

{ PH33 P3：数据更新面——AddRow 逐行追加（无需整表重建） }
procedure TestTableAddRow;
var LT: ITable; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LT := TTable.New([TTableColumn.Make('A', Fixed(12)),
    TTableColumn.Make('B', Fixed(12))]);
  LT.AddRow(TTableRow.Make(['r1c1', 'r1c2']));
  LT.AddRow(TTableRow.Make(['added-row-x', 'added-row-y']));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 26, 4));
  try
    LT.Render(TRect.Make(0, 0, 26, 4), LBuf);
    LAll := '';
    for I := 0 to 3 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('r1c2', LAll) > 0, 'first added row visible');
    Check(Pos('added-row-y', LAll) > 0, 'second added row visible');
  finally LBuf.Free; end;
end;

begin
  T := TTestSuite.Create('test_tui_widget_table');
  try
    { TTableColumn }
    T.Test('TableColumn Make', @TestTableColumnMake);
    T.Test('TableColumn WithAlign', @TestTableColumnWithAlign);

    { TTableRow }
    T.Test('TableRow Make', @TestTableRowMake);
    T.Test('TableRow WithStyle', @TestTableRowWithStyle);

    { TTableState }
    T.Test('TableState Empty', @TestTableStateEmpty);
    T.Test('TableState Select', @TestTableStateSelect);
    T.Test('TableState ClearSelection', @TestTableStateClearSelection);

    { ITable Builders }
    T.Test('Table New', @TestTableNew);
    T.Test('Table WithRows', @TestTableWithRows);
    T.Test('Table WithBlock', @TestTableWithBlock);
    T.Test('Table WithStyle', @TestTableWithStyle);
    T.Test('Table WithHeaderStyle', @TestTableWithHeaderStyle);
    T.Test('Table WithHighlightStyle', @TestTableWithHighlightStyle);
    T.Test('Table WithHeader false', @TestTableWithHeaderFalse);
    T.Test('Table as IWidget', @TestTableAsIWidget);
    T.Test('Table multiple columns', @TestTableMultipleColumns);
    T.Test('Table selection', @TestTableSelection);
    T.Test('Table render empty', @TestTableRenderEmpty);
    T.Test('Table render small area', @TestTableRenderSmallArea);
    T.Test('Table multiple rows', @TestTableMultipleRows);
    T.Test('TableState select boundary', @TestTableStateSelectBoundary);
    T.Test('AddRow append (PH33 P3)', @TestTableAddRow);

    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
