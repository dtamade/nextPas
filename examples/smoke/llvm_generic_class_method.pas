program test_gm_class;
type
  TUtils = class
    constructor Create;
  end;

constructor TUtils.Create; begin end;

generic function TUtils.Apply<T>(X, Y: T): T;
begin
  Result := X + Y;
end;

var U: TUtils;
begin
  U := TUtils.Create;
  Halt(specialize U.Apply<Integer>(40, 2));
end.
