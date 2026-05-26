program MemberTypeMismatchCallFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

var
  Worker: TWorker;

begin
  Worker.Pick(True);
end.
