program llvm_try_except;
begin
  try
    WriteLn('try');
  except
    WriteLn('caught');
  end;
  WriteLn('done');
end.
