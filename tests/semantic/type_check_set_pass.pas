{$mode objfpc}{$H+}
program type_check_set_pass;

{ 类型检查：集合操作 }

type
  TDaySet = set of 1..7;

var
  Days: TDaySet;
  B: Boolean;
begin
  Days := [1, 3, 5];
  B := 1 in Days;
  if not B then Halt(1);
  B := 2 in Days;
  if B then Halt(2);

  Days := Days + [7];
  B := 7 in Days;
  if not B then Halt(3);

  Days := Days - [3];
  B := 3 in Days;
  if B then Halt(4);
end.
