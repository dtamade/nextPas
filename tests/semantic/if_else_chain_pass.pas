program if_else_chain_pass;

var
  X, Y: Integer;
begin
  X := 42;
  if X > 100 then
    Y := 1
  else if X > 50 then
    Y := 2
  else if X > 0 then
    Y := 3
  else
    Y := 0;
end.
