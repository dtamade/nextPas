program Operators_pass;
var
  x: Integer;
begin
  x := 1 + 2;
  x := 3 - 4;
  x := 5 * 6;
  x := 8 div 2;
  x := 7 mod 3;
  x := 8 shr 1;
  x := 8 shl 1;
  if (x <> 0) and (x > 0) or not (x = 0) then
    x := 1;
  if (x <= 5) or (x >= 10) then
    x := 2;
  x := x + 1;
  x += 1;
  x -= 1;
end.
