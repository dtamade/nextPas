program Declarations_pass;
var
  x: Integer;
const
  Max = 100;
type
  TRec = record
    A: Integer;
    B: Double;
  end;
function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;
procedure PrintNothing;
begin
end;
begin
  x := Add(1, 2);
  PrintNothing;
end.
