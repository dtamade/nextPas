{$mode objfpc}{$H+}
program parallel_build_regression;

{ 并行编译回归测试：验证并行编译产物与串行编译一致 }

function Fibonacci(N: Integer): Integer;
begin
  if N <= 1 then
    Fibonacci := N
  else
    Fibonacci := Fibonacci(N - 1) + Fibonacci(N - 2);
end;

function Factorial(N: Integer): Integer;
begin
  if N <= 1 then
    Factorial := 1
  else
    Factorial := N * Factorial(N - 1);
end;

function IsPrime(N: Integer): Boolean;
var
  I: Integer;
begin
  if N < 2 then
    Exit(False);
  for I := 2 to N div 2 do
    if N mod I = 0 then
      Exit(False);
  Result := True;
end;

var
  I, Count: Integer;
begin
  { Verify Fibonacci }
  if Fibonacci(0) <> 0 then Halt(1);
  if Fibonacci(10) <> 55 then Halt(2);

  { Verify Factorial }
  if Factorial(0) <> 1 then Halt(3);
  if Factorial(5) <> 120 then Halt(4);

  { Verify prime counting }
  Count := 0;
  for I := 1 to 100 do
    if IsPrime(I) then
      Inc(Count);
  if Count <> 25 then Halt(5);
end.
