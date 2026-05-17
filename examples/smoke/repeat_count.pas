program RepeatCount;

var
  i: Integer;

begin
  i := 1;
  repeat
    WriteLn(i);
    i := i + 1;
  until i > 3;
end.
