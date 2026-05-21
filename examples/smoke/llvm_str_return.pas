program Llvm_str_return;
type
  TObj = class
    FName: String;
    constructor Create(AName: String);
    function GetName: String; virtual;
  end;

constructor TObj.Create(AName: String);
begin
  FName := AName;
end;

function TObj.GetName: String;
begin
  Result := FName;
end;

var
  O: TObj;
  S: String;
begin
  O := TObj.Create('World');
  S := O.GetName;
  Halt(Length(S));
end.
