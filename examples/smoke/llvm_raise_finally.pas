program llvm_raise_finally;
begin
  try
    try
      WriteLn('try');
      raise;
      WriteLn('unreachable');
    finally
      WriteLn('finally');
    end;
  except
  end;
  Halt(42);
end.
