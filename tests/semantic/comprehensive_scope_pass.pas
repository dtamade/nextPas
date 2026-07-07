{ objfpc}{+}
program comprehensive_scope_pass;
var G: Integer;
procedure Outer;
var L: Integer;
  procedure Inner;
  begin
    L:=G+1;
  end;
begin
  G:=5; L:=0;
  Inner;
  if L<>6 then Halt(1);
end;
begin
  G:=0;
  Outer;
  if G<>5 then Halt(2);
end.
