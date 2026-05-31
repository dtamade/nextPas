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
  nextpas.core.tui.layout;

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

  TPanel = record
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
    class function Create(
      const Cols: array of TConstraint;
      const Rows: array of TConstraint): TPanel; static;
    function WithBorderSet(const BS: TBorderSet): TPanel;
    function WithSepSet(const BS: TBorderSet): TPanel;
    function WithEdges(E: TPanelEdges): TPanel;
    function WithBorderStyle(const S: TStyle): TPanel;
    function WithHSepStartCol(Col: Integer): TPanel;
    function WithHSepStartColAt(SepIndex: Integer; Col: Integer): TPanel;
    function WithVSepStartRow(Row: Integer): TPanel;
    function WithVSepEndRow(Row: Integer): TPanel;
    function WithHSepVisible(SepIndex: Integer; Visible: Boolean): TPanel;
    function WithVSepVisible(SepIndex: Integer; Visible: Boolean): TPanel;
    function WithHSepTitle(SepIndex: Integer; const ATitle: AnsiString): TPanel;
    function WithHSepTitleStyle(SepIndex: Integer; const ATitle: AnsiString; const S: TStyle): TPanel;
    function WithFocus(Col, Row: Integer): TPanel;
    function WithFocusStyle(const S: TStyle): TPanel;
    function WithPadding(P: Byte): TPanel;
    function WithCellPadding(Col, Row: Integer; P: Byte): TPanel;
    function WithMinWidth(Col: Integer; Min: Integer): TPanel;
    function WithMinHeight(Row: Integer; Min: Integer): TPanel;
    function WithColWeight(Col: Integer; Weight: Word): TPanel;
    function WithRowWeight(Row: Integer; Weight: Word): TPanel;
    function WithDebug(Enable: Boolean): TPanel;
    function Layout(const Area: TRect): TPanelGrid;
    function Render(const Area: TRect; ABuf: TBuffer): TPanelGrid;
    class function Sidebar(SidebarWidth: Integer): TPanel; static;
    class function HSplit(TopHeight: Integer): TPanel; static;
    class function Grid(ACols, ARows: Integer): TPanel; static;
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

class function TPanel.Create(
  const Cols: array of TConstraint;
  const Rows: array of TConstraint): TPanel;
var
  I: Integer;
begin
  Result.FColCount := Length(Cols);
  if Result.FColCount > PANEL_MAX_COLS then Result.FColCount := PANEL_MAX_COLS;
  for I := 0 to Result.FColCount - 1 do
    Result.FCols[I] := Cols[I];

  Result.FRowCount := Length(Rows);
  if Result.FRowCount > PANEL_MAX_ROWS then Result.FRowCount := PANEL_MAX_ROWS;
  for I := 0 to Result.FRowCount - 1 do
    Result.FRows[I] := Rows[I];

  Result.FBorderSet := BorderSetPlain;
  Result.FHasSepSet := False;
  Result.FEdges := PanelEdgesAll;
  Result.FBorderStyle := TStyle.Default;
  Result.FVSepStartRow := 0;
  Result.FVSepEndRow := PANEL_MAX_ROWS;
  Result.FHasFocus := False;
  Result.FFocusCol := 0;
  Result.FFocusRow := 0;
  Result.FFocusStyle := TStyle.Default.WithFg(TUI_WHITE).WithModifier([mbBold]);
  Result.FPadding := 0;
  Result.FHasCellPadding := False;
  Result.FDebug := False;
  for I := 0 to PANEL_MAX_HSEP - 1 do
  begin
    Result.FHSepVisible[I] := True;
    Result.FHSepTitles[I].HasTitle := False;
    Result.FHSepStartCol[I] := 0;
  end;
  for I := 0 to PANEL_MAX_VSEP - 1 do
    Result.FVSepVisible[I] := True;
  for I := 0 to PANEL_MAX_COLS - 1 do
    Result.FMinWidths[I] := 0;
  for I := 0 to PANEL_MAX_ROWS - 1 do
    Result.FMinHeights[I] := 0;
  for I := 0 to PANEL_MAX_CELLS - 1 do
    Result.FCellPadding[I] := 0;
end;

function TPanel.WithBorderSet(const BS: TBorderSet): TPanel;
begin Result := Self; Result.FBorderSet := BS; end;

function TPanel.WithSepSet(const BS: TBorderSet): TPanel;
begin Result := Self; Result.FSepSet := BS; Result.FHasSepSet := True; end;

function TPanel.WithEdges(E: TPanelEdges): TPanel;
begin Result := Self; Result.FEdges := E; end;

function TPanel.WithBorderStyle(const S: TStyle): TPanel;
begin Result := Self; Result.FBorderStyle := S; end;

function TPanel.WithHSepStartCol(Col: Integer): TPanel;
var I: Integer;
begin
  Result := Self;
  if Col < 0 then Col := 0;
  if Col >= Result.FColCount then Col := Result.FColCount - 1;
  for I := 0 to PANEL_MAX_HSEP - 1 do
    Result.FHSepStartCol[I] := Col;
end;

function TPanel.WithHSepStartColAt(SepIndex: Integer; Col: Integer): TPanel;
begin
  Result := Self;
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    if Col < 0 then Col := 0;
    if Col >= Result.FColCount then Col := Result.FColCount - 1;
    Result.FHSepStartCol[SepIndex] := Col;
  end;
end;

function TPanel.WithVSepStartRow(Row: Integer): TPanel;
begin
  Result := Self;
  if Row < 0 then Row := 0;
  if Row >= Result.FRowCount then Row := Result.FRowCount - 1;
  Result.FVSepStartRow := Row;
end;

function TPanel.WithVSepEndRow(Row: Integer): TPanel;
begin
  Result := Self;
  if Row < 1 then Row := 1;
  if Row > Result.FRowCount then Row := Result.FRowCount;
  Result.FVSepEndRow := Row;
end;

function TPanel.WithHSepVisible(SepIndex: Integer; Visible: Boolean): TPanel;
begin
  Result := Self;
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
    Result.FHSepVisible[SepIndex] := Visible;
end;

function TPanel.WithVSepVisible(SepIndex: Integer; Visible: Boolean): TPanel;
begin
  Result := Self;
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_VSEP) then
    Result.FVSepVisible[SepIndex] := Visible;
end;

function TPanel.WithHSepTitle(SepIndex: Integer; const ATitle: AnsiString): TPanel;
begin
  Result := Self;
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    Result.FHSepTitles[SepIndex].Text := ATitle;
    Result.FHSepTitles[SepIndex].HasTitle := True;
    Result.FHSepTitles[SepIndex].HasStyle := False;
  end;
end;

function TPanel.WithHSepTitleStyle(SepIndex: Integer; const ATitle: AnsiString; const S: TStyle): TPanel;
begin
  Result := Self;
  if (SepIndex >= 0) and (SepIndex < PANEL_MAX_HSEP) then
  begin
    Result.FHSepTitles[SepIndex].Text := ATitle;
    Result.FHSepTitles[SepIndex].Style := S;
    Result.FHSepTitles[SepIndex].HasTitle := True;
    Result.FHSepTitles[SepIndex].HasStyle := True;
  end;
end;

function TPanel.WithFocus(Col, Row: Integer): TPanel;
begin
  Result := Self;
  Result.FHasFocus := True;
  Result.FFocusCol := Col;
  Result.FFocusRow := Row;
end;

function TPanel.WithFocusStyle(const S: TStyle): TPanel;
begin Result := Self; Result.FFocusStyle := S; end;

function TPanel.WithPadding(P: Byte): TPanel;
begin Result := Self; Result.FPadding := P; end;

function TPanel.WithCellPadding(Col, Row: Integer; P: Byte): TPanel;
begin
  Result := Self;
  if (Col >= 0) and (Col < PANEL_MAX_COLS) and (Row >= 0) and (Row < PANEL_MAX_ROWS) then
  begin
    Result.FCellPadding[Row * PANEL_MAX_COLS + Col] := P;
    Result.FHasCellPadding := True;
  end;
end;

function TPanel.WithMinWidth(Col: Integer; Min: Integer): TPanel;
begin
  Result := Self;
  if (Col >= 0) and (Col < PANEL_MAX_COLS) then
    Result.FMinWidths[Col] := Min;
end;

function TPanel.WithMinHeight(Row: Integer; Min: Integer): TPanel;
begin
  Result := Self;
  if (Row >= 0) and (Row < PANEL_MAX_ROWS) then
    Result.FMinHeights[Row] := Min;
end;

function TPanel.WithColWeight(Col: Integer; Weight: Word): TPanel;
begin
  Result := Self;
  if (Col >= 0) and (Col < Result.FColCount) then
    Result.FCols[Col] := FillConstraint(Weight);
end;

function TPanel.WithRowWeight(Row: Integer; Weight: Word): TPanel;
begin
  Result := Self;
  if (Row >= 0) and (Row < Result.FRowCount) then
    Result.FRows[Row] := FillConstraint(Weight);
end;

function TPanel.WithDebug(Enable: Boolean): TPanel;
begin Result := Self; Result.FDebug := Enable; end;

class function TPanel.Sidebar(SidebarWidth: Integer): TPanel;
begin
  Result := TPanel.Create(
    [LengthConstraint(SidebarWidth), MinConstraint(0)],
    [MinConstraint(0)]);
end;

class function TPanel.HSplit(TopHeight: Integer): TPanel;
begin
  Result := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(TopHeight), MinConstraint(0)]);
end;

class function TPanel.Grid(ACols, ARows: Integer): TPanel;
var
  Cs: array[0..PANEL_MAX_COLS - 1] of TConstraint;
  Rs: array[0..PANEL_MAX_ROWS - 1] of TConstraint;
  I: Integer;
begin
  if ACols > PANEL_MAX_COLS then ACols := PANEL_MAX_COLS;
  if ARows > PANEL_MAX_ROWS then ARows := PANEL_MAX_ROWS;
  for I := 0 to ACols - 1 do Cs[I] := MinConstraint(0);
  for I := 0 to ARows - 1 do Rs[I] := MinConstraint(0);
  Result := TPanel.Create(Slice(Cs, ACols), Slice(Rs, ARows));
end;

function TPanel.Layout(const Area: TRect): TPanelGrid;
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

  if (FColCount = 0) or (FRowCount = 0) or Area.IsEmpty then Exit;

  BorderL := Ord(peLeft in FEdges);
  BorderR := Ord(peRight in FEdges);
  BorderT := Ord(peTop in FEdges);
  BorderB := Ord(peBottom in FEdges);
  if peInnerV in FEdges then InnerVCount := FColCount - 1 else InnerVCount := 0;
  if peInnerH in FEdges then InnerHCount := FRowCount - 1 else InnerHCount := 0;

  InnerW := Integer(Area.Width) - BorderL - BorderR - InnerVCount;
  InnerH := Integer(Area.Height) - BorderT - BorderB - InnerHCount;
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

  Cursor := Integer(Area.X) + BorderL;
  for I := 0 to FColCount - 1 do
  begin
    Result.ColOffsets[I] := Cursor;
    Inc(Cursor, ColSizes[I]);
    if (I < FColCount - 1) and (peInnerV in FEdges) then
      Inc(Cursor);
  end;
  Result.ColOffsets[FColCount] := Cursor;

  Cursor := Integer(Area.Y) + BorderT;
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

function TPanel.Render(const Area: TRect; ABuf: TBuffer): TPanelGrid;
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
  G := Layout(Area);
  if (G.ColCount = 0) or (G.RowCount = 0) or Area.IsEmpty then
  begin
    Result := G;
    Exit;
  end;

  BS := FBorderSet;
  if FHasSepSet then SS := FSepSet else SS := BS;
  Edges := FEdges;
  Sty := FBorderStyle;
  Left_ := Area.X;
  Top_ := Area.Y;
  Right_ := Integer(Area.X) + Integer(Area.Width) - 1;
  Bottom_ := Integer(Area.Y) + Integer(Area.Height) - 1;

  // Draw outer horizontal edges
  if peTop in Edges then
    for X := Left_ + 1 to Right_ - 1 do
      ABuf.SetStringN(X, Top_, BS.Horizontal, 1, Sty);
  if peBottom in Edges then
    for X := Left_ + 1 to Right_ - 1 do
      ABuf.SetStringN(X, Bottom_, BS.Horizontal, 1, Sty);

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
        ABuf.SetStringN(X, SepY, SS.Horizontal, 1, Sty);
      // Draw title on separator
      if FHSepTitles[J - 1].HasTitle then
      begin
        TitleLen := Length(FHSepTitles[J - 1].Text);
        TitleX := HStart + 2;
        if TitleX + TitleLen < Right_ then
        begin
          if FHSepTitles[J - 1].HasStyle then
            ABuf.SetStringN(TitleX, SepY, FHSepTitles[J - 1].Text, TitleLen, FHSepTitles[J - 1].Style)
          else
            ABuf.SetStringN(TitleX, SepY, FHSepTitles[J - 1].Text, TitleLen, Sty);
        end;
      end;
    end;

  // Draw outer vertical edges
  if peLeft in Edges then
    for Y := Top_ + 1 to Bottom_ - 1 do
      ABuf.SetStringN(Left_, Y, BS.Vertical, 1, Sty);
  if peRight in Edges then
    for Y := Top_ + 1 to Bottom_ - 1 do
      ABuf.SetStringN(Right_, Y, BS.Vertical, 1, Sty);

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
        ABuf.SetStringN(SepX, Y, SS.Vertical, 1, Sty);
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

      ABuf.SetStringN(X, Y, Glyph, 1, Sty);
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
      for I := X to SepX do ABuf.SetStringN(I, Top_, BS.Horizontal, 1, FFocusStyle)
    else if (FFocusRow > 0) and (peInnerH in Edges) and FHSepVisible[FFocusRow - 1] then
      for I := X to SepX do ABuf.SetStringN(I, Y - 1, SS.Horizontal, 1, FFocusStyle);
    // Bottom edge of focused cell
    if (FFocusRow = G.RowCount - 1) and (peBottom in Edges) then
      for I := X to SepX do ABuf.SetStringN(I, Bottom_, BS.Horizontal, 1, FFocusStyle)
    else if (FFocusRow < G.RowCount - 1) and (peInnerH in Edges) and FHSepVisible[FFocusRow] then
      for I := X to SepX do ABuf.SetStringN(I, SepY + 1, SS.Horizontal, 1, FFocusStyle);
    // Left edge of focused cell
    if (FFocusCol = 0) and (peLeft in Edges) then
      for J := Y to SepY do ABuf.SetStringN(Left_, J, BS.Vertical, 1, FFocusStyle)
    else if (FFocusCol > 0) and (peInnerV in Edges) and FVSepVisible[FFocusCol - 1] then
      for J := Y to SepY do ABuf.SetStringN(X - 1, J, SS.Vertical, 1, FFocusStyle);
    // Right edge of focused cell
    if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
      for J := Y to SepY do ABuf.SetStringN(Right_, J, BS.Vertical, 1, FFocusStyle)
    else if (FFocusCol < G.ColCount - 1) and (peInnerV in Edges) and FVSepVisible[FFocusCol] then
      for J := Y to SepY do ABuf.SetStringN(SepX + 1, J, SS.Vertical, 1, FFocusStyle);
    // Re-color the 4 corner junctions of the focused cell
    if (FFocusRow = 0) and (peTop in Edges) then
    begin
      if (FFocusCol = 0) and (peLeft in Edges) then
        ABuf.SetStringN(Left_, Top_, BS.TopLeft, 1, FFocusStyle);
      if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
        ABuf.SetStringN(Right_, Top_, BS.TopRight, 1, FFocusStyle);
    end;
    if (FFocusRow = G.RowCount - 1) and (peBottom in Edges) then
    begin
      if (FFocusCol = 0) and (peLeft in Edges) then
        ABuf.SetStringN(Left_, Bottom_, BS.BottomLeft, 1, FFocusStyle);
      if (FFocusCol = G.ColCount - 1) and (peRight in Edges) then
        ABuf.SetStringN(Right_, Bottom_, BS.BottomRight, 1, FFocusStyle);
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
        ABuf.SetStringN(
          G.Cells[J * G.ColCount + I].X,
          G.Cells[J * G.ColCount + I].Y,
          Glyph, Length(Glyph), TStyle.Default.WithFg(TUI_YELLOW));
      end;
  end;

  Result := G;
end;

end.
