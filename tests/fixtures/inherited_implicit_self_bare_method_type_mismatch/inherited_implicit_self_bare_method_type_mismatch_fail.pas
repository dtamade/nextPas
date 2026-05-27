program InheritedImplicitSelfBareMethodTypeMismatchFail;

type
  TBaseWorker = class
    procedure Touch(Value: Integer);
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

procedure TBaseWorker.Touch(Value: Integer);
begin
end;

procedure TWorker.Run;
begin
  Touch(True);
end;

begin
end.
