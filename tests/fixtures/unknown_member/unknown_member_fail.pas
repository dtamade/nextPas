program UnknownMemberFail;

type
  TWorker = class
    procedure Run;
  end;

procedure TWorker.Run;
begin
end;

var
  Worker: TWorker;

begin
  Worker.Missing(1);
end.
