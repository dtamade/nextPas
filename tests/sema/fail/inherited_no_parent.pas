program InheritedNoParent;
type
  TRoot = class
    function Foo: Integer; virtual;
  end;
function TRoot.Foo: Integer;
begin
  Result := inherited Foo;
end;
begin
end.
