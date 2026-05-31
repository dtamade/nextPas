program llvm_polymorphic_array;
type
  TShape = class
    constructor Create;
    function Area: Integer; virtual;
  end;
  TCircle = class(TShape)
    FR: Integer;
    constructor Create(R: Integer);
    function Area: Integer; override;
  end;
  TSquare = class(TShape)
    FS: Integer;
    constructor Create(S: Integer);
    function Area: Integer; override;
  end;

constructor TShape.Create; begin end;
function TShape.Area: Integer; begin Result := 0; end;

constructor TCircle.Create(R: Integer); begin FR := R; end;
function TCircle.Area: Integer; begin Result := FR * FR * 2; end;

constructor TSquare.Create(S: Integer); begin FS := S; end;
function TSquare.Area: Integer; begin Result := FS * FS; end;

var
  Arr: array of TShape;
  I, S: Integer;
begin
  SetLength(Arr, 3);
  Arr[0] := TCircle.Create(3);
  Arr[1] := TSquare.Create(4);
  Arr[2] := TCircle.Create(2);
  S := 0;
  for I := 0 to 2 do
    S := S + Arr[I].Area;
  Halt(S);
end.
