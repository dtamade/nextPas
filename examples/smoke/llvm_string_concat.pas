program Llvm_string_concat;
var
  A: String;
  B: String;
  C: String;
begin
  A := 'Hello';
  B := ' World';
  C := A + B;
  WriteLn(C);
  Halt(Length(C));
end.
