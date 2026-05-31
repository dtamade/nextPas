program IncompatibleReturn;
function Foo: Integer;
begin
  Result := 'hello';
end;
begin
  Foo;
end.
