{$mode objfpc}{$H+}
program constfold_edge_pass;

{ 常量折叠边界测试：极端值和复杂嵌套 }

var
  R: Integer;
begin
  R := 0 * 99999;      if R <> 0 then Halt(1);
  R := 0 div 1;        if R <> 0 then Halt(2);
  R := 100 + 0;        if R <> 100 then Halt(3);
  R := 1 * 42;         if R <> 42 then Halt(4);
  R := 2147483647 - 1; if R <> 2147483646 then Halt(5);
  R := ((1+2)*(3+4))+((5-2)*(8 div 2));
  if R <> 33 then Halt(6);
end.
