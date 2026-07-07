program for_downto_pass;

var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 10 downto 1 do
    Sum := Sum + I;
end.
