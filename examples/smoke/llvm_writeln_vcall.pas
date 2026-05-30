program llvm_writeln_vcall;
type
  TCalc = class
    FVal: Integer;
    constructor Create(V: Integer);
    function GetVal: Integer; virtual;
    function Double: Integer; virtual;
  end;

constructor TCalc.Create(V: Integer);
begin
  FVal := V;
end;

function TCalc.GetVal: Integer;
begin
  Result := FVal;
end;

function TCalc.Double: Integer;
begin
  Result := FVal * 2;
end;

var
  C: TCalc;
begin
  C := TCalc.Create(21);
  WriteLn(C.GetVal);
  Halt(C.Double);
end.
