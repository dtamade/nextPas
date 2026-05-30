program llvm_try_finally;
begin
  try
    WriteLn('try');
  finally
    WriteLn('finally');
  end;
  WriteLn('done');
end.
