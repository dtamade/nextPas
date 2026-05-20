program Llvm_enum_case;
type
  TDirection = (North, East, South, West);

function DirScore(D: Integer): Integer;
begin
  case D of
    North: DirScore := 1;
    East: DirScore := 2;
    South: DirScore := 3;
    West: DirScore := 4;
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
