program test_inherited_call;
type
  TBase = class
    FVal: Integer;
    constructor Create(V: Integer);
    function Compute: Integer; virtual;
  end;
  TDerived = class(TBase)
    FMul: Integer;
    constructor Create(V, M: Integer);
    function Compute: Integer; override;
  end;

constructor TBase.Create(V: Integer);
begin
  FVal := V;
end;

function TBase.Compute: Integer;
begin
  Result := FVal;
end;

constructor TDerived.Create(V, M: Integer);
begin
  FVal := V;
  FMul := M;
end;

function TDerived.Compute: Integer;
begin
  Result := inherited Compute * FMul;
end;

var D: TDerived;
begin
  D := TDerived.Create(7, 6);
  Halt(D.Compute);
end.
