program ForSumHalt;

var
  i, sum: Integer;

begin
  sum := 0;
  for i := 1 to 5 do
    sum := sum + i;
  Halt(sum);
end.
