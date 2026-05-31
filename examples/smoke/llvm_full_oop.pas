program llvm_full_oop;
type
  TNode = class
    FVal: Integer;
    FNext: TNode;
    constructor Create(V: Integer);
  end;
  TCollection = class
    FHead: TNode;
    FSize: Integer;
    constructor Create;
    procedure Add(V: Integer); virtual;
    function Sum: Integer; virtual;
    function Count: Integer; virtual;
    function Average: Integer; virtual;
  end;

constructor TNode.Create(V: Integer);
begin
  FVal := V;
end;

constructor TCollection.Create;
begin
  FSize := 0;
end;

procedure TCollection.Add(V: Integer);
var
  N: TNode;
begin
  N := TNode.Create(V);
  N.FNext := FHead;
  FHead := N;
  FSize := FSize + 1;
end;

function TCollection.Sum: Integer;
var
  Cur: TNode;
  S: Integer;
begin
  S := 0;
  Cur := FHead;
  while Cur <> nil do
  begin
    S := S + Cur.FVal;
    Cur := Cur.FNext;
  end;
  Result := S;
end;

function TCollection.Count: Integer;
begin
  Result := FSize;
end;

function TCollection.Average: Integer;
begin
  if FSize = 0 then
    Result := 0
  else
    Result := Sum div Count;
end;

var
  C: TCollection;
begin
  C := TCollection.Create;
  C.Add(10);
  C.Add(20);
  C.Add(30);
  C.Add(40);
  Halt(C.Average);
end.
