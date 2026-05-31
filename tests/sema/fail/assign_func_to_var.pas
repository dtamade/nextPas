program AssignFuncToVar;
function Foo: Integer;
begin Result := 1; end;
var X: Integer;
begin
  Foo := 10;
end.
