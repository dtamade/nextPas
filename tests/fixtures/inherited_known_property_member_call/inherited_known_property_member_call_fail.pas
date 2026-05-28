program InheritedKnownPropertyMemberCallFail;

type
  TBaseWorker = class
  private
    FValue: Integer;
  public
    property Value: Integer read FValue write FValue;
  end;

  TWorker = class(TBaseWorker)
  end;

var
  Worker: TWorker;

begin
  Worker.Value(1);
end.
