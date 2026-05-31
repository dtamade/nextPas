program NestedGenericMismatch;
type
  generic TBox<T> = class
    FVal: T;
  end;
  generic TWrapper<U> = class
    FInner: specialize TBox<U, Integer>;
  end;
begin
end.
