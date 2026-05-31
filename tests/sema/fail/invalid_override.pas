program InvalidOverride;
type
  TBase = class
    procedure Foo;
  end;
  TChild = class(TBase)
    procedure Foo; override;
  end;
procedure TBase.Foo; begin end;
procedure TChild.Foo; begin end;
begin
end.
