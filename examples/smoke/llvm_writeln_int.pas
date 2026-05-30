program llvm_writeln_int;
function Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;

function Mul(A, B: Integer): Integer;
begin
  Result := A * B;
end;

var
  X: Integer;
begin
  X := Add(3, 4);
  WriteLn(X);
  WriteLn(Mul(5, 6));
  Halt(X + Mul(2, 3));
end.
