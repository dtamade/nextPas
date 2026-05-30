program llvm_boolean;
var
  B: Boolean;
  X: Integer;
begin
  B := True;
  X := 0;
  if B then X := 10;
  B := False;
  if B then X := 99;
  if not B then X := X + 5;
  Halt(X);
end.
