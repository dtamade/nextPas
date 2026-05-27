program KnownPropertyMemberCallFail;

type
  TWorker = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
  end;

var
  Worker: TWorker;

begin
  Worker.Value(1);
end.
