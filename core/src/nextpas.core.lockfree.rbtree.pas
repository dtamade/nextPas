unit nextpas.core.lockfree.rbtree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TRBTreeResult = (rbInserted, rbUpdated, rbRemoved, rbNotFound, rbExists, rbClosed);
  TRBColor = (rbRed, rbBlack);

  PRBNode = ^TRBNode;
  TRBNode = record
    Key: Int64;
    Value: Int64;
    Color: TRBColor;
    Left, Right, Parent: PRBNode;
  end;

  TRBForEachCallback = procedure(AKey, AValue: Int64);

  {** @desc 并发红黑树
    @details 自平衡 BST，保证 O(log n) 查找/插入/删除。
      使用 per-tree spin lock 保护写操作。
      读操作通过 hazard pointer 或直接读取。
  }
  TConcurrentRBTree = class
  private type
    TRBEntry = record
      Key: Int64;
      Value: Int64;
    end;
    TRBEntries = array of TRBEntry;
  private
    FRoot: PRBNode;
    FNil: PRBNode;
    FCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    function CreateNode(AKey, AValue: Int64; AColor: TRBColor): PRBNode;
    procedure FreeNode(ANode: PRBNode);
    procedure RotateLeft(ANode: PRBNode);
    procedure RotateRight(ANode: PRBNode);
    procedure InsertFixup(ANode: PRBNode);
    procedure DeleteFixup(ANode: PRBNode);
    function FindMin(ANode: PRBNode): PRBNode;
    function FindNode(AKey: Int64): PRBNode;
    procedure Transplant(AOld, ANew: PRBNode);
    procedure ClearSubtree(ANode: PRBNode);
    procedure CollectSubtree(ANode: PRBNode; var AEntries: TRBEntries;
      var ACount: SizeInt);
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(AKey, AValue: Int64): TRBTreeResult;
    function Remove(AKey: Int64): TRBTreeResult;
    function Find(AKey: Int64; out AValue: Int64): Boolean;
    function Contains(AKey: Int64): Boolean;
    function GetCount: Int64;
    procedure ForEach(ACallback: TRBForEachCallback);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentRBTree.Create;
begin
  inherited Create;
  FClosed := 0;
  FLock := 0;
  FCount := 0;
  FNil := AllocMem(SizeOf(TRBNode));
  FNil^.Color := rbBlack;
  FNil^.Left := nil;
  FNil^.Right := nil;
  FNil^.Parent := nil;
  FRoot := FNil;
end;

destructor TConcurrentRBTree.Destroy;
begin
  Clear;
  FreeMem(FNil);
  inherited Destroy;
end;

procedure TConcurrentRBTree.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
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

procedure TConcurrentRBTree.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentRBTree.CreateNode(AKey, AValue: Int64; AColor: TRBColor): PRBNode;
begin
  Result := AllocMem(SizeOf(TRBNode));
  Result^.Key := AKey;
  Result^.Value := AValue;
  Result^.Color := AColor;
  Result^.Left := FNil;
  Result^.Right := FNil;
  Result^.Parent := FNil;
end;

procedure TConcurrentRBTree.FreeNode(ANode: PRBNode);
begin
  if ANode <> FNil then
    FreeMem(ANode);
end;

procedure TConcurrentRBTree.RotateLeft(ANode: PRBNode);
var
  LRight: PRBNode;
begin
  LRight := ANode^.Right;
  ANode^.Right := LRight^.Left;
  if LRight^.Left <> FNil then
    LRight^.Left^.Parent := ANode;
  LRight^.Parent := ANode^.Parent;
  if ANode^.Parent = FNil then
    FRoot := LRight
  else if ANode = ANode^.Parent^.Left then
    ANode^.Parent^.Left := LRight
  else
    ANode^.Parent^.Right := LRight;
  LRight^.Left := ANode;
  ANode^.Parent := LRight;
end;

procedure TConcurrentRBTree.RotateRight(ANode: PRBNode);
var
  LLeft: PRBNode;
begin
  LLeft := ANode^.Left;
  ANode^.Left := LLeft^.Right;
  if LLeft^.Right <> FNil then
    LLeft^.Right^.Parent := ANode;
  LLeft^.Parent := ANode^.Parent;
  if ANode^.Parent = FNil then
    FRoot := LLeft
  else if ANode = ANode^.Parent^.Right then
    ANode^.Parent^.Right := LLeft
  else
    ANode^.Parent^.Left := LLeft;
  LLeft^.Right := ANode;
  ANode^.Parent := LLeft;
end;

procedure TConcurrentRBTree.InsertFixup(ANode: PRBNode);
var
  LUncle: PRBNode;
begin
  while (ANode <> FRoot) and (ANode^.Parent^.Color = rbRed) do
  begin
    if ANode^.Parent = ANode^.Parent^.Parent^.Left then
    begin
      LUncle := ANode^.Parent^.Parent^.Right;
      if LUncle^.Color = rbRed then
      begin
        ANode^.Parent^.Color := rbBlack;
        LUncle^.Color := rbBlack;
        ANode^.Parent^.Parent^.Color := rbRed;
        ANode := ANode^.Parent^.Parent;
      end
      else
      begin
        if ANode = ANode^.Parent^.Right then
        begin
          ANode := ANode^.Parent;
          RotateLeft(ANode);
        end;
        ANode^.Parent^.Color := rbBlack;
        ANode^.Parent^.Parent^.Color := rbRed;
        RotateRight(ANode^.Parent^.Parent);
      end;
    end
    else
    begin
      LUncle := ANode^.Parent^.Parent^.Left;
      if LUncle^.Color = rbRed then
      begin
        ANode^.Parent^.Color := rbBlack;
        LUncle^.Color := rbBlack;
        ANode^.Parent^.Parent^.Color := rbRed;
        ANode := ANode^.Parent^.Parent;
      end
      else
      begin
        if ANode = ANode^.Parent^.Left then
        begin
          ANode := ANode^.Parent;
          RotateRight(ANode);
        end;
        ANode^.Parent^.Color := rbBlack;
        ANode^.Parent^.Parent^.Color := rbRed;
        RotateLeft(ANode^.Parent^.Parent);
      end;
    end;
  end;
  FRoot^.Color := rbBlack;
end;

procedure TConcurrentRBTree.DeleteFixup(ANode: PRBNode);
var
  LSibling: PRBNode;
begin
  while (ANode <> FRoot) and (ANode^.Color = rbBlack) do
  begin
    if ANode = ANode^.Parent^.Left then
    begin
      LSibling := ANode^.Parent^.Right;
      if LSibling^.Color = rbRed then
      begin
        LSibling^.Color := rbBlack;
        ANode^.Parent^.Color := rbRed;
        RotateLeft(ANode^.Parent);
        LSibling := ANode^.Parent^.Right;
      end;
      if (LSibling^.Left^.Color = rbBlack) and (LSibling^.Right^.Color = rbBlack) then
      begin
        LSibling^.Color := rbRed;
        ANode := ANode^.Parent;
      end
      else
      begin
        if LSibling^.Right^.Color = rbBlack then
        begin
          LSibling^.Left^.Color := rbBlack;
          LSibling^.Color := rbRed;
          RotateRight(LSibling);
          LSibling := ANode^.Parent^.Right;
        end;
        LSibling^.Color := ANode^.Parent^.Color;
        ANode^.Parent^.Color := rbBlack;
        LSibling^.Right^.Color := rbBlack;
        RotateLeft(ANode^.Parent);
        ANode := FRoot;
      end;
    end
    else
    begin
      LSibling := ANode^.Parent^.Left;
      if LSibling^.Color = rbRed then
      begin
        LSibling^.Color := rbBlack;
        ANode^.Parent^.Color := rbRed;
        RotateRight(ANode^.Parent);
        LSibling := ANode^.Parent^.Left;
      end;
      if (LSibling^.Right^.Color = rbBlack) and (LSibling^.Left^.Color = rbBlack) then
      begin
        LSibling^.Color := rbRed;
        ANode := ANode^.Parent;
      end
      else
      begin
        if LSibling^.Left^.Color = rbBlack then
        begin
          LSibling^.Right^.Color := rbBlack;
          LSibling^.Color := rbRed;
          RotateLeft(LSibling);
          LSibling := ANode^.Parent^.Left;
        end;
        LSibling^.Color := ANode^.Parent^.Color;
        ANode^.Parent^.Color := rbBlack;
        LSibling^.Left^.Color := rbBlack;
        RotateRight(ANode^.Parent);
        ANode := FRoot;
      end;
    end;
  end;
  ANode^.Color := rbBlack;
end;

function TConcurrentRBTree.FindMin(ANode: PRBNode): PRBNode;
begin
  while ANode^.Left <> FNil do
    ANode := ANode^.Left;
  Result := ANode;
end;

function TConcurrentRBTree.FindNode(AKey: Int64): PRBNode;
var
  LNode: PRBNode;
begin
  LNode := FRoot;
  while LNode <> FNil do
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

procedure TConcurrentRBTree.Transplant(AOld, ANew: PRBNode);
begin
  if AOld^.Parent = FNil then
    FRoot := ANew
  else if AOld = AOld^.Parent^.Left then
    AOld^.Parent^.Left := ANew
  else
    AOld^.Parent^.Right := ANew;
  ANew^.Parent := AOld^.Parent;
end;

function TConcurrentRBTree.Insert(AKey, AValue: Int64): TRBTreeResult;
var
  LParent, LCurrent, LNew: PRBNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rbClosed);
  Lock;
  LParent := FNil;
  LCurrent := FRoot;
  while LCurrent <> FNil do
  begin
    LParent := LCurrent;
    if AKey = LCurrent^.Key then
    begin
      LCurrent^.Value := AValue;
      Unlock;
      Exit(rbUpdated);
    end
    else if AKey < LCurrent^.Key then
      LCurrent := LCurrent^.Left
    else
      LCurrent := LCurrent^.Right;
  end;
  LNew := CreateNode(AKey, AValue, rbRed);
  LNew^.Parent := LParent;
  if LParent = FNil then
    FRoot := LNew
  else if AKey < LParent^.Key then
    LParent^.Left := LNew
  else
    LParent^.Right := LNew;
  InsertFixup(LNew);
  AtomicFetchAdd64(FCount, 1, moRelaxed);
  Unlock;
  Result := rbInserted;
end;

function TConcurrentRBTree.Remove(AKey: Int64): TRBTreeResult;
var
  LNode, LSuccessor, LChild: PRBNode;
  LColor: TRBColor;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rbClosed);
  Lock;
  LNode := FindNode(AKey);
  if LNode = nil then
  begin
    Unlock;
    Exit(rbNotFound);
  end;
  LColor := LNode^.Color;
  if LNode^.Left = FNil then
  begin
    LChild := LNode^.Right;
    Transplant(LNode, LNode^.Right);
  end
  else if LNode^.Right = FNil then
  begin
    LChild := LNode^.Left;
    Transplant(LNode, LNode^.Left);
  end
  else
  begin
    LSuccessor := FindMin(LNode^.Right);
    LColor := LSuccessor^.Color;
    LChild := LSuccessor^.Right;
    if LSuccessor^.Parent = LNode then
      LChild^.Parent := LSuccessor
    else
    begin
      Transplant(LSuccessor, LSuccessor^.Right);
      LSuccessor^.Right := LNode^.Right;
      LSuccessor^.Right^.Parent := LSuccessor;
    end;
    Transplant(LNode, LSuccessor);
    LSuccessor^.Left := LNode^.Left;
    LSuccessor^.Left^.Parent := LSuccessor;
    LSuccessor^.Color := LNode^.Color;
  end;
  FreeNode(LNode);
  if LColor = rbBlack then
    DeleteFixup(LChild);
  AtomicFetchSub64(FCount, 1, moRelaxed);
  Unlock;
  Result := rbRemoved;
end;

function TConcurrentRBTree.Find(AKey: Int64; out AValue: Int64): Boolean;
var
  LNode: PRBNode;
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

function TConcurrentRBTree.Contains(AKey: Int64): Boolean;
var
  LNode: PRBNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  Lock;
  LNode := FindNode(AKey);
  Unlock;
  Result := LNode <> nil;
end;

function TConcurrentRBTree.GetCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

procedure TConcurrentRBTree.CollectSubtree(ANode: PRBNode;
  var AEntries: TRBEntries; var ACount: SizeInt);
begin
  if ANode = FNil then
    Exit;
  CollectSubtree(ANode^.Left, AEntries, ACount);
  AEntries[ACount].Key := ANode^.Key;
  AEntries[ACount].Value := ANode^.Value;
  Inc(ACount);
  CollectSubtree(ANode^.Right, AEntries, ACount);
end;

procedure TConcurrentRBTree.ForEach(ACallback: TRBForEachCallback);
var
  LEntries: TRBEntries;
  LCount, LI: SizeInt;
begin
  if (AtomicLoad32(FClosed, moAcquire) <> 0) or not Assigned(ACallback) then
    Exit;
  Lock;
  try
    SetLength(LEntries, FCount);
    LCount := 0;
    CollectSubtree(FRoot, LEntries, LCount);
    SetLength(LEntries, LCount);
  finally
    Unlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LEntries[LI].Key, LEntries[LI].Value);
end;

procedure TConcurrentRBTree.ClearSubtree(ANode: PRBNode);
begin
  if ANode = FNil then
    Exit;
  ClearSubtree(ANode^.Left);
  ClearSubtree(ANode^.Right);
  FreeNode(ANode);
end;

procedure TConcurrentRBTree.Clear;
begin
  Lock;
  ClearSubtree(FRoot);
  FRoot := FNil;
  FCount := 0;
  Unlock;
end;

procedure TConcurrentRBTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentRBTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
