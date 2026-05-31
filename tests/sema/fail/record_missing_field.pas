program RecordMissingField;
type
  TPoint = record
    X, Y: Integer;
  end;
var P: TPoint;
begin
  P.Z := 10;
end.
