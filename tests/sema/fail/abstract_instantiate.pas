program AbstractInstantiate;
type
  TBase = class
    function Foo: Integer; virtual; abstract;
  end;
var B: TBase;
begin
  B := TBase.Create;
end.
