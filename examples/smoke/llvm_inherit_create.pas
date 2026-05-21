program Llvm_inherit_create;
type
  TBase = class
    FVal: Integer;
    constructor Create(V: Integer);
    function GetVal: Integer; virtual;
  end;
  TDouble = class(TBase)
    function GetVal: Integer; override;
  end;

constructor TBase.Create(V: Integer);
begin
  FVal := V;
end;

function TBase.GetVal: Integer;
begin
  Result := FVal;
end;

function TDouble.GetVal: Integer;
begin
  Result := FVal * 2;
end;

var
  B: TBase;
  D: TBase;
begin
  B := TBase.Create(5);
  D := TDouble.Create(7);
  Halt(B.GetVal + D.GetVal);
end.
