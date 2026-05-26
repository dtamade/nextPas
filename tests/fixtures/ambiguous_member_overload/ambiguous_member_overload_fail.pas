program AmbiguousMemberOverloadFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: LongInt);
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: LongInt);
begin
end;

var
  Worker: TWorker;

begin
  Worker.Pick(1);
end.
