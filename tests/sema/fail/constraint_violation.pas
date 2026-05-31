program ConstraintViolation;
type
  generic TContainer<T: class> = class
    FVal: T;
  end;
var
  C: specialize TContainer<Integer>;
begin
end.
