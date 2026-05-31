program DuplicateInterfaceImpl;
type
  IFoo = interface
    function Get: Integer;
  end;
  TBar = class(TInterfacedObject, IFoo, IFoo)
    function Get: Integer;
  end;
function TBar.Get: Integer; begin Result := 0; end;
begin
end.
