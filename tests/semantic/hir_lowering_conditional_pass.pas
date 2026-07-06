{$mode objfpc}{$H+}
program hir_lowering_conditional_pass;

{ HIR lowering：条件表达式 }

function Max(A, B: Integer): Integer;
begin
  if A > B then
    Max := A
  else
    Max := B;
end;

function AbsVal(X: Integer): Integer;
begin
  if X >= 0 then
    AbsVal := X
  else
    AbsVal := -X;
end;

var
  R: Integer;
begin
  R := Max(10, 20);
  if R <> 20 then Halt(1);
  R := Max(-5, -10);
  if R <> -5 then Halt(2);
  R := AbsVal(-42);
  if R <> 42 then Halt(3);
  R := AbsVal(100);
  if R <> 100 then Halt(4);
end.
