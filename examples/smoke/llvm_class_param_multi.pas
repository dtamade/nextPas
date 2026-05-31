program llvm_class_param_multi;
type
  TAnimal = class
    FLegs: Integer;
    constructor Create(L: Integer);
    function GetLegs: Integer; virtual;
  end;
  TDog = class(TAnimal)
    constructor Create;
    function GetLegs: Integer; override;
  end;
  TCat = class(TAnimal)
    constructor Create;
  end;

constructor TAnimal.Create(L: Integer);
begin
  FLegs := L;
end;

function TAnimal.GetLegs: Integer;
begin
  Result := FLegs;
end;

constructor TDog.Create;
begin
  FLegs := 4;
end;

function TDog.GetLegs: Integer;
begin
  Result := FLegs + 1;
end;

constructor TCat.Create;
begin
  FLegs := 4;
end;

function CountLegs(A, B, C: TAnimal): Integer;
begin
  Result := A.GetLegs + B.GetLegs + C.GetLegs;
end;

var
  D: TDog;
  C: TCat;
  A: TAnimal;
begin
  D := TDog.Create;
  C := TCat.Create;
  A := TAnimal.Create(33);
  Halt(CountLegs(D, C, A));
end.
