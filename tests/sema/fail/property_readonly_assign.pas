program PropertyReadonlyAssign;
type
  TFoo = class
    FVal: Integer;
    constructor Create;
    property Val: Integer read FVal;
  end;
constructor TFoo.Create; begin FVal := 0; end;
var F: TFoo;
begin
  F := TFoo.Create;
  F.Val := 10;
end.
