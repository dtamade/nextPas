program WrongArgumentCount;
function Add(A, B: Integer): Integer;
begin
  Result := A + B;
end;
begin
  Add(1, 2, 3);
end.
