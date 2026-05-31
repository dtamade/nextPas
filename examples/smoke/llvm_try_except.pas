program llvm_try_except;
begin
  try
    WriteLn('try');
  except
    WriteLn('caught');
  end;
  WriteLn('done');
  Halt(42);
  Halt(42);
end.
