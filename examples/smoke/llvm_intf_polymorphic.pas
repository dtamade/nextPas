program llvm_intf_polymorphic;
type
  IShape = interface
    function Area: Integer;
  end;
  TCircle = class(TInterfacedObject, IShape)
    FR: Integer;
    constructor Create(R: Integer);
    function Area: Integer;
  end;
  TSquare = class(TInterfacedObject, IShape)
    FS: Integer;
    constructor Create(S: Integer);
    function Area: Integer;
  end;

constructor TCircle.Create(R: Integer); begin FR := R; end;
function TCircle.Area: Integer; begin Result := FR * FR * 6; end;
constructor TSquare.Create(S: Integer); begin FS := S; end;
function TSquare.Area: Integer; begin Result := FS * FS; end;

function GetArea(S: IShape): Integer;
begin
  Result := S.Area;
end;

var
  C: IShape;
  S: IShape;
begin
  C := TCircle.Create(1);
  S := TSquare.Create(6);
  Halt(GetArea(C) + GetArea(S));
end.
