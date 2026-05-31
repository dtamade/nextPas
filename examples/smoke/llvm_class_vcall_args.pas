program Llvm_class_vcall_args;
type
  TCalc = class
    FBase: Integer;
    constructor Create(ABase: Integer);
    function Add(X: Integer): Integer; virtual;
  end;
  TDoubleCalc = class(TCalc)
    constructor Create(ABase: Integer);
    function Add(X: Integer): Integer; override;
  end;

constructor TCalc.Create(ABase: Integer);
begin
  FBase := ABase;
end;

function TCalc.Add(X: Integer): Integer;
begin
  Add := FBase + X;
end;

constructor TDoubleCalc.Create(ABase: Integer);
begin
  inherited Create(ABase);
end;

function TDoubleCalc.Add(X: Integer): Integer;
begin
  Add := FBase + X * 2;
end;

var
  C: TCalc;
begin
  C := TDoubleCalc.Create(10);
  Halt(C.Add(16));
end.
