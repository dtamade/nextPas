program MemberNoMatchingOverloadFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: AnsiString);
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: AnsiString);
begin
end;

var
  Worker: TWorker;

begin
  Worker.Pick(True);
end.
