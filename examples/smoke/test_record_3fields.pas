program Test_record_3fields;
type
  TVec3 = record
    X: Integer;
    Y: Integer;
    Z: Integer;
  end;
var
  V: TVec3;
begin
  V.X := 5;
  V.Y := 10;
  V.Z := 15;
  Halt(V.X + V.Y + V.Z);
end.
