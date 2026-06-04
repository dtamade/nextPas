program Llvm_var_param;

procedure Inc2(var X: Integer);
begin
  X := X + 2;
end;

type
  TNode = class
  end;

  TNodeHelper = class
    procedure ClearNode(var Node: TNode);
  end;

  TVirtualNodeUser = class
    procedure ClearNode(var Node: TNode); virtual;
  end;

  TDerivedNodeUser = class(TVirtualNodeUser)
    procedure ClearNode(var Node: TNode); override;
  end;

  INodeResetter = interface
    procedure ClearNode(var Node: TNode);
  end;

  TInterfaceNodeUser = class(TInterfacedObject, INodeResetter)
    procedure ClearNode(var Node: TNode);
  end;

procedure ClearNodeDirect(var Node: TNode);
begin
  Node := nil;
end;

procedure TNodeHelper.ClearNode(var Node: TNode);
begin
  Node := nil;
end;

procedure TVirtualNodeUser.ClearNode(var Node: TNode);
begin
  Node := nil;
end;

procedure TDerivedNodeUser.ClearNode(var Node: TNode);
begin
  Node := nil;
end;

procedure TInterfaceNodeUser.ClearNode(var Node: TNode);
begin
  Node := nil;
end;

var
  A: Integer;
  Node, Saved: TNode;
  Helper: TNodeHelper;
  Base: TVirtualNodeUser;
  Resetter: INodeResetter;
begin
  A := 1;
  Inc2(A);

  Saved := TNode.Create;
  Node := Saved;
  ClearNodeDirect(Node);
  if Node <> nil then
    Halt(101);
  Saved.Free;

  Saved := TNode.Create;
  Node := Saved;
  Helper := TNodeHelper.Create;
  Helper.ClearNode(Node);
  if Node <> nil then
    Halt(102);
  Saved.Free;
  Helper.Free;

  Saved := TNode.Create;
  Node := Saved;
  Base := TDerivedNodeUser.Create;
  Base.ClearNode(Node);
  if Node <> nil then
    Halt(103);
  Saved.Free;
  Base.Free;

  Saved := TNode.Create;
  Node := Saved;
  Resetter := TInterfaceNodeUser.Create;
  Resetter.ClearNode(Node);
  if Node <> nil then
    Halt(104);
  Saved.Free;
  Resetter := nil;

  A := A + 4;
  Halt(A);
end.
