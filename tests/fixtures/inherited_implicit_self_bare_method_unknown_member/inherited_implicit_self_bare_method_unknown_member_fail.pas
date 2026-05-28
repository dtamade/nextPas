program InheritedImplicitSelfBareMethodUnknownMemberFail;

type
  TBaseWorker = class
    procedure Touch;
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

procedure TBaseWorker.Touch;
begin
end;

procedure TWorker.Run;
begin
  Missing;
end;

begin
end.
