program test_intf_proc;
type
  ICounter = interface
    function GetVal: Integer;
    procedure Inc;
  end;
  TCounter = class(TInterfacedObject, ICounter)
    FVal: Integer;
    constructor Create;
    function GetVal: Integer;
    procedure Inc;
  end;

constructor TCounter.Create;
begin
  FVal := 0;
end;

function TCounter.GetVal: Integer;
begin
  Result := FVal;
end;

procedure TCounter.Inc;
begin
  FVal := FVal + 1;
end;

var
  C: ICounter;
begin
  C := TCounter.Create;
  C.Inc;
  C.Inc;
  C.Inc;
  Halt(C.GetVal);
end.
