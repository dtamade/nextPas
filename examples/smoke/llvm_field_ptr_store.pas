program llvm_field_ptr_store;
type
  TNode = class
    FValue: Integer;
    FNext: TNode;
    constructor Create(V: Integer);
  end;

  TStack = class
    FTop: TNode;
    FCount: Integer;
    constructor Create;
    procedure Push(V: Integer); virtual;
    function Pop: Integer; virtual;
    function Count: Integer; virtual;
  end;

constructor TNode.Create(V: Integer);
begin
  FValue := V;
end;

constructor TStack.Create;
begin
  FCount := 0;
end;

procedure TStack.Push(V: Integer);
var
  N: TNode;
begin
  N := TNode.Create(V);
  N.FNext := FTop;
  FTop := N;
  FCount := FCount + 1;
end;

function TStack.Pop: Integer;
begin
  Result := FTop.FValue;
  FTop := FTop.FNext;
  FCount := FCount - 1;
end;

function TStack.Count: Integer;
begin
  Result := FCount;
end;

var
  S: TStack;
  R: Integer;
begin
  S := TStack.Create;
  S.Push(10);
  S.Push(11);
  S.Push(30);
  R := S.Pop;
  R := R + S.Pop;
  R := R + S.Count;
  Halt(R);
end.
