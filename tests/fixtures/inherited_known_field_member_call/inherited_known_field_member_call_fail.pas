program InheritedKnownFieldMemberCallFail;

type
  TBaseWorker = class
    Value: Integer;
  end;

  TWorker = class(TBaseWorker)
  end;

var
  Worker: TWorker;

begin
  Worker.Value(1);
end.
