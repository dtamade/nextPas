program Class_of_pass;

{$mode objfpc}{$H+}

type
  TAnimal = class
  public
    constructor Create; virtual;
    function Sound: string; virtual;
  end;

  TAnimalClass = class of TAnimal;

  TDog = class(TAnimal)
  public
    constructor Create; override;
    function Sound: string; override;
  end;

  TCat = class(TAnimal)
  public
    constructor Create; override;
    function Sound: string; override;
  end;

constructor TAnimal.Create;
begin
end;

function TAnimal.Sound: string;
begin
  Result := '';
end;

constructor TDog.Create;
begin
  inherited Create;
end;

function TDog.Sound: string;
begin
  Result := 'Woof';
end;

constructor TCat.Create;
begin
  inherited Create;
end;

function TCat.Sound: string;
begin
  Result := 'Meow';
end;

function MakeAnimal(AClass: TAnimalClass): TAnimal;
begin
  Result := AClass.Create;
end;

var
  A: TAnimal;
begin
  A := MakeAnimal(TDog);
  A.Free;
  A := MakeAnimal(TCat);
  A.Free;
end.
