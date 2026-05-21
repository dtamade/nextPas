program Test_obj_param;
type
  TPoint = class
    FX, FY: Integer;
    constructor Create(AX, AY: Integer);
    function GetX: Integer;
    function GetY: Integer;
  end;
  TRect = class
    FWidth, FHeight: Integer;
    constructor Create(AW, AH: Integer);
    function Area: Integer;
  end;

constructor TPoint.Create(AX, AY: Integer);
begin
  FX := AX;
  FY := AY;
end;

function TPoint.GetX: Integer;
begin
  GetX := FX;
end;

function TPoint.GetY: Integer;
begin
  GetY := FY;
end;

constructor TRect.Create(AW, AH: Integer);
begin
  FWidth := AW;
  FHeight := AH;
end;

function TRect.Area: Integer;
begin
  Area := FWidth * FHeight;
end;

var
  P: TPoint;
  R: TRect;
begin
  P := TPoint.Create(3, 4);
  R := TRect.Create(P.GetX, P.GetY);
  Halt(R.Area);
end.
