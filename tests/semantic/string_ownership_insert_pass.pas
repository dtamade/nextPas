{ objfpc}{+}
program string_ownership_insert_pass;
var S: string;
begin
  S:='Hello';
  Insert(' World', S, 6);
  if S<>'Hello World' then Halt(1);
  S:='abc';
  Insert('X', S, 2);
  if S<>'aXbc' then Halt(2);
end.
