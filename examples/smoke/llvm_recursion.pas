program llvm_recursion;

function Fib(N: Integer): Integer;
begin
  if N <= 1 then
    Result := N
  else
    Result := Fib(N - 1) + Fib(N - 2);
end;

function GCD(A, B: Integer): Integer;
begin
  if B = 0 then
    Result := A
  else
    Result := GCD(B, A mod B);
end;

begin
  Halt(Fib(8) + GCD(21, 0));
end.
