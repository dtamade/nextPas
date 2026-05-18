program Diagnostics_pass;
const
  A = 10;
  B = A * 2;
  C = B + A;
function Double(X: Integer): Integer;
begin
  Double := X * 2;
end;
var
  X: Integer;
  Y: Integer;
begin
  X := Double(A);
  Y := B + C;
end.
