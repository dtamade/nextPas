program llvm_while_field;
type
  TNode = class
    FValue: Integer;
    FNext: TNode;
    constructor Create(V: Integer);
  end;

  TList = class
    FHead: TNode;
    FCount: Integer;
    constructor Create;
    procedure Add(V: Integer); virtual;
    function Sum: Integer; virtual;
  end;

constructor TNode.Create(V: Integer);
begin
  FValue := V;
end;

constructor TList.Create;
begin
  FCount := 0;
end;

procedure TList.Add(V: Integer);
var
  N: TNode;
begin
  N := TNode.Create(V);
  N.FNext := FHead;
  FHead := N;
  FCount := FCount + 1;
end;

function TList.Sum: Integer;
var
  Cur: TNode;
  S: Integer;
begin
  S := 0;
  Cur := FHead;
  while Cur <> nil do
  begin
    S := S + Cur.FValue;
    Cur := Cur.FNext;
  end;
  Result := S;
end;

var
  L: TList;
begin
  L := TList.Create;
  L.Add(10);
  L.Add(20);
  L.Add(12);
  Halt(L.Sum);
end.
