unit Worker;

interface

type
  TWorker = class
    Value: Integer;
    procedure Run;
  end;

implementation

procedure TWorker.Run;
begin
  Value(1);
end;

end.
