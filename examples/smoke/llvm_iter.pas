program TestIter;
type
  TNode = class
    FValue: Integer;
    FNext: TNode;
    constructor Create(AValue: Integer);
    procedure SetNext(ANode: TNode); virtual;
    function Next: TNode; virtual;
    function Value: Integer; virtual;
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

var
  A, B, C, Cur: TNode;
  Sum: Integer;
begin
  A := TNode.Create(10);
  B := TNode.Create(14);
  C := TNode.Create(18);
  A.SetNext(B);
  B.SetNext(C);
  Sum := 0;
  Cur := A;
  while Cur <> nil do
  begin
    Sum := Sum + Cur.Value;
    Cur := Cur.Next;
  end;
  Halt(Sum);
end.
