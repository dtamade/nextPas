program QueryMemberCallBindings;

type
  TWorker = class
    constructor Create(Value: Integer);
    procedure Run;
    procedure SetValue(Value: Integer);
    function Add(A, B: Integer): Integer;
  end;

constructor TWorker.Create(Value: Integer);
begin
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
  Worker := TWorker.Create(42);
  Worker.Run;
  Worker.SetValue(7);
  Worker.SetValue;
  Halt(Worker.Add(1, 2));
end.
