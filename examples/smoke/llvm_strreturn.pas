program Llvm_strreturn;

function Greeting: String;
begin
  Greeting := 'Hello World';
end;

var
  S: String;
begin
  S := Greeting;
  WriteLn(S);
  Halt(Length(S));
end.
