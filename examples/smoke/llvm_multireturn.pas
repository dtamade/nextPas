program llvm_multireturn;
function Clamp(X, Lo, Hi: Integer): Integer;
begin
  if X < Lo then
  begin
    Result := Lo;
    Exit;
  end;
  if X > Hi then
  begin
    Result := Hi;
    Exit;
  end;
  Result := X;
end;
begin
  Halt(Clamp(5, 0, 10) + Clamp(50, 0, 10) + Clamp(27, 0, 30));
end.
