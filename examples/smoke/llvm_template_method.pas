program llvm_template_method;
type
  TProcessor = class
    constructor Create;
    function Process(X: Integer): Integer; virtual;
    function PreProcess(X: Integer): Integer; virtual;
    function PostProcess(X: Integer): Integer; virtual;
  end;
  TDoubleProcessor = class(TProcessor)
    constructor Create;
    function PreProcess(X: Integer): Integer; override;
    function PostProcess(X: Integer): Integer; override;
  end;

constructor TProcessor.Create; begin end;
constructor TDoubleProcessor.Create; begin end;

function TProcessor.PreProcess(X: Integer): Integer;
begin
  Result := X;
end;

function TProcessor.PostProcess(X: Integer): Integer;
begin
  Result := X;
end;

function TProcessor.Process(X: Integer): Integer;
begin
  Result := PostProcess(PreProcess(X) + 1);
end;

function TDoubleProcessor.PreProcess(X: Integer): Integer;
begin
  Result := X * 2;
end;

function TDoubleProcessor.PostProcess(X: Integer): Integer;
begin
  Result := X + 31;
end;

var P: TDoubleProcessor;
begin
  P := TDoubleProcessor.Create;
  Halt(P.Process(5));
end.
