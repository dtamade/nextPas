program WhileSum;

var
  i, sum: Integer;

begin
  sum := 0;
  i := 1;
  while i <= 5 do
  begin
    sum := sum + i;
    i := i + 1;
  end;
  Halt(sum);
end.
