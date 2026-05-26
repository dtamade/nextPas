program MemberTypeMismatchVariableCallFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

var
  Worker: TWorker;
  Flag: Boolean;

begin
  Worker.Pick(Flag);
end.
