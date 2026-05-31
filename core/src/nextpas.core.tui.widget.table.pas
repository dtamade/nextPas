unit nextpas.core.tui.widget.table;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.text.width,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.layout,
  nextpas.core.tui.widget.block;

type
  TContentAlign = (caLeft, caCenter, caRight);

  TTableColumn = record
    Title: AnsiString;
    Width: TConstraint;
    Align: TContentAlign;

    class function Make(const ATitle: AnsiString; AWidth: TConstraint): TTableColumn; static;
    function WithAlign(A: TContentAlign): TTableColumn;
  end;

  TTableRow = record
    Cells: array of AnsiString;
    Style: TStyle;

    class function Make(const ACells: array of AnsiString): TTableRow; static;
    function WithStyle(const S: TStyle): TTableRow;
  end;

  TTableState = record
    Offset: Integer;
    Selected: Integer;
    HasSelection: Boolean;

    class function Empty: TTableState; static;
    procedure Select(I: Integer);
    procedure ClearSelection;
  end;

  TTable = record
    Columns: array of TTableColumn;
    Rows: array of TTableRow;
    Style: TStyle;
    HeaderStyle: TStyle;
    HighlightStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;
    HasHeader: Boolean;

    class function Create(const ACols: array of TTableColumn): TTable; static;
    function WithRows(const ARows: array of TTableRow): TTable;
    function WithBlock(ABlock: IBlock): TTable;
    function WithStyle(const S: TStyle): TTable;
    function WithHeaderStyle(const S: TStyle): TTable;
    function WithHighlightStyle(const S: TStyle): TTable;
    function WithHeader(Show: Boolean): TTable;
    procedure Render(const Area: TRect; ABuf: TBuffer);
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTableState);
  end;

implementation

{ TTableColumn }

class function TTableColumn.Make(const ATitle: AnsiString; AWidth: TConstraint): TTableColumn;
begin
  Result.Title := ATitle;
  Result.Width := AWidth;
  Result.Align := caLeft;
end;

function TTableColumn.WithAlign(A: TContentAlign): TTableColumn;
begin
  Result := Self;
  Result.Align := A;
end;

{ TTableRow }

class function TTableRow.Make(const ACells: array of AnsiString): TTableRow;
var I: Integer;
begin
  SetLength(Result.Cells, Length(ACells));
  for I := 0 to High(ACells) do
    Result.Cells[I] := ACells[I];
  Result.Style := TStyle.Default;
end;

function TTableRow.WithStyle(const S: TStyle): TTableRow;
begin
  Result := Self;
  Result.Style := S;
end;

{ TTableState }

class function TTableState.Empty: TTableState;
begin
  Result.Offset := 0;
  Result.Selected := 0;
  Result.HasSelection := False;
end;

procedure TTableState.Select(I: Integer);
begin
  HasSelection := True;
  Selected := I;
end;

procedure TTableState.ClearSelection;
begin
  HasSelection := False;
end;

{ TTable }

class function TTable.Create(const ACols: array of TTableColumn): TTable;
var I: Integer;
begin
  SetLength(Result.Columns, Length(ACols));
  for I := 0 to High(ACols) do
    Result.Columns[I] := ACols[I];
  Result.Rows := nil;
  Result.Style := TStyle.Default;
  Result.HeaderStyle := TStyle.Default.WithModifier([mbBold]);
  Result.HighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
  Result.HasHeader := True;
end;

function TTable.WithRows(const ARows: array of TTableRow): TTable;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Rows, Length(ARows));
  for I := 0 to High(ARows) do
    Result.Rows[I] := ARows[I];
end;

function TTable.WithBlock(ABlock: IBlock): TTable;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := ABlock;
end;

function TTable.WithStyle(const S: TStyle): TTable;
begin
  Result := Self;
  Result.Style := S;
end;

function TTable.WithHeaderStyle(const S: TStyle): TTable;
begin
  Result := Self;
  Result.HeaderStyle := S;
end;

function TTable.WithHighlightStyle(const S: TStyle): TTable;
begin
  Result := Self;
  Result.HighlightStyle := S;
end;

function TTable.WithHeader(Show: Boolean): TTable;
begin
  Result := Self;
  Result.HasHeader := Show;
end;

procedure TTable.Render(const Area: TRect; ABuf: TBuffer);
var Dummy: TTableState;
begin
  Dummy := TTableState.Empty;
  RenderStateful(Area, ABuf, Dummy);
end;

procedure AlignedWrite(ABuf: TBuffer; X, Y, ColW: Integer;
  const Text: AnsiString; Align: TContentAlign; const Sty: TStyle);
var TW, Pad: Integer;
begin
  if ColW <= 0 then Exit;
  TW := Integer(StringDisplayWidth(Text));
  if TW > ColW then TW := ColW;
  case Align of
    caLeft:   Pad := 0;
    caCenter: Pad := (ColW - TW) div 2;
    caRight:  Pad := ColW - TW;
  end;
  ABuf.SetStringN(X + Pad, Y, Text, ColW - Pad, Sty);
end;

procedure TTable.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTableState);
var
  Inner: TRect;
  NCols, NRows, MaxRows, Visible: Integer;
  ColWidths: TRectArray;
  Constraints: array of TConstraint;
  I, RowY, RowIdx, FirstVis, LastVis, Sel: Integer;
  HeaderH: Integer;
  Sty: TStyle;
  CellText: AnsiString;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  NCols := System.Length(Columns);
  NRows := System.Length(Rows);
  if NCols = 0 then Exit;

  SetLength(Constraints, NCols);
  for I := 0 to NCols - 1 do
    Constraints[I] := Columns[I].Width;
  ColWidths := HorizontalSplit(TRect.Make(Inner.X, Inner.Y, Inner.Width, 1), Constraints);

  HeaderH := 0;
  if HasHeader then
    HeaderH := 1;

  // Render header row
  if HasHeader and (Inner.Height > 0) then
  begin
    RowY := Inner.Y;
    ABuf.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), HeaderStyle);
    for I := 0 to NCols - 1 do
      AlignedWrite(ABuf, ColWidths[I].X, RowY, ColWidths[I].Width,
        Columns[I].Title, Columns[I].Align, HeaderStyle);
  end;

  // Data area
  MaxRows := Inner.Height - HeaderH;
  if MaxRows <= 0 then Exit;
  if NRows = 0 then Exit;

  // Clamp selection
  if State.HasSelection then
  begin
    if State.Selected < 0 then State.Selected := 0;
    if State.Selected >= NRows then State.Selected := NRows - 1;
  end;

  Visible := MaxRows;
  if Visible > NRows then Visible := NRows;

  FirstVis := State.Offset;
  if FirstVis < 0 then FirstVis := 0;
  if FirstVis > NRows - 1 then FirstVis := NRows - 1;
  LastVis := FirstVis + Visible;
  if LastVis > NRows then
  begin
    LastVis := NRows;
    FirstVis := NRows - Visible;
    if FirstVis < 0 then FirstVis := 0;
  end;

  if State.HasSelection then
  begin
    Sel := State.Selected;
    while Sel >= LastVis do
    begin
      Inc(LastVis);
      if LastVis - FirstVis > Visible then Inc(FirstVis);
    end;
    while Sel < FirstVis do
    begin
      Dec(FirstVis);
      if LastVis - FirstVis > Visible then Dec(LastVis);
    end;
  end;
  State.Offset := FirstVis;

  // Render data rows
  RowIdx := FirstVis;
  RowY := Inner.Y + HeaderH;
  while (RowIdx < LastVis) and (RowY < Inner.Y + Inner.Height) do
  begin
    Sty := Style.Patch(Rows[RowIdx].Style);
    ABuf.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), Sty);

    for I := 0 to NCols - 1 do
    begin
      if I < System.Length(Rows[RowIdx].Cells) then
        CellText := Rows[RowIdx].Cells[I]
      else
        CellText := '';
      AlignedWrite(ABuf, ColWidths[I].X, RowY, ColWidths[I].Width,
        CellText, Columns[I].Align, Sty);
    end;

    if State.HasSelection and (RowIdx = State.Selected) then
      ABuf.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), HighlightStyle);

    Inc(RowIdx);
    Inc(RowY);
  end;
end;

end.
