program Llvm_exit_func;

function SumUntil(Limit: Integer): Integer;
var
  I: Integer;
begin
  Result := 6;
  I := 1;
  while I <= 100 do
  begin
    if Result + I > Limit then
      Exit;
    Result := Result + I;
    Inc(I);
  end;
end;

begin
  Halt(SumUntil(44));
end.
