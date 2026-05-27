unit Worker;

interface

type
  TWorker = class
    procedure Pick(Value: Integer);
    procedure Pick(Value: AnsiString);
    procedure Run;
  end;

implementation

procedure TWorker.Pick(Value: Integer);
begin
end;

procedure TWorker.Pick(Value: AnsiString);
begin
end;

function Flag: Boolean;
begin
end;

procedure TWorker.Run;
begin
  Pick(Flag);
end;

end.
