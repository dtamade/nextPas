program Llvm_class_oop_pattern;
type
  TAnimal = class
    FAge: Integer;
    constructor Create(AAge: Integer);
    function Sound: Integer; virtual;
    function Info: Integer;
  end;
  TCat = class(TAnimal)
    FLives: Integer;
    constructor Create(AAge, ALives: Integer);
    function Sound: Integer; override;
  end;

constructor TAnimal.Create(AAge: Integer);
begin
  FAge := AAge;
end;

function TAnimal.Sound: Integer;
begin
  Sound := 0;
end;

function TAnimal.Info: Integer;
begin
  Info := FAge + Sound;
end;

constructor TCat.Create(AAge, ALives: Integer);
begin
  inherited Create(AAge);
  FLives := ALives;
end;

function TCat.Sound: Integer;
begin
  Sound := FLives;
end;

var
  A: TAnimal;
begin
  A := TCat.Create(30, 12);
  Halt(A.Info);
end.
