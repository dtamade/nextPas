program while_loop_pass;

var
  I, Sum: Integer;
begin
  I := 10;
  Sum := 0;
  while I > 0 do
  begin
    Sum := Sum + I;
    I := I - 1;
  end;
end.
