program FnCompose;

function Base: Integer;
begin
  Base := 7;
end;

function Doubled: Integer;
begin
  Doubled := Base * 2;
end;

begin
  Halt(Doubled);
end.
