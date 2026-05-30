program llvm_raise_finally;
begin
  try
    WriteLn('try');
    raise;
    WriteLn('unreachable');
  finally
    WriteLn('finally');
  end;
  WriteLn('after');
end.
