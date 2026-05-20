program Interface_type_pass;

{$mode objfpc}{$H+}

type
  IAnimal = interface
    procedure Speak;
    function GetName: string;
    property Name: string read GetName;
  end;

  IDomestic = interface(IAnimal)
    procedure SetOwner(const AOwner: string);
  end;

  TDog = class(TInterfacedObject, IAnimal)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    procedure Speak;
    function GetName: string;
    property Name: string read GetName;
  end;

constructor TDog.Create(const AName: string);
begin
  FName := AName;
end;

procedure TDog.Speak;
begin
end;

function TDog.GetName: string;
begin
  Result := FName;
end;

var
  D: TDog;
begin
  D := TDog.Create('Rex');
  D.Speak;
  D.Free;
end.
