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

  TStatusBar = record
    Left: array of TStatusSegment;
    Center: array of TStatusSegment;
    Right: array of TStatusSegment;
    Style: TStyle;

    class function Default: TStatusBar; static;
    function WithStyle(const S: TStyle): TStatusBar;
    function WithLeft(const Segs: array of TStatusSegment): TStatusBar;
    function WithCenter(const Segs: array of TStatusSegment): TStatusBar;
    function WithRight(const Segs: array of TStatusSegment): TStatusBar;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

{ TStatusSegment }

class function TStatusSegment.Make(const AText: AnsiString): TStatusSegment;
begin
  Result.Text := AText;
  Result.Style := TStyle.Default;
end;

function TStatusSegment.WithStyle(const S: TStyle): TStatusSegment;
begin
  Result := Self;
  Result.Style := S;
end;

{ TStatusBar }

class function TStatusBar.Default: TStatusBar;
begin
  Result.Left := nil;
  Result.Center := nil;
  Result.Right := nil;
  Result.Style := TStyle.Default;
end;

function TStatusBar.WithStyle(const S: TStyle): TStatusBar;
begin
  Result := Self;
  Result.Style := S;
end;

function TStatusBar.WithLeft(const Segs: array of TStatusSegment): TStatusBar;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Left, Length(Segs));
  for I := 0 to High(Segs) do Result.Left[I] := Segs[I];
end;

function TStatusBar.WithCenter(const Segs: array of TStatusSegment): TStatusBar;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Center, Length(Segs));
  for I := 0 to High(Segs) do Result.Center[I] := Segs[I];
end;

function TStatusBar.WithRight(const Segs: array of TStatusSegment): TStatusBar;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Right, Length(Segs));
  for I := 0 to High(Segs) do Result.Right[I] := Segs[I];
end;

procedure TStatusBar.Render(const Area: TRect; ABuf: TBuffer);
var
  I, X, W, TotalRight, TotalCenter, CenterStart: Integer;
begin
  if Area.IsEmpty then Exit;
  W := Area.Width;

  ABuf.SetStyle(TRect.Make(Area.X, Area.Y, W, 1), Style);

  // Left segments
  X := Area.X;
  for I := 0 to High(Left) do
  begin
    if X >= Area.X + W then Break;
    ABuf.SetStringN(X, Area.Y, Left[I].Text, W - (X - Area.X), Style.Patch(Left[I].Style));
    Inc(X, Integer(StringDisplayWidth(Left[I].Text)));
  end;

  // Right segments (render from right edge)
  TotalRight := 0;
  for I := 0 to High(Right) do
    Inc(TotalRight, Integer(StringDisplayWidth(Right[I].Text)));
  X := Area.X + W - TotalRight;
  if X < Area.X then X := Area.X;
  for I := 0 to High(Right) do
  begin
    if X >= Area.X + W then Break;
    ABuf.SetStringN(X, Area.Y, Right[I].Text, W - (X - Area.X), Style.Patch(Right[I].Style));
    Inc(X, Integer(StringDisplayWidth(Right[I].Text)));
  end;

  // Center segments
  TotalCenter := 0;
  for I := 0 to High(Center) do
    Inc(TotalCenter, Integer(StringDisplayWidth(Center[I].Text)));
  CenterStart := Area.X + (W - TotalCenter) div 2;
  if CenterStart < Area.X then CenterStart := Area.X;
  X := CenterStart;
  for I := 0 to High(Center) do
  begin
    if X >= Area.X + W then Break;
    ABuf.SetStringN(X, Area.Y, Center[I].Text, W - (X - Area.X), Style.Patch(Center[I].Style));
    Inc(X, Integer(StringDisplayWidth(Center[I].Text)));
  end;
end;

end.
