unit nextpas.core.tui.widget.statusbar;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.text.width, nextpas.core.text.utf8,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TStatusSegment = record
    Text: AnsiString;
    Style: TStyle;
    class function Make(const AText: AnsiString): TStatusSegment; static;
    function WithStyle(const S: TStyle): TStatusSegment;
  end;

  IStatusBar = interface(IWidget)
    ['{A3B4C5D6-E7F8-9012-ABCD-345678901234}']
    function WithStyle(const S: TStyle): IStatusBar;
    function WithLeft(const Segs: array of TStatusSegment): IStatusBar;
    function WithCenter(const Segs: array of TStatusSegment): IStatusBar;
    function WithRight(const Segs: array of TStatusSegment): IStatusBar;
  end;

  TStatusBar = class(TInterfacedObject, IWidget, IStatusBar)
  private
    FLeft: array of TStatusSegment;
    FCenter: array of TStatusSegment;
    FRight: array of TStatusSegment;
    FStyle: TStyle;
  public
    class function New: IStatusBar; static;

    function WithStyle(const S: TStyle): IStatusBar;
    function WithLeft(const Segs: array of TStatusSegment): IStatusBar;
    function WithCenter(const Segs: array of TStatusSegment): IStatusBar;
    function WithRight(const Segs: array of TStatusSegment): IStatusBar;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

{ TStatusSegment }

class function TStatusSegment.Make(const AText: AnsiString): TStatusSegment;
begin
  Result.Text := AText;
  Result.Style := TStyle.Default;
end;

function TStatusSegment.WithStyle(const S: TStyle): TStatusSegment;
begin Result := Self; Result.Style := S; end;

{ TStatusBar }

class function TStatusBar.New: IStatusBar;
var LSelf: TStatusBar;
begin
  LSelf := TStatusBar.Create;
  LSelf.FLeft := nil;
  LSelf.FCenter := nil;
  LSelf.FRight := nil;
  LSelf.FStyle := TStyle.Default;
  Result := LSelf;
end;

function TStatusBar.WithStyle(const S: TStyle): IStatusBar;
begin FStyle := S; Result := Self; end;

function TStatusBar.WithLeft(const Segs: array of TStatusSegment): IStatusBar;
var I: Integer;
begin
  SetLength(FLeft, Length(Segs));
  for I := 0 to High(Segs) do FLeft[I] := Segs[I];
  Result := Self;
end;

function TStatusBar.WithCenter(const Segs: array of TStatusSegment): IStatusBar;
var I: Integer;
begin
  SetLength(FCenter, Length(Segs));
  for I := 0 to High(Segs) do FCenter[I] := Segs[I];
  Result := Self;
end;

function TStatusBar.WithRight(const Segs: array of TStatusSegment): IStatusBar;
var I: Integer;
begin
  SetLength(FRight, Length(Segs));
  for I := 0 to High(Segs) do FRight[I] := Segs[I];
  Result := Self;
end;

procedure TStatusBar.Render(const AArea: TRect; ABuffer: TBuffer);
var
  I, X, W, TotalRight, TotalCenter, CenterStart: Integer;
begin
  if AArea.IsEmpty then Exit;
  W := AArea.Width;

  ABuffer.SetStyle(TRect.Make(AArea.X, AArea.Y, W, 1), FStyle);

  X := AArea.X;
  for I := 0 to High(FLeft) do
  begin
    if X >= AArea.X + W then Break;
    ABuffer.SetStringN(X, AArea.Y, FLeft[I].Text, W - (X - AArea.X), FStyle.Patch(FLeft[I].Style));
    Inc(X, Integer(StringDisplayWidth(FLeft[I].Text)));
  end;

  TotalRight := 0;
  for I := 0 to High(FRight) do
    Inc(TotalRight, Integer(StringDisplayWidth(FRight[I].Text)));
  X := AArea.X + W - TotalRight;
  if X < AArea.X then X := AArea.X;
  for I := 0 to High(FRight) do
  begin
    if X >= AArea.X + W then Break;
    ABuffer.SetStringN(X, AArea.Y, FRight[I].Text, W - (X - AArea.X), FStyle.Patch(FRight[I].Style));
    Inc(X, Integer(StringDisplayWidth(FRight[I].Text)));
  end;

  TotalCenter := 0;
  for I := 0 to High(FCenter) do
    Inc(TotalCenter, Integer(StringDisplayWidth(FCenter[I].Text)));
  CenterStart := AArea.X + (W - TotalCenter) div 2;
  if CenterStart < AArea.X then CenterStart := AArea.X;
  X := CenterStart;
  for I := 0 to High(FCenter) do
  begin
    if X >= AArea.X + W then Break;
    ABuffer.SetStringN(X, AArea.Y, FCenter[I].Text, W - (X - AArea.X), FStyle.Patch(FCenter[I].Style));
    Inc(X, Integer(StringDisplayWidth(FCenter[I].Text)));
  end;
end;

end.
