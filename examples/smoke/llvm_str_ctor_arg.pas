program Llvm_str_ctor_arg;
type
  TObj = class
    FName: String;
    constructor Create(AName: String);
    function GetLen: Integer; virtual;
  end;

constructor TObj.Create(AName: String);
begin
  FName := AName;
end;

function TObj.GetLen: Integer;
begin
  Result := Length(FName);
end;

var
  O: TObj;
begin
  O := TObj.Create('Hello');
  Halt(O.GetLen);
end.
