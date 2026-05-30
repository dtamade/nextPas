program llvm_nested_raise;
begin
  try
    WriteLn('outer-try');
    try
      WriteLn('inner-try');
      raise;
      WriteLn('unreachable');
    finally
      WriteLn('inner-finally');
    end;
    WriteLn('unreachable2');
  except
    WriteLn('outer-caught');
  end;
  WriteLn('done');
end.
