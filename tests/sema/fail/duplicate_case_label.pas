program DuplicateCaseLabel;
var X: Integer;
begin
  X := 1;
  case X of
    1: X := 10;
    1: X := 20;
  end;
end.
