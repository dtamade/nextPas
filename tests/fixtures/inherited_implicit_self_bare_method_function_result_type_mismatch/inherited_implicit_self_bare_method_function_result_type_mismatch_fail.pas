program InheritedImplicitSelfBareMethodFunctionResultTypeMismatchFail;

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

function Flag: Boolean;
begin
end;

procedure TWorker.Run;
begin
  Touch(Flag);
end;

begin
end.
