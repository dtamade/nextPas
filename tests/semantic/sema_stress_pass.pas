program Sema_stress_pass;
type
  TNodeKind = (nkLiteral, nkBinary, nkUnary, nkIdent);

  TNode = record
    Kind: TNodeKind;
    Value: Integer;
    Name: string;
  end;

const
  MaxNodes = 256;
  Version = 1;

function MakeNode(AKind: TNodeKind; AValue: Integer): TNode;
begin
  MakeNode.Kind := AKind;
  MakeNode.Value := AValue;
  MakeNode.Name := '';
end;

function NodeValue(const N: TNode): Integer;
begin
  case N.Kind of
    nkLiteral: NodeValue := N.Value;
    nkBinary: NodeValue := N.Value * 2;
    nkUnary: NodeValue := 0 - N.Value;
  else
    NodeValue := 0;
  end;
end;

function IsLiteral(const N: TNode): Boolean;
begin
  IsLiteral := N.Kind = nkLiteral;
end;

var
  Nodes: array[0..MaxNodes - 1] of TNode;
  Count: Integer;
  I: Integer;
  Total: Integer;
begin
  Count := 0;
  Total := 0;

  Nodes[Count] := MakeNode(nkLiteral, 42);
  Inc(Count);
  Nodes[Count] := MakeNode(nkBinary, 10);
  Inc(Count);
  Nodes[Count] := MakeNode(nkUnary, 5);
  Inc(Count);

  for I := 0 to Count - 1 do
  begin
    if IsLiteral(Nodes[I]) then
      Total := Total + NodeValue(Nodes[I]);
  end;
end.
