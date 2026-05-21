program Test_nested_calls;
type
  TCalc = class
    FVal: Integer;
    constructor Create(AVal: Integer);
    function Get: Integer;
    function AddTo(X: Integer): Integer;
  end;

constructor TCalc.Create(AVal: Integer);
begin
  FVal := AVal;
end;

function TCalc.Get: Integer;
begin
  Get := FVal;
end;

function TCalc.AddTo(X: Integer): Integer;
begin
  AddTo := FVal + X;
end;

var
  A, B: TCalc;
begin
  A := TCalc.Create(10);
  B := TCalc.Create(5);
  Halt(A.AddTo(B.Get));
end.
