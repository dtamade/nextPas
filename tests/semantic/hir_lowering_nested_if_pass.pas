{ objfpc}{+}
program hir_lowering_nested_if_pass;
var A,B,C,R: Integer;
begin
  A:=1; B:=2; C:=3;
  if A<B then if B<C then R:=1 else R:=2 else R:=3;
  if R<>1 then Halt(1);
end.
