program ImportedUnknownMemberFail;

uses Worker;

var
  Worker: TWorker;

begin
  Worker.Missing(1);
end.
