{ objfpc}{+}
program comprehensive_fibonacci_pass;
function Fib(N: Integer): Integer;
var A,B,T,I: Integer;
begin
  if N<=1 then Fib:=N
  else begin
    A:=0; B:=1;
    for I:=2 to N do begin T:=A+B; A:=B; B:=T; end;
    Fib:=B;
  end;
end;
begin
  if Fib(0)<>0 then Halt(1);
  if Fib(1)<>1 then Halt(2);
  if Fib(10)<>55 then Halt(3);
  if Fib(20)<>6765 then Halt(4);
end.
