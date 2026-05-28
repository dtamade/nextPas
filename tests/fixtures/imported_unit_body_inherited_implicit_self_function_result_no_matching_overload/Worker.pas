unit Worker;

interface

type
  TBaseWorker = class
    procedure Touch(Value: Integer);
    procedure Touch(Value: AnsiString);
  end;

  TWorker = class(TBaseWorker)
    procedure Run;
  end;

implementation

procedure TBaseWorker.Touch(Value: Integer);
begin
end;

procedure TBaseWorker.Touch(Value: AnsiString);
begin
end;

function Flag: Boolean;
begin
end;

procedure TWorker.Run;
begin
  Touch(Flag);
end;

end.
