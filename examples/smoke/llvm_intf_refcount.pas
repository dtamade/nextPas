program llvm_intf_refcount;
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

function UseIntf(V: IValue): Integer;
begin
  Result := V.Get;
end;

var
  V: IValue;
begin
  V := TValue.Create(42);
  Halt(UseIntf(V));
end.
