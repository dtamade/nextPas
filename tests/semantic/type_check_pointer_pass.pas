{$mode objfpc}{$H+}
program type_check_pointer_pass;

{ 类型检查：指针操作 }

type
  PInt = ^Integer;

var
  X: Integer;
  P: PInt;
begin
  X := 42;
  P := @X;
  if P^ <> 42 then Halt(1);

  P^ := 100;
  if X <> 100 then Halt(2);
end.
