program ImportedInheritedMemberWrongArgumentCountFail;

uses Worker;

var
  Worker: TWorker;

begin
  Worker.Pick(1, 2);
end.
