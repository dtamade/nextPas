unit nextpas.core.tui.widget.file_tree;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.modifier, nextpas.core.tui.style, nextpas.core.tui.cell, nextpas.core.tui.buffer, nextpas.core.tui.widget.block, nextpas.core.tui.widget.intf;

type
  TFileNode = record
    Name: AnsiString;
    IsDir: Boolean;
    Depth: Integer;
    Expanded: Boolean;
    Children: array of Integer; // indices into flat array
  end;

  TFileTreeState = record
    Nodes: array of TFileNode;
    Selected: Integer;
    ScrollY: Integer;

    class function Empty: TFileTreeState; static;
    function AddNode(const AName: AnsiString; AIsDir: Boolean; ADepth: Integer): Integer;
    procedure ToggleExpand;
    procedure SelectNext;
    procedure SelectPrev;
    function VisibleCount: Integer;
  end;

  IFileTree = interface(IWidget)
    ['{A1B2C3D4-E5F6-7890-1234-56789ABCDEF0}']
    function WithStyle(const AStyle: TStyle): IFileTree;
    function WithDirStyle(const AStyle: TStyle): IFileTree;
    function WithFileStyle(const AStyle: TStyle): IFileTree;
    function WithSelectedStyle(const AStyle: TStyle): IFileTree;
    function WithBlock(ABlock: IBlock): IFileTree;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TFileTreeState);
  end;

  TFileTree = class(TInterfacedObject, IWidget, IFileTree)
  private
    FStyle: TStyle;
    FDirStyle: TStyle;
    FFileStyle: TStyle;
    FSelectedStyle: TStyle;
    FBlock: IBlock;
  public
    class function New: IFileTree; static;

    { IFileTree builder }
    function WithStyle(const AStyle: TStyle): IFileTree;
    function WithDirStyle(const AStyle: TStyle): IFileTree;
    function WithFileStyle(const AStyle: TStyle): IFileTree;
    function WithSelectedStyle(const AStyle: TStyle): IFileTree;
    function WithBlock(ABlock: IBlock): IFileTree;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IFileTree stateful }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TFileTreeState);
  end;

implementation


{ TFileTreeState }

class function TFileTreeState.Empty: TFileTreeState;
begin
  Result.Nodes := nil;
  Result.Selected := 0;
  Result.ScrollY := 0;
end;

function TFileTreeState.AddNode(const AName: AnsiString; AIsDir: Boolean; ADepth: Integer): Integer;
var Idx: Integer;
begin
  Idx := Length(Nodes);
  SetLength(Nodes, Idx + 1);
  Nodes[Idx].Name := AName;
  Nodes[Idx].IsDir := AIsDir;
  Nodes[Idx].Depth := ADepth;
  Nodes[Idx].Expanded := AIsDir;
  Nodes[Idx].Children := nil;
  Result := Idx;
end;

procedure TFileTreeState.ToggleExpand;
begin
  if (Selected >= 0) and (Selected < Length(Nodes)) then
    if Nodes[Selected].IsDir then
      Nodes[Selected].Expanded := not Nodes[Selected].Expanded;
end;

procedure TFileTreeState.SelectNext;
begin
  if Selected < Length(Nodes) - 1 then Inc(Selected);
end;

procedure TFileTreeState.SelectPrev;
begin
  if Selected > 0 then Dec(Selected);
end;

function TFileTreeState.VisibleCount: Integer;
begin
  Result := Length(Nodes);
end;

{ Helper }

function IsNodeVisible(const Nodes: array of TFileNode; Idx: Integer): Boolean;
var I, D: Integer;
begin
  D := Nodes[Idx].Depth;
  if D = 0 then Exit(True);
  for I := Idx - 1 downto 0 do
  begin
    if Nodes[I].Depth < D then
    begin
      if Nodes[I].IsDir and (not Nodes[I].Expanded) then Exit(False);
      D := Nodes[I].Depth;
      if D = 0 then Break;
    end;
  end;
  Result := True;
end;

{ TFileTree }

class function TFileTree.New: IFileTree;
var
  LObj: TFileTree;
begin
  LObj := TFileTree.Create;
  LObj.FStyle := TStyle.Default;
  LObj.FDirStyle := TStyle.Default.WithFg(TUI_CYAN).WithModifier([mbBold]);
  LObj.FFileStyle := TStyle.Default;
  LObj.FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FBlock := nil;
  Result := LObj;
end;

function TFileTree.WithStyle(const AStyle: TStyle): IFileTree;
begin FStyle := AStyle; Result := Self; end;

function TFileTree.WithDirStyle(const AStyle: TStyle): IFileTree;
begin FDirStyle := AStyle; Result := Self; end;

function TFileTree.WithFileStyle(const AStyle: TStyle): IFileTree;
begin FFileStyle := AStyle; Result := Self; end;

function TFileTree.WithSelectedStyle(const AStyle: TStyle): IFileTree;
begin FSelectedStyle := AStyle; Result := Self; end;

function TFileTree.WithBlock(ABlock: IBlock): IFileTree;
begin FBlock := ABlock; Result := Self; end;

procedure TFileTree.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TFileTree.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TFileTreeState);
var
  Inner: TRect;
  I, Y, ViewH, VisIdx: Integer;
  Prefix, Display: AnsiString;
  LineSty: TStyle;
begin
  if AArea.IsEmpty then Exit;

  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  // Clamp state indices
  if Length(AState.Nodes) > 0 then
  begin
    if AState.Selected < 0 then AState.Selected := 0;
    if AState.Selected >= Length(AState.Nodes) then AState.Selected := Length(AState.Nodes) - 1;
  end
  else
    AState.Selected := 0;

  ViewH := Inner.Height;

  // Ensure selected visible
  if AState.Selected < AState.ScrollY then
    AState.ScrollY := AState.Selected;
  if AState.Selected >= AState.ScrollY + ViewH then
    AState.ScrollY := AState.Selected - ViewH + 1;

  Y := Inner.Y;
  VisIdx := 0;
  for I := 0 to High(AState.Nodes) do
  begin
    if not IsNodeVisible(AState.Nodes, I) then Continue;

    if VisIdx < AState.ScrollY then
    begin
      Inc(VisIdx);
      Continue;
    end;

    if Y >= Inner.Y + ViewH then Break;

    // Build prefix with indentation
    Prefix := StringOfChar(' ', AState.Nodes[I].Depth * 2);
    if AState.Nodes[I].IsDir then
    begin
      if AState.Nodes[I].Expanded then
        Prefix := Prefix + '[-] '
      else
        Prefix := Prefix + '[+] ';
      LineSty := FDirStyle;
    end
    else
    begin
      Prefix := Prefix + '    ';
      LineSty := FFileStyle;
    end;

    if I = AState.Selected then
      LineSty := FSelectedStyle;

    Display := Prefix + AState.Nodes[I].Name;
    ABuffer.SetStringN(Inner.X, Y, Display, Inner.Width, LineSty);

    Inc(Y);
    Inc(VisIdx);
  end;
end;

end.
