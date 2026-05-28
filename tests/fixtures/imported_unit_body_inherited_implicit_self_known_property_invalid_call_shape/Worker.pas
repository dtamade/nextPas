unit Worker;

interface

type
  TBaseWorker = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
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
