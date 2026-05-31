program test_intf_proc_args;
type
  IStack = interface
    procedure Push(V: Integer);
    function Pop: Integer;
    function Count: Integer;
  end;
  TStack = class(TInterfacedObject, IStack)
    FItems: array of Integer;
    FTop: Integer;
    constructor Create;
    procedure Push(V: Integer);
    function Pop: Integer;
    function Count: Integer;
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

function TStack.Count: Integer;
begin
  Result := FTop;
end;

var
  S: IStack;
begin
  S := TStack.Create;
  S.Push(10);
  S.Push(20);
  S.Push(30);
  Halt(S.Pop + S.Count);
end.
