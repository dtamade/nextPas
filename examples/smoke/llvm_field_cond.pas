program llvm_field_cond;
type
  TCounter = class
    FCount: Integer;
    constructor Create;
    function IsZero: Integer; virtual;
    procedure Inc; virtual;
  end;

constructor TCounter.Create;
begin
  FCount := 0;
end;

function TCounter.IsZero: Integer;
begin
  if FCount = 0 then
    Result := 1
  else
    Result := 0;
end;

procedure TCounter.Inc;
begin
  FCount := FCount + 1;
end;

var
  C: TCounter;
  R: Integer;
begin
  C := TCounter.Create;
  R := C.IsZero;
  C.Inc;
  R := R + C.IsZero;
  Halt(R);
end.
