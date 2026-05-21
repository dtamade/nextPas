program Llvm_result_var;

function Factorial(N: Integer): Integer;
var
  I: Integer;
begin
  Result := 1;
  I := 2;
  while I <= N do
  begin
    Result := Result * I;
    I := I + 1;
  end;
end;

function Max(A, B: Integer): Integer;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

begin
  Halt(Max(Factorial(4), Factorial(3)));
end.
