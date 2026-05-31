unit nextpas.core.tui.widget.sparkline;

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
  ISparkline = interface(IWidget)
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    function WithStyle(const S: TStyle): ISparkline;
    function WithMax(M: Double): ISparkline;
    function WithBlock(ABlock: IBlock): ISparkline;
  end;

  TSparkline = class(TInterfacedObject, IWidget, ISparkline)
  private
    FData: array of Double;
    FStyle: TStyle;
    FMaxVal: Double;
    FBlock: IBlock;
  public
    class function New(const AData: array of Double): ISparkline; static;

    function WithStyle(const S: TStyle): ISparkline;
    function WithMax(M: Double): ISparkline;
    function WithBlock(ABlock: IBlock): ISparkline;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

const
  DOT_BITS: array[0..1, 0..3] of Byte = (
    ($01, $02, $04, $40),
    ($08, $10, $20, $80)
  );

procedure BrailleToUtf8(CodePoint: Word; out B0, B1, B2: Byte); inline;
begin
  B0 := $E0 or (CodePoint shr 12);
  B1 := $80 or ((CodePoint shr 6) and $3F);
  B2 := $80 or (CodePoint and $3F);
end;

{ TSparkline }

class function TSparkline.New(const AData: array of Double): ISparkline;
var
  LSelf: TSparkline;
  I: Integer;
begin
  LSelf := TSparkline.Create;
  SetLength(LSelf.FData, Length(AData));
  for I := 0 to High(AData) do
    LSelf.FData[I] := AData[I];
  LSelf.FStyle := TStyle.Default;
  LSelf.FMaxVal := 0.0;
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TSparkline.WithStyle(const S: TStyle): ISparkline;
begin
  FStyle := S;
  Result := Self;
end;

function TSparkline.WithMax(M: Double): ISparkline;
begin
  FMaxVal := M;
  Result := Self;
end;

function TSparkline.WithBlock(ABlock: IBlock): ISparkline;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TSparkline.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner: TRect;
  CellW, CellH: Integer;
  DotCols, DotRows: Integer;
  DataLen, DataStart, DataCount: Integer;
  ActualMax: Double;
  I: Integer;
  Grid: array of array of Byte;
  Col, Row: Integer;
  DotCol, DotRow: Integer;
  Val: Double;
  ScaledY: Integer;
  CellCol, CellRow, LocalRow, LocalCol: Integer;
  CP: Word;
  B0, B1, B2: Byte;
  GlyphStr: AnsiString;
begin
  if AArea.IsEmpty then Exit;
  DataLen := Length(FData);
  if DataLen = 0 then Exit;

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  CellW := Inner.Width;
  CellH := Inner.Height;
  DotCols := CellW * 2;
  DotRows := CellH * 4;

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

  ActualMax := FMaxVal;
  if ActualMax <= 0.0 then
  begin
    ActualMax := 0.0;
    for I := DataStart to DataStart + DataCount - 1 do
      if FData[I] > ActualMax then
        ActualMax := FData[I];
  end;
  if ActualMax <= 0.0 then
    ActualMax := 1.0;

  SetLength(Grid, CellW, CellH);
  for Col := 0 to CellW - 1 do
    for Row := 0 to CellH - 1 do
      Grid[Col][Row] := 0;

  for I := 0 to DataCount - 1 do
  begin
    Val := FData[DataStart + I];
    if Val < 0.0 then Val := 0.0;
    if Val > ActualMax then Val := ActualMax;

    ScaledY := Trunc((Val / ActualMax) * (DotRows - 1) + 0.5);
    if ScaledY >= DotRows then ScaledY := DotRows - 1;

    DotCol := I;
    CellCol := DotCol div 2;
    LocalCol := DotCol mod 2;

    DotRow := DotRows - 1 - ScaledY;
    CellRow := DotRow div 4;
    LocalRow := DotRow mod 4;

    if (CellCol < CellW) and (CellRow < CellH) then
      Grid[CellCol][CellRow] := Grid[CellCol][CellRow] or DOT_BITS[LocalCol][LocalRow];
  end;

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

      ABuffer.SetStringN(Inner.X + Col, Inner.Y + Row, GlyphStr, 1, FStyle);
    end;
end;

end.
