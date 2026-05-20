program Param_scope_pass;
function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;
function Mul(A, B: Integer): Integer;
begin
  Mul := A * B;
end;
var
  X: Integer;
begin
  X := Add(1, 2) + Mul(3, 4);
end.
