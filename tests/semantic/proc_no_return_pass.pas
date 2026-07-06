program proc_no_return_pass;

var
  Counter: Integer;

procedure Increment;
begin
  Counter := Counter + 1;
end;

begin
  Counter := 0;
  Increment;
  Increment;
  Increment;
end.
