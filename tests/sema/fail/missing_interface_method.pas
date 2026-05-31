program MissingInterfaceMethod;
type
  IFoo = interface
    function Bar: Integer;
    procedure Baz;
  end;
  TFoo = class(TInterfacedObject, IFoo)
    function Bar: Integer;
  end;
function TFoo.Bar: Integer;
begin
  Result := 0;
end;
begin
end.
