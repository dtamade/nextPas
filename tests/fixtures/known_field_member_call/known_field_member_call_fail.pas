program KnownFieldMemberCallFail;

type
  TWorker = class
    Value: Integer;
  end;

var
  Worker: TWorker;

begin
  Worker.Value(1);
end.
