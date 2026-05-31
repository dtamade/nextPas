unit nextpas.core.tui.widget.sparkline;

// Braille-based sparkline widget.
//
// Renders data points as a line chart using Unicode braille characters
// (U+2800..U+28FF). Each terminal cell is a 2x4 dot matrix (2 columns,
// 4 rows = 8 dots per cell). The Y axis is auto-scaled to fit the
// available height * 4 rows of dots.
//
// If there are more data points than available dot-columns (width * 2),
// only the last N points that fit are shown.

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

type
  TSparkline = record
    Data: array of Double;
    Style: TStyle;
    MaxVal: Double;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const AData: array of Double): TSparkline; static;
    function WithStyle(const S: TStyle): TSparkline;
    function WithMax(M: Double): TSparkline;
    function WithBlock(ABlock: IBlock): TSparkline;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

// Braille dot bit positions within a cell:
//   Col0: rows 0-3 -> bits 0,1,2,6
//   Col1: rows 0-3 -> bits 3,4,5,7
const
  DOT_BITS: array[0..1, 0..3] of Byte = (
    ($01, $02, $04, $40),
    ($08, $10, $20, $80)
  );

procedure BrailleToUtf8(CodePoint: Word; out B0, B1, B2: Byte); inline;
begin
  // U+2800..U+28FF -> 3-byte UTF-8
  B0 := $E0 or (CodePoint shr 12);
  B1 := $80 or ((CodePoint shr 6) and $3F);
  B2 := $80 or (CodePoint and $3F);
end;

{ TSparkline }

class function TSparkline.Create(const AData: array of Double): TSparkline;
var
  I: Integer;
begin
  SetLength(Result.Data, Length(AData));
  for I := 0 to High(AData) do
    Result.Data[I] := AData[I];
  Result.Style := TStyle.Default;
  Result.MaxVal := 0.0;
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TSparkline.WithStyle(const S: TStyle): TSparkline;
begin
  Result := Self;
  Result.Style := S;
end;

function TSparkline.WithMax(M: Double): TSparkline;
begin
  Result := Self;
  Result.MaxVal := M;
end;

function TSparkline.WithBlock(ABlock: IBlock): TSparkline;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := ABlock;
end;

procedure TSparkline.Render(const Area: TRect; ABuf: TBuffer);
var
  Inner: TRect;
  CellW, CellH: Integer;
  DotCols, DotRows: Integer;
  DataLen, DataStart, DataCount: Integer;
  ActualMax: Double;
  I: Integer;
  Grid: array of array of Byte;  // [cellCol][cellRow] = braille bits
  Col, Row: Integer;
  DotCol, DotRow: Integer;
  Val: Double;
  ScaledY: Integer;
  CellCol, CellRow, LocalRow, LocalCol: Integer;
  CP: Word;
  B0, B1, B2: Byte;
  GlyphStr: AnsiString;
  PC: PCell;
begin
  if Area.IsEmpty then Exit;
  DataLen := Length(Data);
  if DataLen = 0 then Exit;

  // Handle block
  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  CellW := Inner.Width;
  CellH := Inner.Height;
  DotCols := CellW * 2;
  DotRows := CellH * 4;

  // Determine how many data points to show
  if DataLen > DotCols then
  begin
    DataStart := DataLen - DotCols;
    DataCount := DotCols;
  end
  else
  begin
    DataStart := 0;
    DataCount := DataLen;
  end;

  // Determine max value for scaling
  ActualMax := MaxVal;
  if ActualMax <= 0.0 then
  begin
    ActualMax := 0.0;
    for I := DataStart to DataStart + DataCount - 1 do
      if Data[I] > ActualMax then
        ActualMax := Data[I];
  end;
  if ActualMax <= 0.0 then
    ActualMax := 1.0;

  // Allocate grid of braille bit patterns (one byte per cell)
  // TODO(perf): Grid 每帧堆分配。若成为瓶颈，用 frame-local arena 统一解决。
  SetLength(Grid, CellW, CellH);
  for Col := 0 to CellW - 1 do
    for Row := 0 to CellH - 1 do
      Grid[Col][Row] := 0;

  // Plot each data point as a dot
  for I := 0 to DataCount - 1 do
  begin
    Val := Data[DataStart + I];
    if Val < 0.0 then Val := 0.0;
    if Val > ActualMax then Val := ActualMax;

    // Scale to dot-row coordinate (0 = bottom, DotRows-1 = top)
    ScaledY := Trunc((Val / ActualMax) * (DotRows - 1) + 0.5);
    if ScaledY >= DotRows then ScaledY := DotRows - 1;

    // DotCol is the horizontal dot position
    DotCol := I;

    // Convert dot coordinates to cell coordinates
    CellCol := DotCol div 2;
    LocalCol := DotCol mod 2;

    // Braille Y: row 0 is top of cell, but our ScaledY 0 is bottom of area
    // Invert: actual dot row from top = (DotRows - 1 - ScaledY)
    DotRow := DotRows - 1 - ScaledY;
    CellRow := DotRow div 4;
    LocalRow := DotRow mod 4;

    if (CellCol < CellW) and (CellRow < CellH) then
      Grid[CellCol][CellRow] := Grid[CellCol][CellRow] or DOT_BITS[LocalCol][LocalRow];
  end;

  // Render grid to buffer
  SetLength(GlyphStr, 3);
  for Col := 0 to CellW - 1 do
    for Row := 0 to CellH - 1 do
    begin
      if Grid[Col][Row] = 0 then Continue;

      CP := $2800 + Grid[Col][Row];
      BrailleToUtf8(CP, B0, B1, B2);
      GlyphStr[1] := Chr(B0);
      GlyphStr[2] := Chr(B1);
      GlyphStr[3] := Chr(B2);

      ABuf.SetStringN(Inner.X + Col, Inner.Y + Row, GlyphStr, 1, Style);
    end;
end;

end.
