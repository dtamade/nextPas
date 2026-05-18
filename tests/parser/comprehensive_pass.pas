program Comprehensive_pass;

{$mode objfpc}{$H+}

type
  TDirection = (dirNorth, dirSouth, dirEast, dirWest);
  TDirectionSet = set of TDirection;

  TPoint = record
    X: Integer;
    Y: Integer;
  end;

  TShape = class
  private
    FOrigin: TPoint;
    FName: string;
  public
    constructor Create(const AName: string; AX, AY: Integer);
    destructor Destroy; override;
    function Area: Integer; virtual;
    property Origin: TPoint read FOrigin;
    property Name: string read FName;
  end;

  TRectangle = class(TShape)
  private
    FWidth: Integer;
    FHeight: Integer;
  public
    constructor Create(const AName: string; AX, AY, AW, AH: Integer);
    function Area: Integer; override;
  end;

operator + (A, B: TPoint): TPoint;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
end;

constructor TShape.Create(const AName: string; AX, AY: Integer);
begin
  FName := AName;
  FOrigin.X := AX;
  FOrigin.Y := AY;
end;

destructor TShape.Destroy;
begin
  inherited Destroy;
end;

function TShape.Area: Integer;
begin
  Result := 0;
end;

constructor TRectangle.Create(const AName: string; AX, AY, AW, AH: Integer);
begin
  inherited Create(AName, AX, AY);
  FWidth := AW;
  FHeight := AH;
end;

function TRectangle.Area: Integer;
begin
  Result := FWidth * FHeight;
end;

var
  R: TRectangle;
  Dirs: TDirectionSet;
  P: TPoint;
  I: Integer;
  Arr: array[1..5] of Integer;
begin
  R := TRectangle.Create('MyRect', 0, 0, 10, 20);

  try
    I := R.Area;

    Dirs := [dirNorth, dirEast];
    if dirNorth in Dirs then
      I := I + 1;

    Arr[1] := 10;
    Arr[2] := 20;
    for I := 1 to 5 do
      Arr[I] := I * 10;

    P.Y := Arr[1] + Arr[2];
  finally
    R.Free;
  end;
end.
