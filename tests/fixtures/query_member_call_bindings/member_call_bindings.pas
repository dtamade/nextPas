program QueryMemberCallBindings;

type
  TWorker = class
    procedure Run;
    procedure SetValue(Value: Integer);
  end;

procedure TWorker.Run;
begin
end;

procedure TWorker.SetValue(Value: Integer);
begin
end;

var
  Worker: TWorker;

begin
  Worker.Run;
  Worker.SetValue(7);
  Worker.SetValue;
end.
