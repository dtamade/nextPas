program Llvm_method_inc;
type
  TCounter = class
    FVal: Integer;
    constructor Create;
    procedure Increment;
    function GetVal: Integer;
  end;

constructor TCounter.Create;
begin
  FVal := 0;
end;

procedure TCounter.Increment;
begin
  Inc(FVal);
end;

function TCounter.GetVal: Integer;
begin
  Result := FVal;
end;

var
  C: TCounter;
begin
  C := TCounter.Create;
  C.Increment;
  C.Increment;
  C.Increment;
  Halt(C.GetVal);
end.
