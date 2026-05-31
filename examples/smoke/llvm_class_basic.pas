program Llvm_class_basic;
type
  TCounter = class
    FValue: Integer;
    constructor Create(AInit: Integer);
    function GetValue: Integer;
    procedure Increment;
  end;

constructor TCounter.Create(AInit: Integer);
begin
  FValue := AInit;
end;

function TCounter.GetValue: Integer;
begin
  GetValue := FValue;
end;

procedure TCounter.Increment;
begin
  FValue := FValue + 1;
end;

var
  C: TCounter;
begin
  C := TCounter.Create(39);
  C.Increment;
  C.Increment;
  C.Increment;
  Halt(C.GetValue);
end.
