program llvm_raise;
begin
  try
    WriteLn('before');
    raise;
    WriteLn('unreachable');
  except
    WriteLn('caught');
  end;
  WriteLn('after');
end.
