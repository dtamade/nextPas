program Class_hierarchy_pass;

{$mode objfpc}{$H+}

type
  TShape = class
  private
    FX: Integer;
    FY: Integer;
  public
    constructor Create(AX, AY: Integer);
    function Area: Integer; virtual;
    function Perimeter: Integer; virtual;
    function Description: string; virtual;
  end;

  TCircle = class(TShape)
  private
    FRadius: Integer;
  public
    constructor Create(AX, AY, ARadius: Integer);
    function Area: Integer; override;
    function Perimeter: Integer; override;
  end;

  TSquare = class(TShape)
  private
    FSide: Integer;
  public
    constructor Create(AX, AY, ASide: Integer);
    function Area: Integer; override;
    function Perimeter: Integer; override;
  end;

constructor TShape.Create(AX, AY: Integer);
begin
  FX := AX;
  FY := AY;
end;

function TShape.Area: Integer;
begin
  Result := 0;
end;

function TShape.Perimeter: Integer;
begin
  Result := 0;
end;

function TShape.Description: string;
begin
  Result := 'shape';
end;

constructor TCircle.Create(AX, AY, ARadius: Integer);
begin
  inherited Create(AX, AY);
  FRadius := ARadius;
end;

function TCircle.Area: Integer;
begin
  Result := 3 * FRadius * FRadius;
end;

function TCircle.Perimeter: Integer;
begin
  Result := 6 * FRadius;
end;

constructor TSquare.Create(AX, AY, ASide: Integer);
begin
  inherited Create(AX, AY);
  FSide := ASide;
end;

function TSquare.Area: Integer;
begin
  Result := FSide * FSide;
end;

function TSquare.Perimeter: Integer;
begin
  Result := 4 * FSide;
end;

function TotalArea(const Shapes: array of TShape): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Shapes) to High(Shapes) do
    Result := Result + Shapes[I].Area;
end;

var
  C: TCircle;
  S: TSquare;
  Total: Integer;
begin
  C := TCircle.Create(0, 0, 5);
  S := TSquare.Create(0, 0, 4);
  Total := C.Area + S.Area;
  Total := TotalArea([C, S]);
  C.Free;
  S.Free;
end.
