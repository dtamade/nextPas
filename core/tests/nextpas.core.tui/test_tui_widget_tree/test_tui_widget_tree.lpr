program test_tui_widget_tree;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.tree,
  nextpas.core.test;

var
  T: TTestSuite;

{ === TreeNode Tests === }

procedure TestTreeNodeMake;
var
  Node: TTreeNode;
begin
  Node := TTreeNode.Make('test');
  CheckEqual('test', Node.Label_, 'node label');
  CheckEqual(0, Length(Node.Children), 'no children');
end;

procedure TestTreeNodeWithChildren;
var
  Parent, Child: TTreeNode;
begin
  Child := TTreeNode.Make('child');
  Parent := TTreeNode.Make('parent').WithChildren([Child]);
  CheckEqual(1, Length(Parent.Children), 'one child');
  CheckEqual('child', Parent.Children[0].Label_, 'child label');
end;

procedure TestTreeNodeWithStyle;
var
  Node: TTreeNode;
  Sty: TStyle;
begin
  Sty := TStyle.Default.WithFg(TUI_RED);
  Node := TTreeNode.Make('styled').WithStyle(Sty);
  Check(Node.Style.Fg.Kind <> ckUnset, 'style applied');
end;

procedure TestTreeNodeNested;
var
  Root, Child1, Child2, Grandchild: TTreeNode;
begin
  Grandchild := TTreeNode.Make('grandchild');
  Child1 := TTreeNode.Make('child1').WithChildren([Grandchild]);
  Child2 := TTreeNode.Make('child2');
  Root := TTreeNode.Make('root').WithChildren([Child1, Child2]);
  CheckEqual(2, Length(Root.Children), 'root has 2 children');
  CheckEqual(1, Length(Root.Children[0].Children), 'child1 has 1 grandchild');
end;

{ === TreeState Tests === }

procedure TestTreeStateEmpty;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  CheckEqual(0, State.Offset, 'initial offset');
  CheckEqual(0, State.Selected, 'initial selected');
  CheckEqual(0, Length(State.Opened), 'initial opened length');
  CheckEqual(0, State.FlatCount, 'initial flat count');
end;

procedure TestTreeStateToggle;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  State.Toggle(0);
  Check(State.IsOpen(0), 'toggle opens');
  State.Toggle(0);
  Check(not State.IsOpen(0), 'toggle closes');
end;

procedure TestTreeStateEnsureSize;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  State.EnsureSize(5);
  CheckEqual(5, Length(State.Opened), 'ensure size expands');
  Check(not State.IsOpen(3), 'new entries are closed');
end;

procedure TestTreeStateIsOpenOutOfRange;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  Check(not State.IsOpen(100), 'out of range returns false');
end;

{ === Tree Widget Tests === }

procedure TestTreeRenderEmpty;
var
  Tree: ITree;
  Buf: TBuffer;
begin
  Tree := TTree.New([]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Tree.Render(TRect.Make(0, 0, 20, 5), Buf);
    Check(True, 'empty tree renders without error');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderSingleRoot;
var
  Tree: ITree;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  Tree := TTree.New([TTreeNode.Make('root')]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Tree.Render(TRect.Make(0, 0, 20, 5), Buf);
    LLines := Buf.AsLines;
    Check(Pos('root', LLines[0]) > 0, 'root label rendered');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderWithChildren;
var
  Tree: ITree;
  Buf: TBuffer;
  LLines: TBufferLines;
  Root, Child1, Child2: TTreeNode;
begin
  Child1 := TTreeNode.Make('child1');
  Child2 := TTreeNode.Make('child2');
  Root := TTreeNode.Make('root').WithChildren([Child1, Child2]);
  Tree := TTree.New([Root]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tree.Render(TRect.Make(0, 0, 20, 10), Buf);
    LLines := Buf.AsLines;
    Check(Pos('root', LLines[0]) > 0, 'root rendered');
    { Children are collapsed by default }
    Check(Pos('child', LLines[1]) = 0, 'children collapsed by default');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderStatefulOpen;
var
  Tree: ITree;
  Buf: TBuffer;
  LLines: TBufferLines;
  State: TTreeState;
  Root, Child: TTreeNode;
begin
  Child := TTreeNode.Make('child');
  Root := TTreeNode.Make('root').WithChildren([Child]);
  Tree := TTree.New([Root]);
  State := TTreeState.Empty;
  State.Toggle(0); { Open root }
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tree.RenderStateful(TRect.Make(0, 0, 20, 10), Buf, State);
    LLines := Buf.AsLines;
    Check(Pos('root', LLines[0]) > 0, 'root rendered');
    Check(Pos('child', LLines[1]) > 0, 'child visible when open');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderSelected;
var
  Tree: ITree;
  Buf: TBuffer;
  State: TTreeState;
begin
  Tree := TTree.New([TTreeNode.Make('a'), TTreeNode.Make('b')]);
  State := TTreeState.Empty;
  State.Selected := 1;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Tree.RenderStateful(TRect.Make(0, 0, 20, 5), Buf, State);
    Check(True, 'selected node renders without error');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderWithBlock;
var
  Tree: ITree;
  Block: IBlock;
  Buf: TBuffer;
begin
  Block := TBlock.New;
  Tree := TTree.New([TTreeNode.Make('root')]);
  Tree.WithBlock(Block);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Tree.Render(TRect.Make(0, 0, 20, 5), Buf);
    Check(True, 'tree with block renders without error');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeBuilderChaining;
var
  Tree: ITree;
begin
  Tree := TTree.New([TTreeNode.Make('root')])
    .WithStyle(TStyle.Default)
    .WithHighlightStyle(TStyle.Default.WithModifier([mbBold]))
    .WithIndent(4);
  Check(Tree <> nil, 'builder chaining returns non-nil');
end;

procedure TestTreeFlatCount;
var
  Tree: ITree;
  Buf: TBuffer;
  State: TTreeState;
  Root, Child1, Child2: TTreeNode;
begin
  Child1 := TTreeNode.Make('child1');
  Child2 := TTreeNode.Make('child2');
  Root := TTreeNode.Make('root').WithChildren([Child1, Child2]);
  Tree := TTree.New([Root]);
  State := TTreeState.Empty;
  State.Toggle(0); { Open root }
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tree.RenderStateful(TRect.Make(0, 0, 20, 10), Buf, State);
    CheckEqual(3, State.FlatCount, 'flat count with open node');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeRenderSmallArea;
var
  Tree: ITree;
  Buf: TBuffer;
begin
  Tree := TTree.New([TTreeNode.Make('root')]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Tree.Render(TRect.Make(0, 0, 5, 2), Buf);
    Check(True, 'tree renders in small area');
  finally
    Buf.Free;
  end;
end;

procedure TestTreeStateToggleMultiple;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  State.EnsureSize(3);
  State.Toggle(0);
  State.Toggle(1);
  Check(State.IsOpen(0), 'node 0 should be open');
  Check(State.IsOpen(1), 'node 1 should be open');
  Check(not State.IsOpen(2), 'node 2 should be closed');
  State.Toggle(0);
  Check(not State.IsOpen(0), 'node 0 should be closed after toggle');
end;

procedure TestTreeStateEnsureSizeIdempotent;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  State.EnsureSize(5);
  State.EnsureSize(5);
  CheckEqual(5, Length(State.Opened), 'ensure size should be idempotent');
end;

procedure TestTreeNodeWithEmptyChildren;
var
  Node: TTreeNode;
begin
  Node := TTreeNode.Make('leaf').WithChildren([]);
  CheckEqual(0, Length(Node.Children), 'empty children array');
  CheckEqual('leaf', Node.Label_, 'label preserved');
end;

procedure TestTreeRenderMultipleRoots;
var
  Tree: ITree;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  Tree := TTree.New([TTreeNode.Make('root1'), TTreeNode.Make('root2')]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tree.Render(TRect.Make(0, 0, 20, 10), Buf);
    LLines := Buf.AsLines;
    Check(Pos('root1', LLines[0]) > 0, 'root1 should be rendered');
  finally
    Buf.Free;
  end;
end;

{ PH33 P3：数据更新面——SetNodes 原地替换节点集 }
procedure TestTreeSetNodes;
var LT: ITree; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LT := TTree.New([TTreeNode.Make('old-root')]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 5));
  try
    LT.SetNodes([TTreeNode.Make('fresh-root')]);
    LT.Render(TRect.Make(0, 0, 30, 5), LBuf);
    LAll := '';
    for I := 0 to 4 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('fresh-root', LAll) > 0, 'new root visible');
    Check(Pos('old-root', LAll) = 0, 'old root gone');
  finally LBuf.Free; end;
end;

procedure TestTreeWithNodesChaining;
var LT: ITree;
begin
  LT := TTree.New([TTreeNode.Make('a')])
    .WithNodes([TTreeNode.Make('x'), TTreeNode.Make('y')]);
  Check(LT <> nil, 'WithNodes chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.tree');

  { TreeNode tests }
  T.Test('tree node make', @TestTreeNodeMake);
  T.Test('tree node with children', @TestTreeNodeWithChildren);
  T.Test('tree node with style', @TestTreeNodeWithStyle);
  T.Test('tree node nested', @TestTreeNodeNested);

  { TreeState tests }
  T.Test('tree state empty', @TestTreeStateEmpty);
  T.Test('tree state toggle', @TestTreeStateToggle);
  T.Test('tree state ensure size', @TestTreeStateEnsureSize);
  T.Test('tree state is open out of range', @TestTreeStateIsOpenOutOfRange);

  { Tree widget tests }
  T.Test('tree render empty', @TestTreeRenderEmpty);
  T.Test('tree render single root', @TestTreeRenderSingleRoot);
  T.Test('tree render with children', @TestTreeRenderWithChildren);
  T.Test('tree render stateful open', @TestTreeRenderStatefulOpen);
  T.Test('tree render selected', @TestTreeRenderSelected);
  T.Test('tree render with block', @TestTreeRenderWithBlock);
  T.Test('tree builder chaining', @TestTreeBuilderChaining);
  T.Test('tree flat count', @TestTreeFlatCount);
  T.Test('tree render small area', @TestTreeRenderSmallArea);
  T.Test('tree state toggle multiple', @TestTreeStateToggleMultiple);
  T.Test('tree state ensure size idempotent', @TestTreeStateEnsureSizeIdempotent);
  T.Test('tree node with empty children', @TestTreeNodeWithEmptyChildren);
  T.Test('tree render multiple roots', @TestTreeRenderMultipleRoots);
  T.Test('SetNodes in-place update (PH33 P3)', @TestTreeSetNodes);
  T.Test('WithNodes chaining (PH33 P3)', @TestTreeWithNodesChaining);

  if not T.Run then Halt(1);
end.
