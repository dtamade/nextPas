program ImportedInheritedMemberFunctionResultWrongArgumentCountFail;

uses Worker;

var
  Worker: TWorker;

function Flag: Boolean;
begin
end;

begin
  Worker.Pick(Flag, Flag);
end.
