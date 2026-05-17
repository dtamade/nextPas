program RepeatHalt;

var
  x: Integer;

begin
  x := 0;
  repeat
    x := x + 5;
  until x >= 20;
  Halt(x);
end.
