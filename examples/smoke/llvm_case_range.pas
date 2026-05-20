program Llvm_case_range;

function Classify(X: Integer): Integer;
begin
  case X of
    0..9: Classify := 1;
    10..19: Classify := 2;
    20, 25, 30: Classify := 3;
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
