program MemberTypeMismatchFunctionResultCallFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Run;
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

function Flag: Boolean;
begin
end;

procedure TWorker.Run;
begin
  Self.Pick(Flag);
end;

begin
end.
