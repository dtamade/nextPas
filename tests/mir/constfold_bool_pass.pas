{$mode objfpc}{$H+}
program constfold_bool_pass;

{ 验证常量折叠：布尔表达式在编译期求值 }

var
  B: Boolean;
begin
  B := True and True;   if not B then Halt(1);
  B := False or True;   if not B then Halt(2);
  B := not False;       if not B then Halt(3);
  B := 5 > 3;           if not B then Halt(4);
  B := (2 < 4) and (10 >= 5) and (3 <> 7);  if not B then Halt(5);
end.
