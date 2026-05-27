program QueryMemberCallBindings;

type
  TWorker = class
    constructor Create(Value: Integer);
    procedure Run;
    procedure Touch;
    procedure SetValue(Value: Integer);
    function Add(A, B: Integer): Integer;
    procedure Pick;
    procedure Pick(Value: Integer);
    procedure Pick(Value: Boolean);
  end;
  TBaseWorker = class
    procedure Touch;
  end;
  TChildWorker = class(TBaseWorker)
    procedure Run;
  end;

constructor TWorker.Create(Value: Integer);
begin
end;

procedure TWorker.Run;
begin
  Self.SetValue(9);
  Touch;
end;

procedure TWorker.Touch;
begin
end;

procedure TWorker.SetValue(Value: Integer);
begin
end;

function TWorker.Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

procedure TWorker.Pick;
begin
end;

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: Boolean);
begin
end;

procedure TBaseWorker.Touch;
begin
end;

procedure TChildWorker.Run;
begin
  Touch;
end;

var
  Worker: TWorker;
  Child: TChildWorker;

begin
  Worker := TWorker.Create(42);
  Worker.Run;
  Worker.SetValue(7);
  Halt(Worker.Add(1, 2));
  Worker.Pick;
  Worker.Pick(5);
  Worker.Pick(1 = 1);
  Child.Touch;
end.
