unit Worker;

interface

type
  TBase = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: LongInt);
  end;

  TWorker = class(TBase)
  end;

implementation

procedure TBase.Pick(Value: Integer);
begin
end;

procedure TBase.Pick(Value: LongInt);
begin
end;

end.
