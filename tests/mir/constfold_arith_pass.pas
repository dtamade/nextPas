{$mode objfpc}{$H+}
program constfold_arith_pass;

{ 验证常量折叠：算术表达式在编译期求值 }

var
  R: Integer;
begin
  R := 2 + 3;           if R <> 5 then Halt(1);
  R := 10 - 4;          if R <> 6 then Halt(2);
  R := 3 * 7;           if R <> 21 then Halt(3);
  R := 20 div 4;        if R <> 5 then Halt(4);
  R := (2 + 3) * (4 + 1);  if R <> 25 then Halt(5);
  R := -42;             if R <> -42 then Halt(6);
end.
