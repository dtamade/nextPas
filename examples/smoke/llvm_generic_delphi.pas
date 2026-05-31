program llvm_generic_delphi;

function Max<T>(A, B: T): T;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Add<T>(A, B: T): T;
begin
  Result := A + B;
end;

begin
  Halt(Max<Integer>(Add<Integer>(10, 32), 30));
end.
