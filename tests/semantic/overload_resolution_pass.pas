{$mode objfpc}{$H+}
program overload_resolution_pass;

{ 重载解析：精确匹配和类型提升 }

function AddInt(A, B: Integer): Integer;
begin
  AddInt := A + B;
end;

function AddReal(A, B: Real): Real;
begin
  AddReal := A + B;
end;

function AddThree(A, B, C: Integer): Integer;
begin
  AddThree := A + B + C;
end;

var
  I, J: Integer;
  R: Real;
begin
  I := AddInt(1, 2);
  if I <> 3 then Halt(1);
  R := AddReal(1.5, 2.5);
  if Abs(R - 4.0) > 0.001 then Halt(2);
  I := AddThree(1, 2, 3);
  if I <> 6 then Halt(3);
  { 精确匹配：Integer 参数匹配 AddInt }
  I := AddInt(10, 20);
  if I <> 30 then Halt(4);
end.
