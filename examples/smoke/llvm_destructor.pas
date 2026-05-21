program Llvm_destructor;
type
  TCounter = class
    FCount: Integer;
    constructor Create;
    destructor Destroy; virtual;
    procedure Inc;
    function GetCount: Integer; virtual;
  end;

constructor TCounter.Create;
begin
  FCount := 0;
end;

destructor TCounter.Destroy;
begin
  FCount := -1;
end;

procedure TCounter.Inc;
begin
  FCount := FCount + 1;
end;

function TCounter.GetCount: Integer;
begin
  Result := FCount;
end;

var
  C: TCounter;
  R: Integer;
begin
  C := TCounter.Create;
  C.Inc;
  C.Inc;
  C.Inc;
  R := C.GetCount;
  C.Free;
  Halt(R);
end.
