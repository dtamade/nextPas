program Llvm_obj_field;
type
  TInner = class
    FVal: Integer;
    constructor Create(V: Integer);
    function Get: Integer; virtual;
  end;
  TOuter = class
    FInner: TInner;
    constructor Create(V: Integer);
    function GetInnerVal: Integer; virtual;
  end;

constructor TInner.Create(V: Integer);
begin
  FVal := V;
end;

function TInner.Get: Integer;
begin
  Result := FVal;
end;

constructor TOuter.Create(V: Integer);
begin
  FInner := TInner.Create(V);
end;

function TOuter.GetInnerVal: Integer;
begin
  Result := FInner.Get;
end;

var
  O: TOuter;
begin
  O := TOuter.Create(42);
  Halt(O.GetInnerVal);
end.
