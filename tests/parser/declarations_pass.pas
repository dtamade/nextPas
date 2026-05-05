program Declarations_pass;
var
  X: Integer;
  Y: Double;
const
  Max = 100;
  Greeting = 'hello';
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
  X := Add(1, 2);
  PrintNothing;
end.
