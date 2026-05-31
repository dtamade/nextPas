program llvm_try_finally;
begin
  try
    WriteLn('try');
  finally
    WriteLn('finally');
  end;
  WriteLn('done');
  Halt(42);
  Halt(42);
end.
