{ objfpc}{+}
program string_ownership_upcase_pass;
var S: string;
begin
  S:='hello';
  S:=UpCase(S);
  if S<>'HELLO' then Halt(1);
end.
