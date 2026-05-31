program test_str_concat_func;

function Greet(Name: String): String;
begin
  Result := 'Hi ' + Name;
end;

var S: String;
begin
  S := Greet('World');
  WriteLn(S);
  Halt(Length(S) + 34);
end.
