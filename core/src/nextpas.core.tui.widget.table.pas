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
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

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

  ITable = interface(IWidget)
    ['{F6A7B8C9-D0E1-2345-FABC-678901234567}']
    function WithRows(const ARows: array of TTableRow): ITable;
    function WithBlock(ABlock: IBlock): ITable;
    function WithStyle(const S: TStyle): ITable;
    function WithHeaderStyle(const S: TStyle): ITable;
    function WithHighlightStyle(const S: TStyle): ITable;
    function WithHeader(Show: Boolean): ITable;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTableState);
  end;

  TTable = class(TInterfacedObject, IWidget, ITable)
  private
    FColumns: array of TTableColumn;
    FRows: array of TTableRow;
    FStyle: TStyle;
    FHeaderStyle: TStyle;
    FHighlightStyle: TStyle;
    FBlock: IBlock;
    FHasHeader: Boolean;
  public
    class function New(const ACols: array of TTableColumn): ITable; static;

    function WithRows(const ARows: array of TTableRow): ITable;
    function WithBlock(ABlock: IBlock): ITable;
    function WithStyle(const S: TStyle): ITable;
    function WithHeaderStyle(const S: TStyle): ITable;
    function WithHighlightStyle(const S: TStyle): ITable;
    function WithHeader(Show: Boolean): ITable;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { ITable }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTableState);
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
  Result.Cells := nil;
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

class function TTable.New(const ACols: array of TTableColumn): ITable;
var
  LSelf: TTable;
  I: Integer;
begin
  LSelf := TTable.Create;
  SetLength(LSelf.FColumns, Length(ACols));
  for I := 0 to High(ACols) do
    LSelf.FColumns[I] := ACols[I];
  LSelf.FRows := nil;
  LSelf.FStyle := TStyle.Default;
  LSelf.FHeaderStyle := TStyle.Default.WithModifier([mbBold]);
  LSelf.FHighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FBlock := nil;
  LSelf.FHasHeader := True;
  Result := LSelf;
end;

function TTable.WithRows(const ARows: array of TTableRow): ITable;
var I: Integer;
begin
  SetLength(FRows, Length(ARows));
  for I := 0 to High(ARows) do
    FRows[I] := ARows[I];
  Result := Self;
end;

function TTable.WithBlock(ABlock: IBlock): ITable;
begin
  FBlock := ABlock;
  Result := Self;
end;

function TTable.WithStyle(const S: TStyle): ITable;
begin
  FStyle := S;
  Result := Self;
end;

function TTable.WithHeaderStyle(const S: TStyle): ITable;
begin
  FHeaderStyle := S;
  Result := Self;
end;

function TTable.WithHighlightStyle(const S: TStyle): ITable;
begin
  FHighlightStyle := S;
  Result := Self;
end;

function TTable.WithHeader(Show: Boolean): ITable;
begin
  FHasHeader := Show;
  Result := Self;
end;

procedure TTable.Render(const AArea: TRect; ABuffer: TBuffer);
var Dummy: TTableState;
begin
  Dummy := TTableState.Empty;
  RenderStateful(AArea, ABuffer, Dummy);
end;

procedure AlignedWrite(ABuffer: TBuffer; X, Y, ColW: Integer;
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
  ABuffer.SetStringN(X + Pad, Y, Text, ColW - Pad, Sty);
end;

procedure TTable.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TTableState);
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
  if AArea.IsEmpty then Exit;

  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  NCols := System.Length(FColumns);
  NRows := System.Length(FRows);
  if NCols = 0 then Exit;

  SetLength(Constraints, NCols);
  for I := 0 to NCols - 1 do
    Constraints[I] := FColumns[I].Width;
  ColWidths := HorizontalSplit(TRect.Make(Inner.X, Inner.Y, Inner.Width, 1), Constraints);

  HeaderH := 0;
  if FHasHeader then HeaderH := 1;

  if FHasHeader and (Inner.Height > 0) then
  begin
    RowY := Inner.Y;
    ABuffer.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), FHeaderStyle);
    for I := 0 to NCols - 1 do
      AlignedWrite(ABuffer, ColWidths[I].X, RowY, ColWidths[I].Width,
        FColumns[I].Title, FColumns[I].Align, FHeaderStyle);
  end;

  MaxRows := Inner.Height - HeaderH;
  if MaxRows <= 0 then Exit;
  if NRows = 0 then Exit;

  if AState.HasSelection then
  begin
    if AState.Selected < 0 then AState.Selected := 0;
    if AState.Selected >= NRows then AState.Selected := NRows - 1;
  end;

  Visible := MaxRows;
  if Visible > NRows then Visible := NRows;

  FirstVis := AState.Offset;
  if FirstVis < 0 then FirstVis := 0;
  if FirstVis > NRows - 1 then FirstVis := NRows - 1;
  LastVis := FirstVis + Visible;
  if LastVis > NRows then
  begin
    LastVis := NRows;
    FirstVis := NRows - Visible;
    if FirstVis < 0 then FirstVis := 0;
  end;

  if AState.HasSelection then
  begin
    Sel := AState.Selected;
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
  AState.Offset := FirstVis;

  RowIdx := FirstVis;
  RowY := Inner.Y + HeaderH;
  while (RowIdx < LastVis) and (RowY < Inner.Y + Inner.Height) do
  begin
    Sty := FStyle.Patch(FRows[RowIdx].Style);
    ABuffer.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), Sty);

    for I := 0 to NCols - 1 do
    begin
      if I < System.Length(FRows[RowIdx].Cells) then
        CellText := FRows[RowIdx].Cells[I]
      else
        CellText := '';
      AlignedWrite(ABuffer, ColWidths[I].X, RowY, ColWidths[I].Width,
        CellText, FColumns[I].Align, Sty);
    end;

    if AState.HasSelection and (RowIdx = AState.Selected) then
      ABuffer.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), FHighlightStyle);

    Inc(RowIdx);
    Inc(RowY);
  end;
end;

end.
