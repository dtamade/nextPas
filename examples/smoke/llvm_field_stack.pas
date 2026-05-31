program llvm_field_stack;
type
  TStack = class
    FItems: array of Integer;
    FTop: Integer;
    constructor Create;
    procedure Push(V: Integer); virtual;
    function Pop: Integer; virtual;
    function IsEmpty: Integer; virtual;
  end;

constructor TStack.Create;
begin
  FTop := 0;
  SetLength(FItems, 16);
end;

procedure TStack.Push(V: Integer);
begin
  FItems[FTop] := V;
  FTop := FTop + 1;
end;

function TStack.Pop: Integer;
begin
  FTop := FTop - 1;
  Result := FItems[FTop];
end;

function TStack.IsEmpty: Integer;
begin
  if FTop = 0 then
    Result := 1
  else
    Result := 0;
end;

var
  S: TStack;
  R: Integer;
begin
  S := TStack.Create;
  R := S.IsEmpty;
  S.Push(10);
  S.Push(41);
  R := R + S.Pop;
  R := R + S.IsEmpty;
  Halt(R);
end.
