program Llvm_enum_case;
type
  TDirection = (North, East, South, West);

function DirScore(D: Integer): Integer;
begin
  case D of
    North: DirScore := 10;
    East: DirScore := 11;
    South: DirScore := 12;
    West: DirScore := 9;
  else
    DirScore := 0;
  end;
end;

var
  Total: Integer;
begin
  Total := DirScore(North) + DirScore(East) + DirScore(South) + DirScore(West);
  Halt(Total);
end.
