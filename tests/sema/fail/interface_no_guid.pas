program InterfaceNoGuid;
type
  IFoo = interface
    function Bar: Integer;
  end;
  TFoo = class(TObject, IFoo)
    function Bar: Integer;
  end;
function TFoo.Bar: Integer; begin Result := 0; end;
begin
end.
