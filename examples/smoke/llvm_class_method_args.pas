program Llvm_class_method_args;
type
  TMath = class
    FBase: Integer;
    constructor Create(ABase: Integer);
    function Add(A, B: Integer): Integer;
    function Scale(Factor: Integer): Integer;
  end;

constructor TMath.Create(ABase: Integer);
begin
  FBase := ABase;
end;

function TMath.Add(A, B: Integer): Integer;
begin
  Add := FBase + A + B;
end;

function TMath.Scale(Factor: Integer): Integer;
begin
  Scale := FBase * Factor;
end;

var
  M: TMath;
begin
  M := TMath.Create(10);
  Halt(M.Add(4, 8) + M.Scale(2));
end.
