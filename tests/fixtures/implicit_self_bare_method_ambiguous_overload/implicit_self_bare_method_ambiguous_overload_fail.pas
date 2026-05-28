program ImplicitSelfBareMethodAmbiguousOverloadFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: LongInt);
    procedure Run;
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: LongInt);
begin
end;

procedure TWorker.Run;
begin
  Pick(1);
end;

begin
end.
