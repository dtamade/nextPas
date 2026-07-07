{ objfpc}{+}
program hir_lowering_neg_pass;
var X,R: Integer;
begin
  X:=5; R:=-X; if R<>-5 then Halt(1);
  X:=-10; R:=-X; if R<>10 then Halt(2);
  X:=0; R:=-X; if R<>0 then Halt(3);
end.
