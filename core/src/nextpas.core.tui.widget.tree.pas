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
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block;

type
  PTreeNode = ^TTreeNode;
  TTreeNode = record
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

  ITree = interface(IWidget)
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function WithBlock(ABlock: IBlock): ITree;
    function WithStyle(const AStyle: TStyle): ITree;
    function WithHighlightStyle(const AStyle: TStyle): ITree;
    function WithIndent(N: Integer): ITree;
    procedure RenderStateful(const AArea: TRect; ABuf: TBuffer;
      var AState: TTreeState);
  end;

  TTree = class(TInterfacedObject, IWidget, ITree)
  private
    FNodes: array of TTreeNode;
    FStyle: TStyle;
    FHighlightStyle: TStyle;
    FBlock: IBlock;
    FIndentSize: Integer;
  public
    class function New(const ANodes: array of TTreeNode): ITree; static;

    function WithBlock(ABlock: IBlock): ITree;
    function WithStyle(const AStyle: TStyle): ITree;
    function WithHighlightStyle(const AStyle: TStyle): ITree;
    function WithIndent(N: Integer): ITree;

    { IWidget }
    procedure Render(const AArea: TRect; ABuf: TBuffer);
    { ITree }
    procedure RenderStateful(const AArea: TRect; ABuf: TBuffer;
      var AState: TTreeState);
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

class function TTree.New(const ANodes: array of TTreeNode): ITree;
var
  LSelf: TTree;
  I: Integer;
begin
  LSelf := TTree.Create;
  SetLength(LSelf.FNodes, Length(ANodes));
  for I := 0 to High(ANodes) do
    LSelf.FNodes[I] := ANodes[I];
  LSelf.FStyle := TStyle.Default;
  LSelf.FHighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FBlock := nil;
  LSelf.FIndentSize := 2;
  Result := LSelf;
end;

function TTree.WithBlock(ABlock: IBlock): ITree;
begin
  FBlock := ABlock;
  Result := Self;
end;

function TTree.WithStyle(const AStyle: TStyle): ITree;
begin
  FStyle := AStyle;
  Result := Self;
end;

function TTree.WithHighlightStyle(const AStyle: TStyle): ITree;
begin
  FHighlightStyle := AStyle;
  Result := Self;
end;

function TTree.WithIndent(N: Integer): ITree;
begin
  FIndentSize := N;
  Result := Self;
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
  I: Integer;
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

procedure TTree.Render(const AArea: TRect; ABuf: TBuffer);
var
  LState: TTreeState;
begin
  LState := TTreeState.Empty;
  RenderStateful(AArea, ABuf, LState);
end;

procedure TTree.RenderStateful(const AArea: TRect; ABuf: TBuffer; var AState: TTreeState);
var
  Inner: TRect;
  Rows: TFlatRows;
  FlatIdx, MaxRows, Visible: Integer;
  FirstVis, LastVis, Sel: Integer;
  RowY, I, X, ColW: Integer;
  Sty: TStyle;
begin
  if AArea.IsEmpty then Exit;

  ABuf.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuf);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;
  if Length(FNodes) = 0 then Exit;

  SetLength(Rows, 0);
  FlatIdx := 0;
  FlattenNodes(FNodes, 0, AState, FlatIdx, Rows, []);
  SetLength(Rows, FlatIdx);
  AState.FlatCount := FlatIdx;

  if FlatIdx = 0 then Exit;

  if AState.Selected < 0 then AState.Selected := 0;
  if AState.Selected >= FlatIdx then AState.Selected := FlatIdx - 1;

  MaxRows := Inner.Height;
  Visible := MaxRows;
  if Visible > FlatIdx then Visible := FlatIdx;

  FirstVis := AState.Offset;
  if FirstVis < 0 then FirstVis := 0;
  if FirstVis > FlatIdx - 1 then FirstVis := FlatIdx - 1;
  LastVis := FirstVis + Visible;
  if LastVis > FlatIdx then
  begin
    LastVis := FlatIdx;
    FirstVis := FlatIdx - Visible;
    if FirstVis < 0 then FirstVis := 0;
  end;

  Sel := AState.Selected;
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
  AState.Offset := FirstVis;

  ColW := Inner.Width;
  RowY := Inner.Y;
  for I := FirstVis to LastVis - 1 do
  begin
    if RowY >= Inner.Y + Inner.Height then Break;

    Sty := FStyle.Patch(Rows[I].NodeStyle);
    ABuf.SetStyle(TRect.Make(Inner.X, RowY, ColW, 1), Sty);

    X := Inner.X + FIndentSize * Rows[I].Depth;

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

    if I = Sel then
      ABuf.SetStyle(TRect.Make(Inner.X, RowY, ColW, 1), FHighlightStyle);

    Inc(RowY);
  end;
end;

end.
