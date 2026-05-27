program InheritedImplicitSelfBareMethodAmbiguousOverloadFail;

type
  TBaseWorker = class
    procedure Touch(Value: Integer);
    procedure Touch(Value: LongInt);
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

procedure TBaseWorker.Touch(Value: Integer);
begin
end;

procedure TBaseWorker.Touch(Value: LongInt);
begin
end;

procedure TWorker.Run;
begin
  Touch(1);
end;

begin
end.
