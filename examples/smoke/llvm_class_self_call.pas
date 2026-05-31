program Llvm_class_self_call;
type
  TCalc = class
    FVal: Integer;
    constructor Create(AVal: Integer);
    function Double: Integer;
    function Quadruple: Integer;
  end;

constructor TCalc.Create(AVal: Integer);
begin
  FVal := AVal;
end;

function TCalc.Double: Integer;
begin
  Double := FVal * 3;
end;

function TCalc.Quadruple: Integer;
begin
  Quadruple := Double + Double;
end;

var
  C: TCalc;
begin
  C := TCalc.Create(7);
  Halt(C.Quadruple);
end.
