{ objfpc}{+}
program string_ownership_inttostr_pass;
var S: string; I: Integer;
begin
  I:=42;
  Str(I, S);
  if S<>'42' then Halt(1);
  I:=-100;
  Str(I, S);
  if S<>'-100' then Halt(2);
end.
