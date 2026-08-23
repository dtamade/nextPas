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
    { PH33 P5b：目录真扫描建态（复用 fs.dir FsReadDir，软失败不抛异常）。
      根节点恒建（basename）；Result=True=根可读且子树已扫。深度边界外
      的子目录保持收拢（children 未装载不假装展开） }
    function LoadDir(const APath: AnsiString; AMaxDepth: Integer;
      AShowHidden: Boolean): Boolean;
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

uses
  nextpas.core.exception,
  nextpas.core.fs.base,
  nextpas.core.fs.dir,
  nextpas.core.text.unicode;


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

{ PH33 P5b：LoadDir 私有辅助——路径收尾斜杠剥离 + '/'/'\' 双分隔符取
  basename（与 tui888 FileTreeRootOf 口径一致；core 侧自持不外泄） }
function FtStripTrailingSep(const APath: AnsiString): AnsiString;
begin
  Result := APath;
  while (Length(Result) > 1) and ((Result[Length(Result)] = '/') or
    (Result[Length(Result)] = '\')) do
    Delete(Result, Length(Result), 1);
end;

function FtBaseName(const APath: AnsiString): AnsiString;
var
  LStripped: AnsiString;
  I: Integer;
begin
  LStripped := FtStripTrailingSep(APath);
  for I := Length(LStripped) downto 1 do
    if (LStripped[I] = '/') or (LStripped[I] = '\') then
      Exit(Copy(LStripped, I + 1, Length(LStripped) - I));
  Result := LStripped;   { 无分隔符：整体即名；'/' 已被剥成根名本身 }
end;

function FtJoinPath(const ADir, AName: AnsiString): AnsiString;
begin
  if (ADir <> '') and (ADir[Length(ADir)] <> '/') and (ADir[Length(ADir)] <> '\') then
    Result := ADir + '/' + AName
  else
    Result := ADir + AName;
end;

{ 每层条目排序：目录在前，同类按 CompareText（Unicode 排序器）升序；
  插入排序——单层条目量级小，稳定性无关紧要、确定性靠全序 }
procedure FtSortEntries(var AEntries: TDirEntryArray);
var
  I, J: Integer;
  LTmp: TDirEntry;
begin
  for I := 1 to High(AEntries) do
  begin
    LTmp := AEntries[I];
    J := I - 1;
    while (J >= 0) and
      ((LTmp.IsDir and not AEntries[J].IsDir) or
       ((LTmp.IsDir = AEntries[J].IsDir) and
        (CompareText(LTmp.Name, AEntries[J].Name) < 0))) do
    begin
      AEntries[J + 1] := AEntries[J];
      Dec(J);
    end;
    AEntries[J + 1] := LTmp;
  end;
end;

function TFileTreeState.LoadDir(const APath: AnsiString; AMaxDepth: Integer;
  AShowHidden: Boolean): Boolean;

  procedure ScanDir(const ADirPath: AnsiString; ADepth: Integer);
  var
    LEntries: TDirEntryArray;
    I, LIdx: Integer;
  begin
    LEntries := FsReadDir(string(ADirPath));
    FtSortEntries(LEntries);
    for I := 0 to High(LEntries) do
    begin
      { 隐藏项（前导点）默认滤；./.. 平台层已滤（platform_dir_read 契约）}
      if not AShowHidden and (LEntries[I].Name <> '') and
        (LEntries[I].Name[1] = '.') then
        Continue;
      { 符号链接 ftSymlink→IsDir=False 不跟随（天然防环） }
      LIdx := AddNode(AnsiString(LEntries[I].Name), LEntries[I].IsDir, ADepth);
      if LEntries[I].IsDir then
      begin
        if ADepth < AMaxDepth then
          ScanDir(FtJoinPath(ADirPath, AnsiString(LEntries[I].Name)), ADepth + 1)
        else
          Nodes[LIdx].Expanded := False;   { 边界外未装载：诚实收拢 }
      end;
    end;
  end;

var
  LRoot: Integer;
  LStripped: AnsiString;
begin
  Result := False;
  if APath = '' then Exit;              { 空路径：无节点 }
  Nodes := nil;
  Selected := 0;
  ScrollY := 0;
  LStripped := FtStripTrailingSep(APath);
  LRoot := AddNode(FtBaseName(APath), True, 0);
  Nodes[LRoot].Expanded := False;       { 读成功前先收拢 }
  if AMaxDepth < 0 then AMaxDepth := 0;
  try
    if AMaxDepth > 0 then
      ScanDir(LStripped, 1);
    Nodes[LRoot].Expanded := True;
    Result := True;
  except
    on E: ENextPasError do
      SetLength(Nodes, LRoot + 1);      { 中途读失败软着陆：截回单根态 }
  end;
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
