program ClassMissingConstructor;
type
  TFoo = class
    FVal: Integer;
    function GetVal: Integer; virtual;
  end;
function TFoo.GetVal: Integer; begin Result := FVal; end;
var F: TFoo;
begin
  F := TFoo.Create(42);
end.
