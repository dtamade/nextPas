program llvm_linked_list;
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
    procedure Push(V: Integer); virtual;
    function Top: Integer; virtual;
    function Count: Integer; virtual;
  end;

constructor TNode.Create(V: Integer);
begin
  FValue := V;
end;

constructor TList.Create;
begin
  FCount := 0;
end;

procedure TList.Push(V: Integer);
var
  N: TNode;
begin
  N := TNode.Create(V);
  FHead := N;
  FCount := FCount + 1;
end;

function TList.Top: Integer;
begin
  Result := FHead.FValue;
end;

function TList.Count: Integer;
begin
  Result := FCount;
end;

var
  L: TList;
begin
  L := TList.Create;
  L.Push(10);
  L.Push(40);
  Halt(L.Top + L.Count);
end.
