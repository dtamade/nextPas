unit nextpas.core.tui.widget.canvas;

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
  nextpas.core.tui.widget.intf;

type
  ICanvas = interface(IWidget)
    ['{E5F6A7B8-C9D0-1234-EFAB-567890123456}']
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure Clear;
    procedure SetDot(X, Y: Integer);
    procedure ClearDot(X, Y: Integer);
    function GetDot(X, Y: Integer): Boolean;
    procedure DrawLine(X1, Y1, X2, Y2: Integer);
    procedure DrawRect(X1, Y1, X2, Y2: Integer);
    procedure DrawCircle(CX, CY, Radius: Integer);
    procedure Plot(const Data: array of Double; PlotMax: Double);
    function WithStyle(const S: TStyle): ICanvas;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

  TCanvas = class(TInterfacedObject, IWidget, ICanvas)
  private
    FWidth, FHeight: Integer;
    FDots: array of Byte;
    FStyle: TStyle;
  public
    class function New(CellWidth, CellHeight: Integer): ICanvas; static;

    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure Clear;
    procedure SetDot(X, Y: Integer);
    procedure ClearDot(X, Y: Integer);
    function GetDot(X, Y: Integer): Boolean;
    procedure DrawLine(X1, Y1, X2, Y2: Integer);
    procedure DrawRect(X1, Y1, X2, Y2: Integer);
    procedure DrawCircle(CX, CY, Radius: Integer);
    procedure Plot(const Data: array of Double; PlotMax: Double);
    function WithStyle(const S: TStyle): ICanvas;

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

{ TCanvas }

class function TCanvas.New(CellWidth, CellHeight: Integer): ICanvas;
var
  LSelf: TCanvas;
  ByteCount: Integer;
begin
  LSelf := TCanvas.Create;
  LSelf.FWidth := CellWidth * 2;
  LSelf.FHeight := CellHeight * 4;
  ByteCount := (LSelf.FWidth * LSelf.FHeight + 7) div 8;
  SetLength(LSelf.FDots, ByteCount);
  FillChar(LSelf.FDots[0], ByteCount, 0);
  LSelf.FStyle := TStyle.Default;
  Result := LSelf;
end;

function TCanvas.GetWidth: Integer;
begin Result := FWidth; end;

function TCanvas.GetHeight: Integer;
begin Result := FHeight; end;

procedure TCanvas.Clear;
var ByteCount: Integer;
begin
  ByteCount := Length(FDots);
  if ByteCount > 0 then
    FillChar(FDots[0], ByteCount, 0);
end;

procedure TCanvas.SetDot(X, Y: Integer);
var BitIdx, ByteIdx, BitOff: Integer;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then Exit;
  BitIdx := Y * FWidth + X;
  ByteIdx := BitIdx div 8;
  BitOff := BitIdx mod 8;
  FDots[ByteIdx] := FDots[ByteIdx] or (1 shl BitOff);
end;

procedure TCanvas.ClearDot(X, Y: Integer);
var BitIdx, ByteIdx, BitOff: Integer;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then Exit;
  BitIdx := Y * FWidth + X;
  ByteIdx := BitIdx div 8;
  BitOff := BitIdx mod 8;
  FDots[ByteIdx] := FDots[ByteIdx] and (not (1 shl BitOff));
end;

function TCanvas.GetDot(X, Y: Integer): Boolean;
var BitIdx, ByteIdx, BitOff: Integer;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then Exit(False);
  BitIdx := Y * FWidth + X;
  ByteIdx := BitIdx div 8;
  BitOff := BitIdx mod 8;
  Result := (FDots[ByteIdx] and (1 shl BitOff)) <> 0;
end;

procedure TCanvas.DrawLine(X1, Y1, X2, Y2: Integer);
var DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  if X1 < X2 then SX := 1 else SX := -1;
  if Y1 < Y2 then SY := 1 else SY := -1;
  Err := DX - DY;
  while True do
  begin
    SetDot(X1, Y1);
    if (X1 = X2) and (Y1 = Y2) then Break;
    E2 := 2 * Err;
    if E2 > -DY then begin Dec(Err, DY); Inc(X1, SX); end;
    if E2 < DX then begin Inc(Err, DX); Inc(Y1, SY); end;
  end;
end;

procedure TCanvas.DrawRect(X1, Y1, X2, Y2: Integer);
begin
  DrawLine(X1, Y1, X2, Y1);
  DrawLine(X2, Y1, X2, Y2);
  DrawLine(X2, Y2, X1, Y2);
  DrawLine(X1, Y2, X1, Y1);
end;

procedure TCanvas.DrawCircle(CX, CY, Radius: Integer);
var X, Y, D: Integer;
begin
  if Radius <= 0 then
  begin
    if Radius = 0 then SetDot(CX, CY);
    Exit;
  end;
  X := 0; Y := Radius; D := 1 - Radius;
  while X <= Y do
  begin
    SetDot(CX + X, CY + Y); SetDot(CX - X, CY + Y);
    SetDot(CX + X, CY - Y); SetDot(CX - X, CY - Y);
    SetDot(CX + Y, CY + X); SetDot(CX - Y, CY + X);
    SetDot(CX + Y, CY - X); SetDot(CX - Y, CY - X);
    Inc(X);
    if D < 0 then D := D + 2 * X + 1
    else begin Dec(Y); D := D + 2 * (X - Y) + 1; end;
  end;
end;

procedure TCanvas.Plot(const Data: array of Double; PlotMax: Double);
var
  N, I: Integer;
  ActualMax: Double;
  PrevX, PrevY, CurX, CurY: Integer;
  Val: Double;
begin
  N := Length(Data);
  if N = 0 then Exit;
  ActualMax := PlotMax;
  if ActualMax <= 0.0 then
  begin
    ActualMax := 0.0;
    for I := 0 to N - 1 do
      if Data[I] > ActualMax then ActualMax := Data[I];
  end;
  if ActualMax <= 0.0 then ActualMax := 1.0;

  PrevX := 0;
  Val := Data[0];
  if Val < 0.0 then Val := 0.0;
  if Val > ActualMax then Val := ActualMax;
  PrevY := FHeight - 1 - Trunc((Val / ActualMax) * (FHeight - 1) + 0.5);
  if PrevY < 0 then PrevY := 0;
  if PrevY >= FHeight then PrevY := FHeight - 1;

  for I := 1 to N - 1 do
  begin
    if FWidth > 1 then CurX := (I * (FWidth - 1)) div (N - 1)
    else CurX := 0;
    Val := Data[I];
    if Val < 0.0 then Val := 0.0;
    if Val > ActualMax then Val := ActualMax;
    CurY := FHeight - 1 - Trunc((Val / ActualMax) * (FHeight - 1) + 0.5);
    if CurY < 0 then CurY := 0;
    if CurY >= FHeight then CurY := FHeight - 1;
    DrawLine(PrevX, PrevY, CurX, CurY);
    PrevX := CurX; PrevY := CurY;
  end;
  if N = 1 then SetDot(PrevX, PrevY);
end;

function TCanvas.WithStyle(const S: TStyle): ICanvas;
begin
  FStyle := S;
  Result := Self;
end;

procedure TCanvas.Render(const AArea: TRect; ABuffer: TBuffer);
var
  CellW, CellH: Integer;
  Col, Row: Integer;
  DotX, DotY, LocalCol, LocalRow: Integer;
  Bits: Byte;
  CP: Word;
  B0, B1, B2: Byte;
  GlyphStr: AnsiString;
begin
  if AArea.IsEmpty then Exit;
  CellW := AArea.Width;
  CellH := AArea.Height;
  SetLength(GlyphStr, 3);

  for Col := 0 to CellW - 1 do
    for Row := 0 to CellH - 1 do
    begin
      Bits := 0;
      for LocalCol := 0 to 1 do
        for LocalRow := 0 to 3 do
        begin
          DotX := Col * 2 + LocalCol;
          DotY := Row * 4 + LocalRow;
          if (DotX < FWidth) and (DotY < FHeight) then
            if GetDot(DotX, DotY) then
              Bits := Bits or DOT_BITS[LocalCol][LocalRow];
        end;
      if Bits = 0 then Continue;
      CP := $2800 + Bits;
      BrailleToUtf8(CP, B0, B1, B2);
      GlyphStr[1] := Chr(B0);
      GlyphStr[2] := Chr(B1);
      GlyphStr[3] := Chr(B2);
      ABuffer.SetStringN(AArea.X + Col, AArea.Y + Row, GlyphStr, 1, FStyle);
    end;
end;

end.
