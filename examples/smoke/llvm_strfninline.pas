program Llvm_strfninline;

function Greeting: String;
begin
  Greeting := 'Hello World';
end;

begin
  WriteLn(Greeting);
  Halt(Length(Greeting) + 31);
end.
