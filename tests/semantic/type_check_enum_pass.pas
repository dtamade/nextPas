{$mode objfpc}{$H+}
program type_check_enum_pass;

{ 类型检查：枚举类型 }

type
  TColor = (Red, Green, Blue);
  TSize = (Small, Medium, Large);

var
  C: TColor;
  S: TSize;
  I: Integer;
begin
  C := Red;
  if Ord(C) <> 0 then Halt(1);
  C := Green;
  if Ord(C) <> 1 then Halt(2);
  C := Blue;
  if Ord(C) <> 2 then Halt(3);

  S := Small;
  if S <> Small then Halt(4);
  S := Large;
  if Ord(S) <> 2 then Halt(5);
end.
