program DuplicateMethod;
type
  TFoo = class
    procedure Bar;
    procedure Bar;
  end;
procedure TFoo.Bar; begin end;
begin
end.
