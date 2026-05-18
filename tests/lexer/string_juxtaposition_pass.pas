program StringJuxtaposition_pass;
var
  s: string;
begin
  s := 'Hello'#10'World';
  s := 'a'#9'b'#9'c';
  s := #65#66#67;
  s := 'prefix'^M^J;
  s := 'simple';
end.
