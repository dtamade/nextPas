{$mode objfpc}{$H+}
program string_ownership_length_pass;

{ 字符串所有权：Length/Copy 操作 }

var
  S, Sub: string;
  L: Integer;
begin
  S := 'Hello World';
  L := Length(S);
  if L <> 11 then Halt(1);

  Sub := Copy(S, 1, 5);
  if Sub <> 'Hello' then Halt(2);

  Sub := Copy(S, 7, 5);
  if Sub <> 'World' then Halt(3);

  S := '';
  L := Length(S);
  if L <> 0 then Halt(4);
end.
