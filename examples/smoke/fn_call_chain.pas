program FnCallChain;

function Base: Integer;
begin
  Base := 5;
end;

function Doubled: Integer;
begin
  Doubled := Base() * 2;
end;

function Tripled: Integer;
begin
  Tripled := Doubled() + Base();
end;

begin
  Halt(Tripled());
end.
