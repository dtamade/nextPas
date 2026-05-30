program llvm_interface_full;
type
  IAdder = interface
    procedure Add(Value: Integer);
    function GetSum: Integer;
  end;
  TAdder = class(TObject, IAdder)
    FSum: Integer;
    constructor Create;
    procedure Add(Value: Integer);
    function GetSum: Integer;
  end;

constructor TAdder.Create;
begin
  FSum := 0;
end;

procedure TAdder.Add(Value: Integer);
begin
  FSum := FSum + Value;
end;

function TAdder.GetSum: Integer;
begin
  GetSum := FSum;
end;

var
  A: IAdder;
  I: Integer;
begin
  A := TAdder.Create;
  for I := 1 to 10 do
    A.Add(I);
  Halt(A.GetSum);
end.
