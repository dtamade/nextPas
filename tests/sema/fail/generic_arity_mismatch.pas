program GenericArityMismatch;
type
  generic TBox<T> = class
    FVal: T;
  end;
var
  B: specialize TBox<Integer, String>;
begin
end.
