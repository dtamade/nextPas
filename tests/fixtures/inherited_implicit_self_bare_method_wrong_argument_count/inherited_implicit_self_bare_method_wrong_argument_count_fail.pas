program InheritedImplicitSelfBareMethodWrongArgumentCountFail;

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
  Touch;
end;

begin
end.
