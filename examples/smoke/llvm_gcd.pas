program Llvm_gcd;
function GCD(A, B: Integer): Integer;
begin
  while B <> 0 do
  begin
    GCD := B;
    B := A mod B;
    A := GCD;
  end;
  GCD := A;
end;
begin
  Halt(GCD(48, 18));
end.
