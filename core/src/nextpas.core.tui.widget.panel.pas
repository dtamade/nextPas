unit nextpas.core.tui.widget.panel;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 1}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.widget.intf;

const
  PANEL_MAX_COLS = 8;
  PANEL_MAX_ROWS = 8;
  PANEL_MAX_CELLS = PANEL_MAX_COLS * PANEL_MAX_ROWS;
  PANEL_MAX_HSEP = PANEL_MAX_ROWS - 1;
  PANEL_MAX_VSEP = PANEL_MAX_COLS - 1;

type
  TPanelEdge = (peTop, peBottom, peLeft, peRight, peInnerH, peInnerV);
  TPanelEdges = set of TPanelEdge;

const
  PanelEdgesAll: TPanelEdges = [peTop, peBottom, peLeft, peRight, peInnerH, peInnerV];
  PanelEdgesOuter: TPanelEdges = [peTop, peBottom, peLeft, peRight];
  PanelEdgesInner: TPanelEdges = [peInnerH, peInnerV];
  PanelEdgesNone: TPanelEdges = [];

type
  TSepTitle = record
    Text: AnsiString;
    Style: TStyle;
    HasTitle: Boolean;
    HasStyle: Boolean;
  end;

  TPanelGrid = record
    ColCount: Integer;
    RowCount: Integer;
    Cells: array[0..PANEL_MAX_CELLS - 1] of TRect;
    ColOffsets: array[0..PANEL_MAX_COLS] of Integer;
    RowOffsets: array[0..PANEL_MAX_ROWS] of Integer;
  end;

  TSepHit = record
    Found: Boolean;
    IsHorizontal: Boolean;
    SepIndex: Integer;
  end;

  IPanel = interface(IWidget)
    ['{A0B1C2D3-E4F5-6789-ABCD-E0F1A2B3C4D5}']
    function WithBorderSet(const BS: TBorderSet): IPanel;
    function WithSepSet(const BS: TBorderSet): IPanel;
    function WithEdges(E: TPanelEdges): IPanel;
    function WithBorderStyle(const S: TStyle): IPanel;
    function WithHSepStartCol(Col: Integer): IPanel;
    function WithHSepStartColAt(SepIndex: Integer; Col: Integer): IPanel;
    function WithVSepStartRow(Row: Integer): IPanel;
    function WithVSepEndRow(Row: Integer): IPanel;
    function WithHSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
    function WithVSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
    function WithHSepTitle(SepIndex: Integer; const ATitle: AnsiString): IPanel;
    function WithHSepTitleStyle(SepIndex: Integer; const ATitle: AnsiString; const S: TStyle): IPanel;
    function WithFocus(Col, Row: Integer): IPanel;
    function WithFocusStyle(const S: TStyle): IPanel;
    function WithPadding(P: Byte): IPanel;
    function WithCellPadding(Col, Row: Integer; P: Byte): IPanel;
    function WithMinWidth(Col: Integer; Min: Integer): IPanel;
    function WithMinHeight(Row: Integer; Min: Integer): IPanel;
    function WithColWeight(Col: Integer; Weight: Word): IPanel;
    function WithRowWeight(Row: Integer; Weight: Word): IPanel;
    function WithDebug(Enable: Boolean): IPanel;
    function Layout(const AArea: TRect): TPanelGrid;
    function RenderGrid(const AArea: TRect; ABuffer: TBuffer): TPanelGrid;
  end;

  TPanel = class(TInterfacedObject, IWidget, IPanel)
  private
    FCols: array[0..PANEL_MAX_COLS - 1] of TConstraint;
    FRows: array[0..PANEL_MAX_ROWS - 1] of TConstraint;
    FColCount: Integer;
    FRowCount: Integer;
    FBorderSet: TBorderSet;
    FSepSet: TBorderSet;
    FHasSepSet: Boolean;
    FEdges: TPanelEdges;
    FBorderStyle: TStyle;
    FHSepStartCol: array[0..PANEL_MAX_HSEP - 1] of Integer;
    FVSepStartRow: Integer;
    FVSepEndRow: Integer;
    FHSepVisible: array[0..PANEL_MAX_HSEP - 1] of Boolean;
    FVSepVisible: array[0..PANEL_MAX_VSEP - 1] of Boolean;
    FHSepTitles: array[0..PANEL_MAX_HSEP - 1] of TSepTitle;
    FFocusCol: Integer;
    FFocusRow: Integer;
    FHasFocus: Boolean;
    FFocusStyle: TStyle;
    FPadding: Byte;
    FCellPadding: array[0..PANEL_MAX_CELLS - 1] of Byte;
    FHasCellPadding: Boolean;
    FMinWidths: array[0..PANEL_MAX_COLS - 1] of Integer;
    FMinHeights: array[0..PANEL_MAX_ROWS - 1] of Integer;
    FDebug: Boolean;
  public
    class function New(
      const Cols: array of TConstraint;
      const Rows: array of TConstraint): IPanel; static;
    class function Sidebar(SidebarWidth: Integer): IPanel; static;
    class function HSplit(TopHeight: Integer): IPanel; static;
    class function Grid(ACols, ARows: Integer): IPanel; static;

    function WithBorderSet(const BS: TBorderSet): IPanel;
    function WithSepSet(const BS: TBorderSet): IPanel;
    function WithEdges(E: TPanelEdges): IPanel;
    function WithBorderStyle(const S: TStyle): IPanel;
    function WithHSepStartCol(Col: Integer): IPanel;
    function WithHSepStartColAt(SepIndex: Integer; Col: Integer): IPanel;
    function WithVSepStartRow(Row: Integer): IPanel;
    function WithVSepEndRow(Row: Integer): IPanel;
    function WithHSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
    function WithVSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
    function WithHSepTitle(SepIndex: Integer; const ATitle: AnsiString): IPanel;
    function WithHSepTitleStyle(SepIndex: Integer; const ATitle: AnsiString; const S: TStyle): IPanel;
    function WithFocus(Col, Row: Integer): IPanel;
    function WithFocusStyle(const S: TStyle): IPanel;
    function WithPadding(P: Byte): IPanel;
    function WithCellPadding(Col, Row: Integer; P: Byte): IPanel;
    function WithMinWidth(Col: Integer; Min: Integer): IPanel;
    function WithMinHeight(Row: Integer; Min: Integer): IPanel;
    function WithColWeight(Col: Integer; Weight: Word): IPanel;
    function WithRowWeight(Row: Integer; Weight: Word): IPanel;
    function WithDebug(Enable: Boolean): IPanel;
    function Layout(const AArea: TRect): TPanelGrid;
    function RenderGrid(const AArea: TRect; ABuffer: TBuffer): TPanelGrid;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

function PanelCell(const Grid: TPanelGrid; Col, Row: Integer): TRect; inline;
function PanelCellPadded(const Panel: TPanel; const Grid: TPanelGrid; Col, Row: Integer): TRect;
function PanelCellSpan(const Grid: TPanelGrid; Col, Row, ColSpan, RowSpan: Integer): TRect;
function PanelHitTestSep(const Grid: TPanelGrid; X, Y: Integer): TSepHit;

implementation

function PanelCell(const Grid: TPanelGrid; Col, Row: Integer): TRect; inline;
begin
  Result := Grid.Cells[Row * Grid.ColCount + Col];
end;

function PanelCellSpan(const Grid: TPanelGrid; Col, Row, ColSpan, RowSpan: Integer): TRect;
var
  First, Last: TRect;
begin
  First := Grid.Cells[Row * Grid.ColCount + Col];
  Last := Grid.Cells[(Row + RowSpan - 1) * Grid.ColCount + (Col + ColSpan - 1)];
  Result := TRect.Make(First.X, First.Y,
    (Last.X + Last.Width) - First.X,
    (Last.Y + Last.Height) - First.Y);
end;

function PanelCellPadded(const Panel: TPanel; const Grid: TPanelGrid; Col, Row: Integer): TRect;
var
  R: TRect;
  P: Integer;
begin
  R := Grid.Cells[Row * Grid.ColCount + Col];
  P := Panel.FPadding;
  if Panel.FHasCellPadding and (Panel.FCellPadding[Row * PANEL_MAX_COLS + Col] > 0) then
    P := Panel.FCellPadding[Row * PANEL_MAX_COLS + Col];
  if P > 0 then
  begin
    if (Integer(R.Width) > P * 2) and (Integer(R.Height) > P * 2) then
      Result := TRect.Make(R.X + P, R.Y + P, R.Width - P * 2, R.Height - P * 2)
    else
      Result := TRect.Make(R.X, R.Y, 0, 0);
  end
  else
    Result := R;
end;

function PanelHitTestSep(const Grid: TPanelGrid; X, Y: Integer): TSepHit;
var
  I: Integer;
begin
  Result.Found := False;
  Result.IsHorizontal := False;
  Result.SepIndex := -1;
  for I := 1 to Grid.ColCount - 1 do
    if X = Grid.ColOffsets[I] - 1 then
    begin
      Result.Found := True;
      Result.IsHorizontal := False;
      Result.SepIndex := I - 1;
      Exit;
    end;
  for I := 1 to Grid.RowCount - 1 do
    if Y = Grid.RowOffsets[I] - 1 then
    begin
      Result.Found := True;
      Result.IsHorizontal := True;
      Result.SepIndex := I - 1;
      Exit;
    end;
end;

{ TPanel }

class function TPanel.New(
  const Cols: array of TConstraint;
  const Rows: array of TConstraint): IPanel;
var
  LSelf: TPanel;
  I: Integer;
begin
  LSelf := TPanel.Create;
  LSelf.FColCount := Length(Cols);
  if LSelf.FColCount > PANEL_MAX_COLS then LSelf.FColCount := PANEL_MAX_COLS;
  for I := 0 to LSelf.FColCount - 1 do
    LSelf.FCols[I] := Cols[I];

  LSelf.FRowCount := Length(Rows);
  if LSelf.FRowCount > PANEL_MAX_ROWS then LSelf.FRowCount := PANEL_MAX_ROWS;
  for I := 0 to LSelf.FRowCount - 1 do
    LSelf.FRows[I] := Rows[I];

  LSelf.FBorderSet := BorderSetPlain;
  LSelf.FHasSepSet := False;
  LSelf.FEdges := PanelEdgesAll;
  LSelf.FBorderStyle := TStyle.Default;
  LSelf.FVSepStartRow := 0;
  LSelf.FVSepEndRow := PANEL_MAX_ROWS;
  LSelf.FHasFocus := False;
  LSelf.FFocusCol := 0;
  LSelf.FFocusRow := 0;
  LSelf.FFocusStyle := TStyle.Default.WithFg(TUI_WHITE).WithModifier([mbBold]);
  LSelf.FPadding := 0;
  LSelf.FHasCellPadding := False;
  LSelf.FDebug := False;
  for I := 0 to PANEL_MAX_HSEP - 1 do
  begin
    LSelf.FHSepVisible[I] := True;
    LSelf.FHSepTitles[I].HasTitle := False;
    LSelf.FHSepStartCol[I] := 0;
  end;
  for I := 0 to PANEL_MAX_VSEP - 1 do
    LSelf.FVSepVisible[I] := True;
  for I := 0 to PANEL_MAX_COLS - 1 do
    LSelf.FMinWidths[I] := 0;
  for I := 0 to PANEL_MAX_ROWS - 1 do
    LSelf.FMinHeights[I] := 0;
  for I := 0 to PANEL_MAX_CELLS - 1 do
    LSelf.FCellPadding[I] := 0;
  Result := LSelf;
end;

function TPanel.WithBorderSet(const BS: TBorderSet): IPanel;
begin FBorderSet := BS; Result := Self; end;

function TPanel.WithSepSet(const BS: TBorderSet): IPanel;
begin FSepSet := BS; FHasSepSet := True; Result := Self; end;

function TPanel.WithEdges(E: TPanelEdges): IPanel;
begin FEdges := E; Result := Self; end;

function TPanel.WithBorderStyle(const S: TStyle): IPanel;
begin FBorderStyle := S; Result := Self; end;

function TPanel.WithHSepStartCol(Col: Integer): IPanel;
var I: Integer;
begin
  if Col < 0 then Col := 0;
  if Col >= FColCount then Col := FColCount - 1;
  for I := 0 to PANEL_MAX_HSEP - 1 do
    FHSepStartCol[I] := Col;
  Result := Self;
end;

function TPanel.WithHSepStartColAt(SepIndex: Integer; Col: Integer): IPanel;
begin
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    if Col < 0 then Col := 0;
    if Col >= FColCount then Col := FColCount - 1;
    FHSepStartCol[SepIndex] := Col;
  end;
  Result := Self;
end;

function TPanel.WithVSepStartRow(Row: Integer): IPanel;
begin
  if Row < 0 then Row := 0;
  if Row >= FRowCount then Row := FRowCount - 1;
  FVSepStartRow := Row;
  Result := Self;
end;

function TPanel.WithVSepEndRow(Row: Integer): IPanel;
begin
  if Row < 1 then Row := 1;
  if Row > FRowCount then Row := FRowCount;
  FVSepEndRow := Row;
  Result := Self;
end;

function TPanel.WithHSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
begin
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
    FHSepVisible[SepIndex] := Visible;
  Result := Self;
end;

function TPanel.WithVSepVisible(SepIndex: Integer; Visible: Boolean): IPanel;
begin
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_VSEP) then
    FVSepVisible[SepIndex] := Visible;
  Result := Self;
end;

function TPanel.WithHSepTitle(SepIndex: Integer; const ATitle: AnsiString): IPanel;
begin
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    FHSepTitles[SepIndex].Text := ATitle;
    FHSepTitles[SepIndex].HasTitle := True;
    FHSepTitles[SepIndex].HasStyle := False;
  end;
  Result := Self;
end;

function TPanel.WithHSepTitleStyle(SepIndex: Integer; const ATitle: AnsiString; const S: TStyle): IPanel;
begin
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    FHSepTitles[SepIndex].Text := ATitle;
    FHSepTitles[SepIndex].Style := S;
    FHSepTitles[SepIndex].HasTitle := True;
    FHSepTitles[SepIndex].HasStyle := True;
  end;
  Result := Self;
end;

function TPanel.WithFocus(Col, Row: Integer): IPanel;
begin
  FHasFocus := True;
  FFocusCol := Col;
  FFocusRow := Row;
  Result := Self;
end;

function TPanel.WithFocusStyle(const S: TStyle): IPanel;
begin FFocusStyle := S; Result := Self; end;

function TPanel.WithPadding(P: Byte): IPanel;
begin FPadding := P; Result := Self; end;

function TPanel.WithCellPadding(Col, Row: Integer; P: Byte): IPanel;
begin
  if (Col >= 0) and (Col < PANEL_MAX_COLS) and (Row >= 0) and (Row < PANEL_MAX_ROWS) then
  begin
    FCellPadding[Row * PANEL_MAX_COLS + Col] := P;
    FHasCellPadding := True;
  end;
  Result := Self;
end;

function TPanel.WithMinWidth(Col: Integer; Min: Integer): IPanel;
begin
  if (Col >= 0) and (Col < PANEL_MAX_COLS) then
    FMinWidths[Col] := Min;
  Result := Self;
end;

function TPanel.WithMinHeight(Row: Integer; Min: Integer): IPanel;
begin
  if (Row >= 0) and (Row < PANEL_MAX_ROWS) then
    FMinHeights[Row] := Min;
  Result := Self;
end;

function TPanel.WithColWeight(Col: Integer; Weight: Word): IPanel;
begin
  if (Col >= 0) and (Col < FColCount) then
    FCols[Col] := FillConstraint(Weight);
  Result := Self;
end;

function TPanel.WithRowWeight(Row: Integer; Weight: Word): IPanel;
begin
  if (Row >= 0) and (Row < FRowCount) then
    FRows[Row] := FillConstraint(Weight);
  Result := Self;
end;

function TPanel.WithDebug(Enable: Boolean): IPanel;
begin FDebug := Enable; Result := Self; end;

class function TPanel.Sidebar(SidebarWidth: Integer): IPanel;
begin
  Result := TPanel.New(
    [LengthConstraint(SidebarWidth), MinConstraint(0)],
    [MinConstraint(0)]);
end;

class function TPanel.HSplit(TopHeight: Integer): IPanel;
begin
  Result := TPanel.New(
    [MinConstraint(0)],
    [LengthConstraint(TopHeight), MinConstraint(0)]);
end;

class function TPanel.Grid(ACols, ARows: Integer): IPanel;
var
  Cs: array[0..PANEL_MAX_COLS - 1] of TConstraint;
  Rs: array[0..PANEL_MAX_ROWS - 1] of TConstraint;
  I: Integer;
begin
  if ACols > PANEL_MAX_COLS then ACols := PANEL_MAX_COLS;
  if ARows > PANEL_MAX_ROWS then ARows := PANEL_MAX_ROWS;
  for I := 0 to ACols - 1 do Cs[I] := MinConstraint(0);
  for I := 0 to ARows - 1 do Rs[I] := MinConstraint(0);
  Result := TPanel.New(Slice(Cs, ACols), Slice(Rs, ARows));
end;

function TPanel.Layout(const AArea: TRect): TPanelGrid;
var
  ColSizes, RowSizes: TIntArray;
  InnerW, InnerH: Integer;
  BorderL, BorderR, BorderT, BorderB: Integer;
  InnerVCount, InnerHCount: Integer;
  I, Cursor: Integer;
  Col, Row: Integer;
begin
  Result.ColCount := FColCount;
  Result.RowCount := FRowCount;

  if (FColCount = 0) or (FRowCount = 0) or AArea.IsEmpty then Exit;

  BorderL := Ord(peLeft in FEdges);
  BorderR := Ord(peRight in FEdges);
  BorderT := Ord(peTop in FEdges);
  BorderB := Ord(peBottom in FEdges);
  if peInnerV in FEdges then InnerVCount := FColCount - 1 else InnerVCount := 0;
  if peInnerH in FEdges then InnerHCount := FRowCount - 1 else InnerHCount := 0;

  InnerW := Integer(AArea.Width) - BorderL - BorderR - InnerVCount;
  InnerH := Integer(AArea.Height) - BorderT - BorderB - InnerHCount;
  if InnerW < 0 then InnerW := 0;
  if InnerH < 0 then InnerH := 0;

  ColSizes := ComputeSlotSizes(InnerW, Slice(FCols, FColCount));
  RowSizes := ComputeSlotSizes(InnerH, Slice(FRows, FRowCount));

  // Enforce minimum sizes, then clamp total to available space
  for I := 0 to FColCount - 1 do
    if (FMinWidths[I] > 0) and (ColSizes[I] < FMinWidths[I]) then
      ColSizes[I] := FMinWidths[I];
  for I := 0 to FRowCount - 1 do
    if (FMinHeights[I] > 0) and (RowSizes[I] < FMinHeights[I]) then
      RowSizes[I] := FMinHeights[I];

  // Clamp: if total col sizes exceed InnerW, shrink last column that can absorb
  Cursor := 0;
  for I := 0 to FColCount - 1 do Inc(Cursor, ColSizes[I]);
  if Cursor > InnerW then
  begin
    for I := FColCount - 1 downto 0 do
    begin
      if ColSizes[I] > (Cursor - InnerW) then
      begin
        Dec(ColSizes[I], Cursor - InnerW);
        Break;
      end
      else
      begin
        Dec(Cursor, ColSizes[I]);
        ColSizes[I] := 0;
      end;
    end;
  end;
  Cursor := 0;
  for I := 0 to FRowCount - 1 do Inc(Cursor, RowSizes[I]);
  if Cursor > InnerH then
  begin
    for I := FRowCount - 1 downto 0 do
    begin
      if RowSizes[I] > (Cursor - InnerH) then
      begin
        Dec(RowSizes[I], Cursor - InnerH);
        Break;
      end
      else
      begin
        Dec(Cursor, RowSizes[I]);
        RowSizes[I] := 0;
      end;
    end;
  end;

  Cursor := Integer(AArea.X) + BorderL;
  for I := 0 to FColCount - 1 do
  begin
    Result.ColOffsets[I] := Cursor;
    Inc(Cursor, ColSizes[I]);
    if (I < FColCount - 1) and (peInnerV in FEdges) then
      Inc(Cursor);
  end;
  Result.ColOffsets[FColCount] := Cursor;

  Cursor := Integer(AArea.Y) + BorderT;
  for I := 0 to FRowCount - 1 do
  begin
    Result.RowOffsets[I] := Cursor;
    Inc(Cursor, RowSizes[I]);
    if (I < FRowCount - 1) and (peInnerH in FEdges) then
      Inc(Cursor);
  end;
  Result.RowOffsets[FRowCount] := Cursor;

  for Row := 0 to FRowCount - 1 do
    for Col := 0 to FColCount - 1 do
      Result.Cells[Row * FColCount + Col] := TRect.Make(
        Result.ColOffsets[Col],
        Result.RowOffsets[Row],
        ColSizes[Col],
        RowSizes[Row]);
end;

procedure TPanel.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  RenderGrid(AArea, ABuffer);
end;

function TPanel.RenderGrid(const AArea: TRect; ABuffer: TBuffer): TPanelGrid;
var
  G: TPanelGrid;
  BS, SS: TBorderSet;
  Edges: TPanelEdges;
  Sty: TStyle;
  Left_, Right_, Top_, Bottom_: Integer;
  X, Y, I, J, SepX, SepY, HStart, VStart: Integer;
  HasUp, HasDown, HasLeft_, HasRight_: Boolean;
  JBits: Integer;
  Glyph: AnsiString;
  HSepActive, VSepActive: Boolean;
  TitleLen, TitleX: Integer;
begin
  G := Layout(AArea);
  if (G.ColCount = 0) or (G.RowCount = 0) or AArea.IsEmpty then
  begin
    Result := G;
    Exit;
  end;

  BS := FBorderSet;
  if FHasSepSet then SS := FSepSet else SS := BS;
  Edges := FEdges;
  Sty := FBorderStyle;
  Left_ := AArea.X;
  Top_ := AArea.Y;
  Right_ := Integer(AArea.X) + Integer(AArea.Width) - 1;
  Bottom_ := Integer(AArea.Y) + Integer(AArea.Height) - 1;

  // Draw outer horizontal edges
  if peTop in Edges then
    for X := Left_ + 1 to Right_ - 1 do
      ABuffer.SetStringN(X, Top_, BS.Horizontal, 1, Sty);
  if peBottom in Edges then
    for X := Left_ + 1 to Right_ - 1 do
      ABuffer.SetStringN(X, Bottom_, BS.Horizontal, 1, Sty);

  // Draw inner horizontal separators
  if peInnerH in Edges then
    for J := 1 to G.RowCount - 1 do
    begin
      if not FHSepVisible[J - 1] then Continue;
      SepY := G.RowOffsets[J] - 1;
      if FHSepStartCol[J - 1] > 0 then
        HStart := G.ColOffsets[FHSepStartCol[J - 1]] - 1
      else
        HStart := Left_ + Ord(peLeft in Edges);
      for X := HStart to Right_ - Ord(peRight in Edges) do
        ABuffer.SetStringN(X, SepY, SS.Horizontal, 1, Sty);
      // Draw title on separator
      if FHSepTitles[J - 1].HasTitle then
      begin
        TitleLen := Length(FHSepTitles[J - 1].Text);
        TitleX := HStart + 2;
        if TitleX + TitleLen < Right_ then
        begin
          if FHSepTitles[J - 1].HasStyle then
            ABuffer.SetStringN(TitleX, SepY, FHSepTitles[J - 1].Text, TitleLen, FHSepTitles[J - 1].Style)
          else
            ABuffer.SetStringN(TitleX, SepY, FHSepTitles[J - 1].Text, TitleLen, Sty);
        end;
      end;
    end;

  // Draw outer vertical edges
  if peLeft in Edges then
    for Y := Top_ + 1 to Bottom_ - 1 do
      ABuffer.SetStringN(Left_, Y, BS.Vertical, 1, Sty);
  if peRight in Edges then
    for Y := Top_ + 1 to Bottom_ - 1 do
      ABuffer.SetStringN(Right_, Y, BS.Vertical, 1, Sty);

  // Draw inner vertical separators
  if peInnerV in Edges then
    for I := 1 to G.ColCount - 1 do
    begin
      if not FVSepVisible[I - 1] then Continue;
      SepX := G.ColOffsets[I] - 1;
      if FVSepStartRow > 0 then
        VStart := G.RowOffsets[FVSepStartRow] - 1
      else
        VStart := Top_ + Ord(peTop in Edges);
      if FVSepEndRow < FRowCount then
        SepY := G.RowOffsets[FVSepEndRow] - 1
      else
        SepY := Bottom_ - Ord(peBottom in Edges);
      for Y := VStart to SepY do
        ABuffer.SetStringN(SepX, Y, SS.Vertical, 1, Sty);
    end;

  // Draw junctions
  for J := 0 to G.RowCount do
    for I := 0 to G.ColCount do
    begin
      if I = 0 then
      begin
        if not (peLeft in Edges) then Continue;
        X := Left_;
      end
      else if I = G.ColCount then
      begin
        if not (peRight in Edges) then Continue;
        X := Right_;
      end
      else
      begin
        if not (peInnerV in Edges) then Continue;
        if not FVSepVisible[I - 1] then Continue;
        X := G.ColOffsets[I] - 1;
      end;

      if J = 0 then
      begin
        if not (peTop in Edges) then Continue;
        Y := Top_;
      end
      else if J = G.RowCount then
      begin
        if not (peBottom in Edges) then Continue;
        Y := Bottom_;
      end
      else
      begin
        if not (peInnerH in Edges) then Continue;
        if not FHSepVisible[J - 1] then Continue;
        Y := G.RowOffsets[J] - 1;
      end;

      // VSep active at this row?
      if (I > 0) and (I < G.ColCount) then
        VSepActive := FVSepVisible[I - 1] and (J >= FVSepStartRow) and (J <= FVSepEndRow)
      else
        VSepActive := True;

      // HSep active at this col?
      if (J > 0) and (J < G.RowCount) then
        HSepActive := FHSepVisible[J - 1] and (I >= FHSepStartCol[J - 1])
      else
        HSepActive := True;

      HasUp := (J > 0) and (
        ((I = 0) and (peLeft in Edges)) or
        ((I = G.ColCount) and (peRight in Edges)) or
        ((I > 0) and (I < G.ColCount) and VSepActive and (J > FVSepStartRow)));
      HasDown := (J < G.RowCount) and (
        ((I = 0) and (peLeft in Edges)) or
        ((I = G.ColCount) and (peRight in Edges)) or
        ((I > 0) and (I < G.ColCount) and VSepActive and (J >= FVSepStartRow) and (J < FVSepEndRow)));
      HasLeft_ := (I > 0) and (
        ((J = 0) and (peTop in Edges)) or
        ((J = G.RowCount) and (peBottom in Edges)) or
        ((J > 0) and (J < G.RowCount) and HSepActive and (I > FHSepStartCol[J - 1])));
      HasRight_ := (I < G.ColCount) and (
        ((J = 0) and (peTop in Edges)) or
        ((J = G.RowCount) and (peBottom in Edges)) or
        ((J > 0) and (J < G.RowCount) and HSepActive and (I >= FHSepStartCol[J - 1])));

      JBits := (Ord(HasUp) shl 3) or (Ord(HasDown) shl 2) or
               (Ord(HasLeft_) shl 1) or Ord(HasRight_);

      case JBits of
        $F: Glyph := SS.Cross;
        $E: Glyph := SS.RightT;
        $D: Glyph := SS.LeftT;
        $B: Glyph := SS.BottomT;
        $7: Glyph := SS.TopT;
        $C: Glyph := SS.Vertical;
        $3: Glyph := SS.Horizontal;
        $5: if (I = 0) and (J = 0) then Glyph := BS.TopLeft else Glyph := SS.TopLeft;
        $6: if (I = G.ColCount) and (J = 0) then Glyph := BS.TopRight else Glyph := SS.TopRight;
        $9: if (I = 0) and (J = G.RowCount) then Glyph := BS.BottomLeft else Glyph := SS.BottomLeft;
        $A: if (I = G.ColCount) and (J = G.RowCount) then Glyph := BS.BottomRight else Glyph := SS.BottomRight;
      else
        Continue;
      end;

      // Outer frame junctions use BS, T-junctions on outer edge use BS
      if (I = 0) or (I = G.ColCount) or (J = 0) or (J = G.RowCount) then
        if not FHasSepSet then
          { same set, no override needed }
        else case JBits of
          $B, $7: if (I = 0) or (I = G.ColCount) then Glyph := BS.BottomT;
          $D, $E: if (J = 0) or (J = G.RowCount) then Glyph := BS.LeftT;
        end;

      ABuffer.SetStringN(X, Y, Glyph, 1, Sty);
    end;

  // Focus highlight: re-draw borders around focused cell with focus style
  if FHasFocus and (FFocusCol >= 0) and (FFocusCol < G.ColCount)
     and (FFocusRow >= 0) and (FFocusRow < G.RowCount) then
  begin
    X := G.ColOffsets[FFocusCol];
    Y := G.RowOffsets[FFocusRow];
    SepX := X + PanelCell(G, FFocusCol, FFocusRow).Width - 1;
    SepY := Y + PanelCell(G, FFocusCol, FFocusRow).Height - 1;
    // Top edge of focused cell
    if (FFocusRow = 0) and (peTop in Edges) then
      for I := X to SepX do ABuffer.SetStringN(I, Top_, BS.Horizontal, 1, FFocusStyle)
    else if (FFocusRow > 0) and (peInnerH in Edges) and FHSepVisible[FFocusRow - 1] then
      for I := X to SepX do ABuffer.SetStringN(I, Y - 1, SS.Horizontal, 1, FFocusStyle);
    // Bottom edge of focused cell
    if (FFocusRow = G.RowCount - 1) and (peBottom in Edges) then
      for I := X to SepX do ABuffer.SetStringN(I, Bottom_, BS.Horizontal, 1, FFocusStyle)
    else if (FFocusRow < G.RowCount - 1) and (peInnerH in Edges) and FHSepVisible[FFocusRow] then
      for I := X to SepX do ABuffer.SetStringN(I, SepY + 1, SS.Horizontal, 1, FFocusStyle);
    // Left edge of focused cell
    if (FFocusCol = 0) and (peLeft in Edges) then
      for J := Y to SepY do ABuffer.SetStringN(Left_, J, BS.Vertical, 1, FFocusStyle)
    else if (FFocusCol > 0) and (peInnerV in Edges) and FVSepVisible[FFocusCol - 1] then
      for J := Y to SepY do ABuffer.SetStringN(X - 1, J, SS.Vertical, 1, FFocusStyle);
    // Right edge of focused cell
    if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
      for J := Y to SepY do ABuffer.SetStringN(Right_, J, BS.Vertical, 1, FFocusStyle)
    else if (FFocusCol < G.ColCount - 1) and (peInnerV in Edges) and FVSepVisible[FFocusCol] then
      for J := Y to SepY do ABuffer.SetStringN(SepX + 1, J, SS.Vertical, 1, FFocusStyle);
    // Re-color the 4 corner junctions of the focused cell
    if (FFocusRow = 0) and (peTop in Edges) then
    begin
      if (FFocusCol = 0) and (peLeft in Edges) then
        ABuffer.SetStringN(Left_, Top_, BS.TopLeft, 1, FFocusStyle);
      if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
        ABuffer.SetStringN(Right_, Top_, BS.TopRight, 1, FFocusStyle);
    end;
    if (FFocusRow = G.RowCount - 1) and (peBottom in Edges) then
    begin
      if (FFocusCol = 0) and (peLeft in Edges) then
        ABuffer.SetStringN(Left_, Bottom_, BS.BottomLeft, 1, FFocusStyle);
      if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
        ABuffer.SetStringN(Right_, Bottom_, BS.BottomRight, 1, FFocusStyle);
    end;
  end;

  // Debug mode: show (col,row) in each cell
  if FDebug then
  begin
    SetLength(Glyph, 3);
    for J := 0 to G.RowCount - 1 do
      for I := 0 to G.ColCount - 1 do
      begin
        Glyph[1] := AnsiChar(Ord('0') + I);
        Glyph[2] := ',';
        Glyph[3] := AnsiChar(Ord('0') + J);
        ABuffer.SetStringN(
          G.Cells[J * G.ColCount + I].X,
          G.Cells[J * G.ColCount + I].Y,
          Glyph, Length(Glyph), TStyle.Default.WithFg(TUI_YELLOW));
      end;
  end;

  Result := G;
end;

end.
