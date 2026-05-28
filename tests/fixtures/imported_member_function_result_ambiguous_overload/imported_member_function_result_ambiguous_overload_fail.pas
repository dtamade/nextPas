program ImportedMemberFunctionResultAmbiguousOverloadFail;

uses Worker;

var
  Worker: TWorker;

function Count: Integer;
begin
end;

begin
  Worker.Pick(Count);
end.
