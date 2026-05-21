program Llvm_factory;
type
  TObj = class
    FVal: Integer;
    constructor Create(V: Integer);
    function Get: Integer; virtual;
  end;

constructor TObj.Create(V: Integer);
begin
  FVal := V;
end;

function TObj.Get: Integer;
begin
  Result := FVal;
end;

function MakeObj(V: Integer): TObj;
begin
  Result := TObj.Create(V);
end;

var
  O: TObj;
begin
  O := MakeObj(42);
  Halt(O.Get);
end.
