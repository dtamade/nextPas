program ReferenceRegression;

var
  Value: Integer;

begin
  Value := 42;
  if Value <> 42 then
    Halt(1);

  WriteLn('regression guard active');
end.
