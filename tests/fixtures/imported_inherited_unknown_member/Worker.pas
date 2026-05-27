unit Worker;

interface

type
  TBase = class
    procedure Run;
  end;

  TWorker = class(TBase)
  end;

implementation

procedure TBase.Run;
begin
end;

end.
