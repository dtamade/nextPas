program MethodNotFound;
type
  TFoo = class
    constructor Create;
  end;
constructor TFoo.Create; begin end;
var F: TFoo;
begin
  F := TFoo.Create;
  F.NonExistent;
end.
