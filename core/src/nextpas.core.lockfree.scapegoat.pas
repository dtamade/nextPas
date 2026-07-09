unit nextpas.core.lockfree.scapegoat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TScapegoatResult = (sgInserted, sgUpdated, sgRemoved, sgNotFound, sgExists, sgClosed);
  TScapegoatForEachCallback = procedure(AKey, AValue: Int64);

  PScapegoatNode = ^TScapegoatNode;
  TScapegoatNode = record
    Key: Int64;
    Value: Int64;
    Left, Right, Parent: PScapegoatNode;
    Size: Int32;
  end;

  {** @desc 并发 Scapegoat Tree
    @details 无旋转平衡 BST，通过重建子树实现平衡。
      摊还 O(log n) 查找/插入/删除。
      并发友好：旋转时不需要复杂的指针操作。
  }
  TConcurrentScapegoatTree = class
  private
    FRoot: PScapegoatNode;
    FCount: Int64;
    FMaxCount: Int64;
    FAlpha: Double;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    function CreateNode(AKey, AValue: Int64; AParent: PScapegoatNode): PScapegoatNode;
    procedure FreeNode(ANode: PScapegoatNode);
    function NodeSize(ANode: PScapegoatNode): Int32;
    procedure UpdateSize(ANode: PScapegoatNode);
    function IsAlphaBalanced(ANode: PScapegoatNode): Boolean;
    function FindScapegoat(ANode: PScapegoatNode): PScapegoatNode;
    procedure RebuildSubtree(ANode: PScapegoatNode);
    procedure FlattenSubtree(ANode: PScapegoatNode; var AArray: array of PScapegoatNode; var AIdx: Integer);
    function BuildBalanced(AArray: array of PScapegoatNode; AStart, AEnd: Integer; AParent: PScapegoatNode): PScapegoatNode;
    function FindNode(AKey: Int64): PScapegoatNode;
    procedure ClearSubtree(ANode: PScapegoatNode);
    procedure ForEachSubtree(ANode: PScapegoatNode; ACallback: TScapegoatForEachCallback);
  public
    constructor Create(const AAlpha: Double = 0.7);
    destructor Destroy; override;
    function Insert(AKey, AValue: Int64): TScapegoatResult;
    function Remove(AKey: Int64): TScapegoatResult;
    function Find(AKey: Int64; out AValue: Int64): Boolean;
    function Contains(AKey: Int64): Boolean;
    function GetCount: Int64;
    procedure ForEach(ACallback: TScapegoatForEachCallback);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentScapegoatTree.Create(const AAlpha: Double);
begin
  if (AAlpha <= 0.5) or (AAlpha >= 1.0) then
    raise EArgumentError.Create('TConcurrentScapegoatTree: alpha must be in (0.5, 1.0)');
  inherited Create;
  FRoot := nil;
  FCount := 0;
  FMaxCount := 0;
  FAlpha := AAlpha;
  FLock := 0;
  FClosed := 0;
end;

destructor TConcurrentScapegoatTree.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TConcurrentScapegoatTree.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 1, 0) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TConcurrentScapegoatTree.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentScapegoatTree.CreateNode(AKey, AValue: Int64; AParent: PScapegoatNode): PScapegoatNode;
begin
  Result := AllocMem(SizeOf(TScapegoatNode));
  Result^.Key := AKey;
  Result^.Value := AValue;
  Result^.Left := nil;
  Result^.Right := nil;
  Result^.Parent := AParent;
  Result^.Size := 1;
end;

procedure TConcurrentScapegoatTree.FreeNode(ANode: PScapegoatNode);
begin
  if ANode <> nil then
    FreeMem(ANode);
end;

function TConcurrentScapegoatTree.NodeSize(ANode: PScapegoatNode): Int32;
begin
  if ANode = nil then
    Exit(0);
  Result := ANode^.Size;
end;

procedure TConcurrentScapegoatTree.UpdateSize(ANode: PScapegoatNode);
begin
  if ANode <> nil then
    ANode^.Size := 1 + NodeSize(ANode^.Left) + NodeSize(ANode^.Right);
end;

function TConcurrentScapegoatTree.IsAlphaBalanced(ANode: PScapegoatNode): Boolean;
var
  LLeftSize, LRightSize, LTotal: Int32;
begin
  if ANode = nil then
    Exit(True);
  LLeftSize := NodeSize(ANode^.Left);
  LRightSize := NodeSize(ANode^.Right);
  LTotal := 1 + LLeftSize + LRightSize;
  Result := (LLeftSize <= FAlpha * LTotal) and (LRightSize <= FAlpha * LTotal);
end;

function TConcurrentScapegoatTree.FindScapegoat(ANode: PScapegoatNode): PScapegoatNode;
var
  LNode: PScapegoatNode;
  LSize: Int32;
begin
  LNode := ANode;
  while LNode <> nil do
  begin
    if not IsAlphaBalanced(LNode) then
      Exit(LNode);
    LNode := LNode^.Parent;
  end;
  Result := nil;
end;

procedure TConcurrentScapegoatTree.FlattenSubtree(ANode: PScapegoatNode; var AArray: array of PScapegoatNode; var AIdx: Integer);
begin
  if ANode = nil then
    Exit;
  FlattenSubtree(ANode^.Left, AArray, AIdx);
  AArray[AIdx] := ANode;
  Inc(AIdx);
  FlattenSubtree(ANode^.Right, AArray, AIdx);
end;

function TConcurrentScapegoatTree.BuildBalanced(AArray: array of PScapegoatNode; AStart, AEnd: Integer; AParent: PScapegoatNode): PScapegoatNode;
var
  LMid: Integer;
  LNode: PScapegoatNode;
begin
  if AStart > AEnd then
    Exit(nil);
  LMid := (AStart + AEnd) div 2;
  LNode := AArray[LMid];
  LNode^.Parent := AParent;
  LNode^.Left := BuildBalanced(AArray, AStart, LMid - 1, LNode);
  LNode^.Right := BuildBalanced(AArray, LMid + 1, AEnd, LNode);
  UpdateSize(LNode);
  Result := LNode;
end;

procedure TConcurrentScapegoatTree.RebuildSubtree(ANode: PScapegoatNode);
var
  LSize: Integer;
  LArray: array of PScapegoatNode;
  LIdx: Integer;
  LParent: PScapegoatNode;
  LIsLeft: Boolean;
begin
  LSize := NodeSize(ANode);
  if LSize <= 1 then
    Exit;
  SetLength(LArray, LSize);
  LIdx := 0;
  FlattenSubtree(ANode, LArray, LIdx);
  LParent := ANode^.Parent;
  LIsLeft := (LParent <> nil) and (LParent^.Left = ANode);
  ANode := BuildBalanced(LArray, 0, LSize - 1, LParent);
  if LParent = nil then
    FRoot := ANode
  else if LIsLeft then
    LParent^.Left := ANode
  else
    LParent^.Right := ANode;
end;

function TConcurrentScapegoatTree.FindNode(AKey: Int64): PScapegoatNode;
var
  LNode: PScapegoatNode;
begin
  LNode := FRoot;
  while LNode <> nil do
  begin
    if AKey = LNode^.Key then
      Exit(LNode)
    else if AKey < LNode^.Key then
      LNode := LNode^.Left
    else
      LNode := LNode^.Right;
  end;
  Result := nil;
end;

function TConcurrentScapegoatTree.Insert(AKey, AValue: Int64): TScapegoatResult;
var
  LNode, LParent, LNew: PScapegoatNode;
  LDepth, LHeight: Int32;
  LScapegoat: PScapegoatNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(sgClosed);
  Lock;
  LParent := nil;
  LNode := FRoot;
  LDepth := 0;
  while LNode <> nil do
  begin
    LParent := LNode;
    if AKey = LNode^.Key then
    begin
      LNode^.Value := AValue;
      Unlock;
      Exit(sgUpdated);
    end
    else if AKey < LNode^.Key then
      LNode := LNode^.Left
    else
      LNode := LNode^.Right;
    Inc(LDepth);
  end;
  LNew := CreateNode(AKey, AValue, LParent);
  if LParent = nil then
    FRoot := LNew
  else if AKey < LParent^.Key then
    LParent^.Left := LNew
  else
    LParent^.Right := LNew;
  AtomicFetchAdd64(FCount, 1, moRelaxed);
  if FCount > FMaxCount then
    FMaxCount := FCount;
  LHeight := Round(Ln(Double(FCount)) / Ln(1.0 / FAlpha));
  if LDepth > LHeight then
  begin
    LScapegoat := FindScapegoat(LNew);
    if LScapegoat <> nil then
      RebuildSubtree(LScapegoat);
  end;
  Unlock;
  Result := sgInserted;
end;

function TConcurrentScapegoatTree.Remove(AKey: Int64): TScapegoatResult;
var
  LNode, LSuccessor, LParent: PScapegoatNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(sgClosed);
  Lock;
  LNode := FindNode(AKey);
  if LNode = nil then
  begin
    Unlock;
    Exit(sgNotFound);
  end;
  if (LNode^.Left = nil) and (LNode^.Right = nil) then
  begin
    LParent := LNode^.Parent;
    if LParent = nil then
      FRoot := nil
    else if LParent^.Left = LNode then
      LParent^.Left := nil
    else
      LParent^.Right := nil;
    FreeNode(LNode);
  end
  else if LNode^.Left = nil then
  begin
    LParent := LNode^.Parent;
    if LParent = nil then
      FRoot := LNode^.Right
    else if LParent^.Left = LNode then
      LParent^.Left := LNode^.Right
    else
      LParent^.Right := LNode^.Right;
    if LNode^.Right <> nil then
      LNode^.Right^.Parent := LParent;
    FreeNode(LNode);
  end
  else if LNode^.Right = nil then
  begin
    LParent := LNode^.Parent;
    if LParent = nil then
      FRoot := LNode^.Left
    else if LParent^.Left = LNode then
      LParent^.Left := LNode^.Left
    else
      LParent^.Right := LNode^.Left;
    if LNode^.Left <> nil then
      LNode^.Left^.Parent := LParent;
    FreeNode(LNode);
  end
  else
  begin
    LSuccessor := LNode^.Right;
    while LSuccessor^.Left <> nil do
      LSuccessor := LSuccessor^.Left;
    LNode^.Key := LSuccessor^.Key;
    LNode^.Value := LSuccessor^.Value;
    LParent := LSuccessor^.Parent;
    if LParent^.Left = LSuccessor then
      LParent^.Left := LSuccessor^.Right
    else
      LParent^.Right := LSuccessor^.Right;
    if LSuccessor^.Right <> nil then
      LSuccessor^.Right^.Parent := LParent;
    FreeNode(LSuccessor);
  end;
  AtomicFetchSub64(FCount, 1, moRelaxed);
  if FCount < FMaxCount * FAlpha * FAlpha then
  begin
    if FRoot <> nil then
      RebuildSubtree(FRoot);
    FMaxCount := FCount;
  end;
  Unlock;
  Result := sgRemoved;
end;

function TConcurrentScapegoatTree.Find(AKey: Int64; out AValue: Int64): Boolean;
var
  LNode: PScapegoatNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := 0;
    Exit(False);
  end;
  Lock;
  LNode := FindNode(AKey);
  if LNode <> nil then
  begin
    AValue := LNode^.Value;
    Unlock;
    Exit(True);
  end;
  Unlock;
  AValue := 0;
  Result := False;
end;

function TConcurrentScapegoatTree.Contains(AKey: Int64): Boolean;
var
  LNode: PScapegoatNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  Lock;
  LNode := FindNode(AKey);
  Unlock;
  Result := LNode <> nil;
end;

function TConcurrentScapegoatTree.GetCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

procedure TConcurrentScapegoatTree.ForEachSubtree(ANode: PScapegoatNode; ACallback: TScapegoatForEachCallback);
begin
  if ANode = nil then
    Exit;
  ForEachSubtree(ANode^.Left, ACallback);
  ACallback(ANode^.Key, ANode^.Value);
  ForEachSubtree(ANode^.Right, ACallback);
end;

procedure TConcurrentScapegoatTree.ForEach(ACallback: TScapegoatForEachCallback);
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  Lock;
  ForEachSubtree(FRoot, ACallback);
  Unlock;
end;

procedure TConcurrentScapegoatTree.ClearSubtree(ANode: PScapegoatNode);
begin
  if ANode = nil then
    Exit;
  ClearSubtree(ANode^.Left);
  ClearSubtree(ANode^.Right);
  FreeNode(ANode);
end;

procedure TConcurrentScapegoatTree.Clear;
begin
  Lock;
  ClearSubtree(FRoot);
  FRoot := nil;
  FCount := 0;
  FMaxCount := 0;
  Unlock;
end;

procedure TConcurrentScapegoatTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentScapegoatTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
