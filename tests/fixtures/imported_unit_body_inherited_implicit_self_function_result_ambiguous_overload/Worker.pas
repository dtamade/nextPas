unit Worker;

interface

type
  TBaseWorker = class
    procedure Touch(Value: Integer);
    procedure Touch(Value: LongInt);
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

implementation

procedure TBaseWorker.Touch(Value: Integer);
begin
end;

procedure TBaseWorker.Touch(Value: LongInt);
begin
end;

function Count: Integer;
begin
end;

procedure TWorker.Run;
begin
  Touch(Count);
end;

end.
