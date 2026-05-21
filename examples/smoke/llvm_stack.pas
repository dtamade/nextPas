program TestStack;
type
  TNode = class
    FValue: Integer;
    FNext: TNode;
    constructor Create(AValue: Integer);
    procedure SetNext(ANode: TNode); virtual;
    function Next: TNode; virtual;
    function Value: Integer; virtual;
  end;

  TStack = class
    FTop: TNode;
    FSize: Integer;
    constructor Create;
    procedure Push(V: Integer); virtual;
    function Pop: Integer; virtual;
    function Size: Integer; virtual;
  end;

constructor TNode.Create(AValue: Integer);
begin
  FValue := AValue;
end;

procedure TNode.SetNext(ANode: TNode);
begin
  FNext := ANode;
end;

function TNode.Next: TNode;
begin
  Result := FNext;
end;

function TNode.Value: Integer;
begin
  Result := FValue;
end;

constructor TStack.Create;
begin
  FSize := 0;
end;

procedure TStack.Push(V: Integer);
var
  N: TNode;
begin
  N := TNode.Create(V);
  N.SetNext(FTop);
  FTop := N;
  FSize := FSize + 1;
end;

function TStack.Pop: Integer;
begin
  Result := FTop.Value;
  FTop := FTop.Next;
  FSize := FSize - 1;
end;

function TStack.Size: Integer;
begin
  Result := FSize;
end;

var
  S: TStack;
  A, B: Integer;
begin
  S := TStack.Create;
  S.Push(10);
  S.Push(20);
  S.Push(5);
  A := S.Pop;
  B := S.Pop;
  Halt(A + B + S.Size);
end.
