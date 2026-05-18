program Property_access_pass;

{$mode objfpc}{$H+}

type
  TItem = class
  private
    FName: string;
    FValue: Integer;
    FItems: array of TItem;
    function GetItem(Index: Integer): TItem;
    procedure SetItem(Index: Integer; AItem: TItem);
    function GetCount: Integer;
  public
    constructor Create(const AName: string; AValue: Integer);
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Value: Integer read FValue write FValue;
    property Items[Index: Integer]: TItem read GetItem write SetItem; default;
    property Count: Integer read GetCount;
  end;

constructor TItem.Create(const AName: string; AValue: Integer);
begin
  FName := AName;
  FValue := AValue;
  SetLength(FItems, 0);
end;

destructor TItem.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(FItems) - 1 do
    FItems[I].Free;
  SetLength(FItems, 0);
  inherited Destroy;
end;

function TItem.GetItem(Index: Integer): TItem;
begin
  Result := FItems[Index];
end;

procedure TItem.SetItem(Index: Integer; AItem: TItem);
begin
  FItems[Index] := AItem;
end;

function TItem.GetCount: Integer;
begin
  Result := Length(FItems);
end;

var
  Root: TItem;
begin
  Root := TItem.Create('root', 0);
  Root.Name := 'Root';
  Root.Value := 42;
  Root.Free;
end.
