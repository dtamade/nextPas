program ImplicitSelfBareMethodTypeMismatchFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Run;
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Run;
begin
  Pick(True);
end;

begin
end.
