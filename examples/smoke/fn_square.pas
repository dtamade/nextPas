program FnSquare;

function Square(x: Integer): Integer;
begin
  Square := x * x;
end;

begin
  Halt(Square(7));
end.
