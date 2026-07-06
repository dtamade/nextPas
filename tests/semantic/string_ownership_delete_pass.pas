{$mode objfpc}{$H+}
program string_ownership_delete_pass;

{ 字符串所有权：Delete 操作 }

var
  S: string;
begin
  S := 'Hello World';
  Delete(S, 6, 6);
  if S <> 'Hello' then Halt(1);

  S := 'abc';
  Delete(S, 2, 1);
  if S <> 'ac' then Halt(2);
end.
