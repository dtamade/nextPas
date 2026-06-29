program classref_create_pass;
{$mode ObjFPC}{$H+}

type
  TAnimal = class
    FName: string;
    constructor Create(const AName: string);
    function GetName: string;
  end;

  TAnimalClass = class of TAnimal;

  TDog = class(TAnimal)
    constructor Create(const AName: string);
  end;

constructor TAnimal.Create(const AName: string);
begin
  FName := AName;
end;

function TAnimal.GetName: string;
begin
  Result := FName;
end;

constructor TDog.Create(const AName: string);
begin
  inherited Create(AName);
end;

procedure MakeAnimal(AClass: TAnimalClass; const AName: string);
var
  LAnimal: TAnimal;
begin
  LAnimal := AClass.Create(AName);
  WriteLn(LAnimal.GetName);
  LAnimal.Free;
end;

begin
  MakeAnimal(TDog, 'Buddy');
end.
