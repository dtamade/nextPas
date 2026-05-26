program NoMatchingOverloadFail;

procedure Pick(Value: Integer);
begin
end;

procedure Pick(Value: AnsiString);
begin
end;

begin
  Pick(True);
end.
