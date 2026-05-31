program Llvm_strparam;

function StrLen(S: String): Integer;
begin
  StrLen := Length(S);
end;

procedure PrintStr(S: String);
begin
  WriteLn(S);
end;

var
  Greeting: String;
  L: Integer;
begin
  Greeting := 'Hello';
  PrintStr(Greeting);
  L := StrLen(Greeting);
  Halt(L + 37);
end.
