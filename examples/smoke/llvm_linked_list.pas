program TestLinked;
type
  TNode = class
    FValue: Integer;
    FNext: TNode;
    constructor Create(AValue: Integer);
    procedure SetNext(ANext: TNode); virtual;
    function Total: Integer; virtual;
  end;

constructor TNode.Create(AValue: Integer);
begin
  FValue := AValue;
end;

procedure TNode.SetNext(ANext: TNode);
begin
  FNext := ANext;
end;

function TNode.Total: Integer;
begin
  if FNext = nil then
    Result := FValue
  else
    Result := FValue + FNext.Total;
end;

var
  A, B, C: TNode;
begin
  A := TNode.Create(10);
  B := TNode.Create(20);
  C := TNode.Create(12);
  A.SetNext(B);
  B.SetNext(C);
  Halt(A.Total);
end.
