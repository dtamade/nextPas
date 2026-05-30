program llvm_for_loop;

function Factorial(N: Integer): Integer;
var
  I, R: Integer;
begin
  R := 1;
  for I := 2 to N do
    R := R * I;
  Result := R;
end;

function SumRange(A, B: Integer): Integer;
var
  I, S: Integer;
begin
  S := 0;
  for I := A to B do
    S := S + I;
  Result := S;
end;

begin
  Halt(Factorial(5) + SumRange(1, 4));
end.
