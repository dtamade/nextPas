program llvm_case_default;
function Classify(X: Integer): Integer;
begin
  case X of
    1..5: Result := 1;
    6..10: Result := 2;
    11..20: Result := 3;
  else
    Result := 0;
  end;
end;
begin
  Halt(Classify(3) + Classify(8) + Classify(15) + Classify(99));
end.
