program Type_decl_pass;
type
  TDirection = (dirNorth, dirSouth, dirEast, dirWest);
  TPoint = record
    X: Integer;
    Y: Integer;
  end;
  PPoint = ^TPoint;
var
  D: TDirection;
  P: TPoint;
begin
  D := dirNorth;
  P.X := 1;
  P.Y := 2;
end.
