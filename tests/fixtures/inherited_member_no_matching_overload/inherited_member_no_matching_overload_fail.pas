program InheritedMemberNoMatchingOverloadFail;

type
  TBase = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: AnsiString);
  end;

  TWorker = class(TBase)
  end;

procedure TBase.Pick(Value: Integer);
begin
end;

procedure TBase.Pick(Value: AnsiString);
begin
end;

var
  Worker: TWorker;

begin
  Worker.Pick(True);
end.
