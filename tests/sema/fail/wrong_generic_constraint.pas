program WrongGenericConstraint;
type
  generic TList<T: record> = class
    FItem: T;
  end;
  TFoo = class
  end;
var L: specialize TList<TFoo>;
begin
end.
