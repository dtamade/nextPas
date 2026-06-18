{$mode objfpc}{$H+}
program test_classes_pass;

type
  TAnimal = class
  private
    FName: string;
    FAge: LongInt;
  public
    constructor Create(const AName: string; AAge: LongInt);
    function Speak: string; virtual;
    property Name: string read FName;
    property Age: LongInt read FAge;
  end;

  TDog = class(TAnimal)
  private
    FBreed: string;
  public
    constructor Create(const AName: string; AAge: LongInt; const ABreed: string);
    function Speak: string; override;
  end;

constructor TAnimal.Create(const AName: string; AAge: LongInt);
begin
  FName := AName;
  FAge := AAge;
end;

function TAnimal.Speak: string;
begin
  Result := '...';
end;

constructor TDog.Create(const AName: string; AAge: LongInt; const ABreed: string);
begin
  inherited Create(AName, AAge);
  FBreed := ABreed;
end;

function TDog.Speak: string;
begin
  Result := 'Woof! I am ' + FName;
end;

var
  A: TAnimal;
  D: TDog;
begin
  A := TAnimal.Create('Cat', 3);
  try
    if A.Name <> 'Cat' then Halt(1);
    if A.Age <> 3 then Halt(2);
    if A.Speak <> '...' then Halt(3);
  finally
    A.Free;
  end;

  D := TDog.Create('Rex', 5, 'Shepherd');
  try
    if D.Name <> 'Rex' then Halt(4);
    if D.Speak <> 'Woof! I am Rex' then Halt(5);
    { polymorphism }
    A := D;
    if A.Speak <> 'Woof! I am Rex' then Halt(6);
  finally
    D.Free;
  end;

  WriteLn('classes OK');
end.
