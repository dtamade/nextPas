program FnConstHalt;

function GetVal: Integer;
begin
  GetVal := 42;
end;

begin
  Halt(GetVal);
end.
