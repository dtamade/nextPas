program abstract_method_args_pass;
{$mode ObjFPC}{$H+}

type
  TShape = class
    function Area: Double; virtual; abstract;
    function IsOverlap(AOther: TShape): Boolean; virtual; abstract;
  end;

  TCircle = class(TShape)
    FRadius: Double;
    constructor Create(ARadius: Double);
    function Area: Double; override;
    function IsOverlap(AOther: TShape): Boolean; override;
  end;

constructor TCircle.Create(ARadius: Double);
begin
  FRadius := ARadius;
end;

function TCircle.Area: Double;
begin
  Result := 3.14159 * FRadius * FRadius;
end;

function TCircle.IsOverlap(AOther: TShape): Boolean;
begin
  Result := AOther <> nil;
end;

var
  C1, C2: TShape;
begin
  C1 := TCircle.Create(5.0);
  C2 := TCircle.Create(3.0);
  WriteLn(C1.Area:0:2);
  WriteLn(C1.IsOverlap(C2));
  C1.Free;
  C2.Free;
end.
