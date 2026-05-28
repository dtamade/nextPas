program ImplicitSelfBareMethodUnknownMemberFail;

type
  TWorker = class
    procedure Run;
  end;

procedure TWorker.Run;
begin
  Missing;
end;

begin
end.
