program test_poly_override;
type
  TAnimal = class
    constructor Create;
    function Sound: Integer; virtual;
    function Legs: Integer; virtual;
  end;
  TDog = class(TAnimal)
    constructor Create;
    function Sound: Integer; override;
    function Legs: Integer; override;
  end;
  TCat = class(TAnimal)
    constructor Create;
    function Sound: Integer; override;
    function Legs: Integer; override;
  end;

constructor TAnimal.Create; begin end;
constructor TDog.Create; begin end;
constructor TCat.Create; begin end;

function TAnimal.Sound: Integer; begin Result := 0; end;
function TAnimal.Legs: Integer; begin Result := 0; end;
function TDog.Sound: Integer; begin Result := 1; end;
function TDog.Legs: Integer; begin Result := 4; end;
function TCat.Sound: Integer; begin Result := 2; end;
function TCat.Legs: Integer; begin Result := 8; end;

function Score(A: TAnimal): Integer;
begin
  Result := A.Sound * 10 + A.Legs;
end;

var D: TDog; C: TCat;
begin
  D := TDog.Create;
  C := TCat.Create;
  Halt(Score(D) + Score(C));
end.
