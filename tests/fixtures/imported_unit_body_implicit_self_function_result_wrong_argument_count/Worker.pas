unit Worker;

interface

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Run;
  end;

implementation

procedure TWorker.Pick(Value: Integer);
begin
end;

function Count: Integer;
begin
end;

procedure TWorker.Run;
begin
  Pick(Count, Count);
end;

end.
