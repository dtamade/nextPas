program llvm_typecast_class;
type
  TBase = class
    FVal: Integer;
    constructor Create(V: Integer);
    function GetVal: Integer; virtual;
  end;
  TChild = class(TBase)
    FExtra: Integer;
    constructor Create(V, E: Integer);
    function GetExtra: Integer; virtual;
  end;

constructor TBase.Create(V: Integer); begin FVal := V; end;
function TBase.GetVal: Integer; begin Result := FVal; end;
constructor TChild.Create(V, E: Integer); begin FVal := V; FExtra := E; end;
function TChild.GetExtra: Integer; begin Result := FExtra; end;

var
  B: TBase;
  C: TChild;
begin
  B := TChild.Create(10, 32);
  C := TChild(B);
  Halt(C.GetVal + C.GetExtra);
end.
