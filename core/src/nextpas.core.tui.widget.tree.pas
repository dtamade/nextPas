unit nextpas.core.tui.widget.tree;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block;

type
  PTreeNode = ^TTreeNode;
  TTreeNode = class(TInterfacedObject)
    Label_: AnsiString;
    Children: array of TTreeNode;
    Style: TStyle;

    class function Make(const ALabel: AnsiString): TTreeNode; static;
    function WithChildren(const AChildren: array of TTreeNode): TTreeNode;
    function WithStyle(const S: TStyle): TTreeNode;
  end;

  TTreeState = record
    Offset: Integer;
    Selected: Integer;
    Opened: array of Boolean;
    FlatCount: Integer;

    class function Empty: TTreeState; static;
    procedure EnsureSize(N: Integer);
    procedure Toggle(Idx: Integer);
    function IsOpen(Idx: Integer): Boolean;
  end;

  TTree = class(TInterfacedObject)
    Nodes: array of TTreeNode;
    Style: TStyle;
    HighlightStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;
    IndentSize: Integer;

    class function Create(const ANodes: array of TTreeNode): TTree; static;
    function WithBlock(const B: TBlock): TTree;
    function WithStyle(const S: TStyle): TTree;
    function WithHighlightStyle(const S: TStyle): TTree;
    function WithIndent(N: Integer): TTree;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTreeState);
  end;

implementation

{ TTreeNode }

class function TTreeNode.Make(const ALabel: AnsiString): TTreeNode;
begin
  Result.Label_ := ALabel;
  Result.Children := nil;
  Result.Style := TStyle.Default;
end;

function TTreeNode.WithChildren(const AChildren: array of TTreeNode): TTreeNode;
var I: Integer;
begin
  Result := Self;
  SetLength(Result.Children, Length(AChildren));
  for I := 0 to High(AChildren) do
    Result.Children[I] := AChildren[I];
end;

function TTreeNode.WithStyle(const S: TStyle): TTreeNode;
begin
  Result := Self;
  Result.Style := S;
end;

{ TTreeState }

class function TTreeState.Empty: TTreeState;
begin
  Result.Offset := 0;
  Result.Selected := 0;
  SetLength(Result.Opened, 0);
  Result.FlatCount := 0;
end;

procedure TTreeState.EnsureSize(N: Integer);
var OldLen, I: Integer;
begin
  OldLen := Length(Opened);
  if OldLen < N then
  begin
    SetLength(Opened, N);
    for I := OldLen to N - 1 do
      Opened[I] := False;
  end;
end;

procedure TTreeState.Toggle(Idx: Integer);
begin
  EnsureSize(Idx + 1);
  Opened[Idx] := not Opened[Idx];
end;

function TTreeState.IsOpen(Idx: Integer): Boolean;
begin
  if Idx >= Length(Opened) then Exit(False);
  Result := Opened[Idx];
end;

{ TTree }

class function TTree.Create(const ANodes: array of TTreeNode): TTree;
var I: Integer;
begin
  SetLength(Result.Nodes, Length(ANodes));
  for I := 0 to High(ANodes) do
    Result.Nodes[I] := ANodes[I];
  Result.Style := TStyle.Default;
  Result.HighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
  Result.IndentSize := 2;
end;

function TTree.WithBlock(const B: TBlock): TTree;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

function TTree.WithStyle(const S: TStyle): TTree;
begin
  Result := Self;
  Result.Style := S;
end;

function TTree.WithHighlightStyle(const S: TStyle): TTree;
begin
  Result := Self;
  Result.HighlightStyle := S;
end;

function TTree.WithIndent(N: Integer): TTree;
begin
  Result := Self;
  Result.IndentSize := N;
end;

type
  TFlatRow = record
    Label_: AnsiString;
    Depth: Integer;
    HasChildren: Boolean;
    IsOpen: Boolean;
    IsLast: Boolean;
    NodeStyle: TStyle;
  end;
  TFlatRows = array of TFlatRow;

procedure FlattenNodes(const Nodes: array of TTreeNode; Depth: Integer;
  var State: TTreeState; var FlatIdx: Integer; var Rows: TFlatRows;
  const ParentLast: array of Boolean);
var
  I, ChildIdx: Integer;
  Row: TFlatRow;
  NewParentLast: array of Boolean;
  J: Integer;
begin
  for I := 0 to High(Nodes) do
  begin
    Row.Label_ := Nodes[I].Label_;
    Row.Depth := Depth;
    Row.HasChildren := Length(Nodes[I].Children) > 0;
    Row.IsOpen := Row.HasChildren and State.IsOpen(FlatIdx);
    Row.IsLast := (I = High(Nodes));
    Row.NodeStyle := Nodes[I].Style;

    if FlatIdx >= Length(Rows) then
      SetLength(Rows, Length(Rows) + 64);
    Rows[FlatIdx] := Row;
    ChildIdx := FlatIdx;
    Inc(FlatIdx);

    if Row.IsOpen then
    begin
      SetLength(NewParentLast, Length(ParentLast) + 1);
      for J := 0 to High(ParentLast) do
        NewParentLast[J] := ParentLast[J];
      NewParentLast[High(NewParentLast)] := Row.IsLast;
      FlattenNodes(Nodes[I].Children, Depth + 1, State, FlatIdx, Rows, NewParentLast);
    end;
  end;
end;

procedure TTree.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTreeState);
var
  Inner: TRect;
  Rows: TFlatRows;
  FlatIdx, MaxRows, Visible: Integer;
  FirstVis, LastVis, Sel: Integer;
  RowY, I, X, ColW: Integer;
  Sty: TStyle;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;
  if Length(Nodes) = 0 then Exit;

  // Flatten tree into visible rows
  SetLength(Rows, 0);
  FlatIdx := 0;
  FlattenNodes(Nodes, 0, State, FlatIdx, Rows, []);
  SetLength(Rows, FlatIdx);
  State.FlatCount := FlatIdx;

  if FlatIdx = 0 then Exit;

  // Clamp selection
  if State.Selected < 0 then State.Selected := 0;
  if State.Selected >= FlatIdx then State.Selected := FlatIdx - 1;

  // Scrolling
  MaxRows := Inner.Height;
  Visible := MaxRows;
  if Visible > FlatIdx then Visible := FlatIdx;

  FirstVis := State.Offset;
  if FirstVis < 0 then FirstVis := 0;
  if FirstVis > FlatIdx - 1 then FirstVis := FlatIdx - 1;
  LastVis := FirstVis + Visible;
  if LastVis > FlatIdx then
  begin
    LastVis := FlatIdx;
    FirstVis := FlatIdx - Visible;
    if FirstVis < 0 then FirstVis := 0;
  end;

  Sel := State.Selected;
  while Sel >= LastVis do
  begin
    Inc(LastVis);
    if LastVis - FirstVis > Visible then Inc(FirstVis);
  end;
  while Sel < FirstVis do
  begin
    Dec(FirstVis);
    if LastVis - FirstVis > Visible then Dec(LastVis);
  end;
  State.Offset := FirstVis;

  // Render visible rows
  ColW := Inner.Width;
  RowY := Inner.Y;
  for I := FirstVis to LastVis - 1 do
  begin
    if RowY >= Inner.Y + Inner.Height then Break;

    Sty := Style.Patch(Rows[I].NodeStyle);
    ABuf.SetStyle(TRect.Make(Inner.X, RowY, ColW, 1), Sty);

    // Indentation: skip IndentSize * Depth columns (already cleared by SetStyle)
    X := Inner.X + IndentSize * Rows[I].Depth;

    // Expand/collapse marker
    if Rows[I].HasChildren then
    begin
      if Rows[I].IsOpen then
        ABuf.SetStringN(X, RowY, '[-] ', 4, Sty)
      else
        ABuf.SetStringN(X, RowY, '[+] ', 4, Sty);
    end
    else
      ABuf.SetStringN(X, RowY, '    ', 4, Sty);
    Inc(X, 4);
    ABuf.SetStringN(X, RowY, Rows[I].Label_, ColW - (X - Inner.X), Sty);

    // Highlight selected row
    if I = Sel then
      ABuf.SetStyle(TRect.Make(Inner.X, RowY, ColW, 1), HighlightStyle);

    Inc(RowY);
  end;
end;

end.
