program Llvm_class_inherit;
type
  TAnimal = class
    FLegs: Integer;
    constructor Create(ALegs: Integer);
    function GetLegs: Integer;
  end;
  TDog = class(TAnimal)
    FTailLength: Integer;
    constructor Create(ALegs, ATail: Integer);
    function GetTotal: Integer;
  end;

constructor TAnimal.Create(ALegs: Integer);
begin
  FLegs := ALegs;
end;

function TAnimal.GetLegs: Integer;
begin
  GetLegs := FLegs;
end;

constructor TDog.Create(ALegs, ATail: Integer);
begin
  FLegs := ALegs;
  FTailLength := ATail;
end;

function TDog.GetTotal: Integer;
begin
  GetTotal := FLegs + FTailLength;
end;

var
  D: TDog;
begin
  D := TDog.Create(4, 38);
  Halt(D.GetTotal);
end.
