program loop_nested_pass;

var
  I, J, Sum: Integer;
begin
  Sum := 0;
  for I := 1 to 10 do
    for J := 1 to I do
      Sum := Sum + J;
end.
