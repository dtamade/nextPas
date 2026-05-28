unit Worker;

interface

type
  TBaseWorker = class
    Value: Integer;
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

implementation

procedure TWorker.Run;
begin
  Value(1);
end;

end.
