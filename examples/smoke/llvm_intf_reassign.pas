program test_intf_reassign;
type
  IValue = interface
    function Get: Integer;
  end;
  TValue = class(TInterfacedObject, IValue)
    FVal: Integer;
    constructor Create(V: Integer);
    function Get: Integer;
  end;

constructor TValue.Create(V: Integer);
begin
  FVal := V;
end;

function TValue.Get: Integer;
begin
  Result := FVal;
end;

var
  V: IValue;
begin
  V := TValue.Create(10);
  V := TValue.Create(42);
  Halt(V.Get);
end.
