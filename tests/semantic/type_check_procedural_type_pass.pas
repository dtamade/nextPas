{ objfpc}{+}
program type_check_procedural_type_pass;
type TIntFunc=function(X: Integer): Integer;
function Double(X: Integer): Integer;
begin Double:=X*2; end;
var F: TIntFunc; R: Integer;
begin
  F:=@Double;
  R:=F(21);
  if R<>42 then Halt(1);
end.
