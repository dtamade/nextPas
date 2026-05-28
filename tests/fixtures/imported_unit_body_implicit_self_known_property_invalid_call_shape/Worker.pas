unit Worker;

interface

type
  TWorker = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
    procedure Run;
  end;

implementation

procedure TWorker.Run;
begin
  Value(1);
end;

end.
