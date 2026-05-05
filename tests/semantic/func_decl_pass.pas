program Func_decl_pass;
function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;
var
  Result: Integer;
begin
  Result := Add(1, 2);
end.
