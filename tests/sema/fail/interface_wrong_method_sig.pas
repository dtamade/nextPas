program InterfaceWrongMethodSig;
type
  ICalc = interface
    function Add(A, B: Integer): Integer;
  end;
  TCalc = class(TInterfacedObject, ICalc)
    function Add(A: Integer): Integer;
  end;
function TCalc.Add(A: Integer): Integer;
begin Result := A; end;
begin
end.
