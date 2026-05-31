program AmbiguousOverload;
procedure Foo(X: Integer); overload;
begin end;
procedure Foo(X: Integer); overload;
begin end;
begin
  Foo(1);
end.
