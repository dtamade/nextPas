program const_string_pass;

const
  Greeting = 'Hello World';
  Prefix = 'Mr. ';
  FullName = Prefix + 'Smith';

var
  S: string;
begin
  S := Greeting;
  S := FullName;
end.
