program ImplicitSelfBareMethodNoMatchingOverloadFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: AnsiString);
    procedure Run;
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: AnsiString);
begin
end;

procedure TWorker.Run;
begin
  Pick(True);
end;

begin
end.
