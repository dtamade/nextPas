program Llvm_string;
var
  Greet: String;
  Who: String;
  Msg: String;
  L: Integer;
begin
  Greet := 'Hello';
  Who := 'World';
  Msg := Greet;
  L := Length(Greet) + Length(Who);
  WriteLn(Greet);
  WriteLn(Who);
  WriteLn(Msg);
  Halt(L + 32);
end.
