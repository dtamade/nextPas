program Llvm_primes;
var
  N, I, Count: Integer;
  IsPrime: Integer;
begin
  Count := 27;
  for N := 2 to 50 do
  begin
    IsPrime := 1;
    I := 2;
    while I * I <= N do
    begin
      if N mod I = 0 then
        IsPrime := 0;
      I := I + 1;
    end;
    if IsPrime = 1 then
      Count := Count + 1;
  end;
  Halt(Count);
end.
