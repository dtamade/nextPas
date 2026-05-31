program test_nested_class;
type
  TPoint = class
    FX, FY: Integer;
    constructor Create(X, Y: Integer);
    function DistSq: Integer; virtual;
  end;
  TLine = class
    FStart: TPoint;
    FEnd2: TPoint;
    constructor Create(X1, Y1, X2, Y2: Integer);
    function LengthSq: Integer; virtual;
  end;

constructor TPoint.Create(X, Y: Integer);
begin
  FX := X;
  FY := Y;
end;
function TPoint.DistSq: Integer;
begin
  Result := FX * FX + FY * FY;
end;

constructor TLine.Create(X1, Y1, X2, Y2: Integer);
begin
  FStart := TPoint.Create(X1, Y1);
  FEnd2 := TPoint.Create(X2, Y2);
end;

function TLine.LengthSq: Integer;
var
  DX, DY: Integer;
begin
  DX := FEnd2.FX - FStart.FX;
  DY := FEnd2.FY - FStart.FY;
  Result := DX * DX + DY * DY;
end;

var L: TLine;
begin
  L := TLine.Create(1, 2, 4, 6);
  Halt(L.LengthSq);
end.
