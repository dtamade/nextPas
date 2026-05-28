unit Worker;

interface

type
  TBaseWorker = class
    procedure Touch(Value: Integer);
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

implementation

procedure TBaseWorker.Touch(Value: Integer);
begin
end;

function Count: Integer;
begin
end;

procedure TWorker.Run;
begin
  Touch(Count, Count);
end;

end.
