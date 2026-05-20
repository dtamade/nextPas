program Llvm_strfncall;

function Repeat2(S: String): String;
begin
  Repeat2 := S + S;
end;

var
  R: String;
begin
  R := Repeat2('Hi');
  WriteLn(R);
  Halt(Length(R));
end.
