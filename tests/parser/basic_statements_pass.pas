program Basic_statements_pass;
var
  X: Integer;
  S: string;
begin
  X := 1;
  X := X + 2;
  if X > 0 then
    X := X + 10;
  while X > 0 do
    X := X - 1;
  for X := 1 to 5 do
    S := 'ok';
  repeat
    X := X - 1;
  until X <= 0;
end.
