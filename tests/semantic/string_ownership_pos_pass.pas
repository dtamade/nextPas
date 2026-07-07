{$mode objfpc}{$H+}
program string_ownership_pos_pass;

{ 字符串所有权：Pos 查找 }

var
  S, Sub: string;
  P: Integer;
begin
  S := 'Hello World';
  P := Pos('World', S);
  if P <> 7 then Halt(1);

  P := Pos('Hello', S);
  if P <> 1 then Halt(2);

  P := Pos('X', S);
  if P <> 0 then Halt(3);

  Sub := 'lo';
  P := Pos(Sub, S);
  if P <> 4 then Halt(4);
end.
