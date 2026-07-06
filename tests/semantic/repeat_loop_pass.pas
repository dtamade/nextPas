program repeat_loop_pass;

var
  I, Sum: Integer;
begin
  I := 1;
  Sum := 0;
  repeat
    Sum := Sum + I;
    I := I + 1;
  until I > 10;
end.
