{ objfpc}{+}
program comprehensive_recursion_pass;
function Factorial(N: Integer): Integer;
begin
  if N<=1 then Factorial:=1
  else Factorial:=N*Factorial(N-1);
end;
function Fib(N: Integer): Integer;
begin
  if N<=1 then Fib:=N
  else Fib:=Fib(N-1)+Fib(N-2);
end;
begin
  if Factorial(5)<>120 then Halt(1);
  if Factorial(0)<>1 then Halt(2);
  if Fib(6)<>8 then Halt(3);
  if Fib(0)<>0 then Halt(4);
end.
