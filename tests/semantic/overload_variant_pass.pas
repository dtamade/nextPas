{$mode objfpc}{$H+}
program overload_variant_pass;

{ 重载解析：参数数量不同的重载 }

function Sum2(A, B: Integer): Integer;
begin
  Sum2 := A + B;
end;

function Sum3(A, B, C: Integer): Integer;
begin
  Sum3 := A + B + C;
end;

function Sum4(A, B, C, D: Integer): Integer;
begin
  Sum4 := A + B + C + D;
end;

var
  R: Integer;
begin
  R := Sum2(1, 2);
  if R <> 3 then Halt(1);
  R := Sum3(1, 2, 3);
  if R <> 6 then Halt(2);
  R := Sum4(1, 2, 3, 4);
  if R <> 10 then Halt(3);
end.
