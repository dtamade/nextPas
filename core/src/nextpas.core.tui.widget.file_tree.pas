unit nextpas.core.tui.widget.file_tree;

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

  TFileTree = record
    Style: TStyle;
    DirStyle: TStyle;
    FileStyle: TStyle;
    SelectedStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Default: TFileTree; static;
    function WithStyle(const S: TStyle): TFileTree;
    function WithDirStyle(const S: TStyle): TFileTree;
    function WithFileStyle(const S: TStyle): TFileTree;
    function WithSelectedStyle(const S: TStyle): TFileTree;
    function WithBlock(const B: TBlock): TFileTree;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TFileTreeState);
  end;

implementation

uses
  SysUtils;

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

class function TFileTree.Default: TFileTree;
begin
  Result.Style := TStyle.Default;
  Result.DirStyle := TStyle.Default.WithFg(TUI_CYAN).WithModifier([mbBold]);
  Result.FileStyle := TStyle.Default;
  Result.SelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TFileTree.WithStyle(const S: TStyle): TFileTree;
begin Result := Self; Result.Style := S; end;

function TFileTree.WithDirStyle(const S: TStyle): TFileTree;
begin Result := Self; Result.DirStyle := S; end;

function TFileTree.WithFileStyle(const S: TStyle): TFileTree;
begin Result := Self; Result.FileStyle := S; end;

function TFileTree.WithSelectedStyle(const S: TStyle): TFileTree;
begin Result := Self; Result.SelectedStyle := S; end;

function TFileTree.WithBlock(const B: TBlock): TFileTree;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TFileTree.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TFileTreeState);
var
  Inner: TRect;
  I, Y, ViewH, VisIdx: Integer;
  Prefix, Display: AnsiString;
  LineSty: TStyle;
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

  // Clamp state indices
  if Length(State.Nodes) > 0 then
  begin
    if State.Selected < 0 then State.Selected := 0;
    if State.Selected >= Length(State.Nodes) then State.Selected := Length(State.Nodes) - 1;
  end
  else
    State.Selected := 0;

  ViewH := Inner.Height;

  // Ensure selected visible
  if State.Selected < State.ScrollY then
    State.ScrollY := State.Selected;
  if State.Selected >= State.ScrollY + ViewH then
    State.ScrollY := State.Selected - ViewH + 1;

  Y := Inner.Y;
  VisIdx := 0;
  for I := 0 to High(State.Nodes) do
  begin
    if not IsNodeVisible(State.Nodes, I) then Continue;

    if VisIdx < State.ScrollY then
    begin
      Inc(VisIdx);
      Continue;
    end;

    if Y >= Inner.Y + ViewH then Break;

    // Build prefix with indentation
    Prefix := StringOfChar(' ', State.Nodes[I].Depth * 2);
    if State.Nodes[I].IsDir then
    begin
      if State.Nodes[I].Expanded then
        Prefix := Prefix + '[-] '
      else
        Prefix := Prefix + '[+] ';
      LineSty := DirStyle;
    end
    else
    begin
      Prefix := Prefix + '    ';
      LineSty := FileStyle;
    end;

    if I = State.Selected then
      LineSty := SelectedStyle;

    Display := Prefix + State.Nodes[I].Name;
    ABuf.SetStringN(Inner.X, Y, Display, Inner.Width, LineSty);

    Inc(Y);
    Inc(VisIdx);
  end;
end;

end.
