program Llvm_is_operator;
type
  TAnimal = class
    constructor Create;
    function Kind: Integer; virtual;
  end;
  TDog = class(TAnimal)
    function Kind: Integer; override;
  end;
  TCat = class(TAnimal)
    function Kind: Integer; override;
  end;
constructor TAnimal.Create;
begin
end;
function TAnimal.Kind: Integer;
begin
  Kind := 0;
end;
function TDog.Kind: Integer;
begin
  Kind := 1;
end;
function TCat.Kind: Integer;
begin
  Kind := 2;
end;
var
  A: TAnimal;
  R: Integer;
begin
  A := TDog.Create;
  R := 0;
  if A is TDog then R := R + 32;
  if A is TCat then R := R + 100;
  if A is TAnimal then R := R + 10;
  Halt(R);
end.
