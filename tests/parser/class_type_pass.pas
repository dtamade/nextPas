program Class_type_pass;

{$mode objfpc}{$H+}

type
  TAnimal = class
  private
    FName: string;
    FAge: Integer;
  public
    constructor Create(const AName: string; AAge: Integer);
    destructor Destroy; override;
    procedure Speak; virtual;
    function GetName: string;
    property Name: string read FName;
    property Age: Integer read FAge write FAge;
  end;

  TDog = class(TAnimal)
  public
    procedure Speak; override;
  end;

constructor TAnimal.Create(const AName: string; AAge: Integer);
begin
  FName := AName;
  FAge := AAge;
end;

destructor TAnimal.Destroy;
begin
  inherited Destroy;
end;

procedure TAnimal.Speak;
begin
end;

function TAnimal.GetName: string;
begin
  Result := FName;
end;

procedure TDog.Speak;
begin
end;

var
  D: TDog;
begin
  D := TDog.Create('Rex', 3);
  D.Speak;
  D.Free;
end.
