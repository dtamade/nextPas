unit Worker;

interface

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: LongInt);
    procedure Run;
  end;

implementation

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: LongInt);
begin
end;

procedure TWorker.Run;
begin
  Pick(1);
end;

end.
