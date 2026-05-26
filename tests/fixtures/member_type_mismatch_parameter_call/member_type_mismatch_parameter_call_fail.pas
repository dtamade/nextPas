program MemberTypeMismatchParameterCallFail;

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Run(Flag: Boolean);
  end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Run(Flag: Boolean);
begin
  Self.Pick(Flag);
end;

begin
end.
