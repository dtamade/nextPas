{ objfpc}{+}
program hir_lowering_shortcircuit_pass;
function SideEffect(var X: Integer): Boolean;
begin X:=X+1; SideEffect:=True; end;
var A: Integer; B: Boolean;
begin
  A:=0;
  B:=False and SideEffect(A);
  if A<>0 then Halt(1);
  B:=True or SideEffect(A);
  if A<>0 then Halt(2);
end.
