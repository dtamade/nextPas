unit Worker;

interface

type
  TBase = class
    procedure Pick(Value: Integer);
  end;

  TWorker = class(TBase)
  end;

implementation

procedure TBase.Pick(Value: Integer);
begin
end;

end.
