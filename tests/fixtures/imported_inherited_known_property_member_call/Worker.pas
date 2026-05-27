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
  end;

implementation

end.
