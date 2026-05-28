unit Worker;

interface

type
  TBaseWorker = class
    procedure Touch;
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

implementation

procedure TBaseWorker.Touch;
begin
end;

procedure TWorker.Run;
begin
  Missing;
end;

end.
