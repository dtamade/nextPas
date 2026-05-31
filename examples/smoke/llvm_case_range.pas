program Llvm_case_range;

function Classify(X: Integer): Integer;
begin
  case X of
    0..9: Classify := 10;
    10..19: Classify := 20;
    20, 25, 30: Classify := 12;
  else
    Classify := 0;
  end;
end;

var
  Score: Integer;
begin
  Score := Classify(5) + Classify(15) + Classify(25) + Classify(99);
  Halt(Score);
end.
