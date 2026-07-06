{ objfpc}{+}
program overload_nested_call_pass;
function Double(X: Integer): Integer;
begin Double:=X*2; end;
function Triple(X: Integer): Integer;
begin Triple:=X*3; end;
var R: Integer;
begin
  R:=Double(Triple(5));
  if R<>30 then Halt(1);
  R:=Triple(Double(7));
  if R<>42 then Halt(2);
end.
