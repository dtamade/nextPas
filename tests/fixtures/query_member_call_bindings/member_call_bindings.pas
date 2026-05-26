program QueryMemberCallBindings;

type
  TWorker = class
    procedure Run;
    procedure SetValue(Value: Integer);
    function Add(A, B: Integer): Integer;
  end;

procedure TWorker.Run;
begin
end;

procedure TWorker.SetValue(Value: Integer);
begin
end;

function TWorker.Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

var
  Worker: TWorker;

begin
  Worker.Run;
  Worker.SetValue(7);
  Worker.SetValue;
  Halt(Worker.Add(1, 2));
end.
