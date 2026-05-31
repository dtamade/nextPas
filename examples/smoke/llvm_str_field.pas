program Llvm_str_field;
type
  TGreeter = class
    FName: String;
    FCount: Integer;
    constructor Create;
    function GetLen: Integer; virtual;
    function GetCount: Integer; virtual;
  end;

constructor TGreeter.Create;
begin
  FName := 'Hello';
  FCount := 37;
end;

function TGreeter.GetLen: Integer;
begin
  Result := Length(FName);
end;

function TGreeter.GetCount: Integer;
begin
  Result := FCount;
end;

var
  G: TGreeter;
  R: Integer;
begin
  G := TGreeter.Create;
  R := G.GetLen + G.GetCount;
  Halt(R);
end.
