program Llvm_dynarray;
var
  A: array of Integer;
  I: Integer;
  Sum: Integer;
begin
  SetLength(A, 5);
  A[0] := 10;
  A[1] := 20;
  A[2] := 30;
  A[3] := 40;
  A[4] := 50;
  Sum := 0;
  I := 0;
  while I < Length(A) do
  begin
    Sum := Sum + A[I];
    I := I + 1;
  end;
  Halt(Sum div 10);
end.
