{ objfpc}{+}
program hir_lowering_logic_pass;
var A,B: Boolean; R: Boolean;
begin
  A:=True; B:=False;
  R:=A and B; if R then Halt(1);
  R:=A or B; if not R then Halt(2);
  R:=not (A and B); if not R then Halt(3);
end.
