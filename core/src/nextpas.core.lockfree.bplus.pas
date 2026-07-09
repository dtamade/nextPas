unit nextpas.core.lockfree.bplus;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  BPLUS_ORDER = 32;
  BPLUS_MAX_KEYS = BPLUS_ORDER - 1;
  BPLUS_MIN_KEYS = (BPLUS_ORDER - 1) div 2;

type
  TBplusResult = (bpInserted, bpUpdated, bpRemoved, bpNotFound, bpExists, bpClosed);
  TBplusForEachCallback = procedure(AKey, AValue: Int64);
  TBplusRangeCallback = procedure(AKey, AValue: Int64; var AContinue: Boolean);

  PBplusNode = ^TBplusNode;
  TBplusNode = record
    IsLeaf: Boolean;
    KeyCount: Int32;
    Keys: array[0..BPLUS_MAX_KEYS - 1] of Int64;
    case Boolean of
      True: (
        Values: array[0..BPLUS_MAX_KEYS - 1] of Int64;
        Next: PBplusNode;
      );
      False: (
        Children: array[0..BPLUS_MAX_KEYS] of PBplusNode;
      );
  end;

  {** @desc 并发 B+ Tree
    @details 数据库索引标准结构。
      叶子节点通过链表连接，支持高效范围查询。
      所有数据存储在叶子节点，内部节点只存索引。
  }
  TConcurrentBPlusTree = class
  private
    FRoot: PBplusNode;
    FFirstLeaf: PBplusNode;
    FCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    function CreateLeaf: PBplusNode;
    function CreateInternal: PBplusNode;
    procedure FreeNode(ANode: PBplusNode);
    function FindLeaf(AKey: Int64): PBplusNode;
    function SplitLeaf(ALeaf: PBplusNode): PBplusNode;
    function SplitInternal(AParent: PBplusNode; AIdx: Integer): PBplusNode;
    procedure InsertInternal(AParent: PBplusNode; AKey: Int64; ARight: PBplusNode);
    function BorrowFromLeft(ALeaf: PBplusNode; ALeft: PBplusNode): Boolean;
    function BorrowFromRight(ALeaf: PBplusNode; ARight: PBplusNode): Boolean;
    function MergeLeaves(ALeft: PBplusNode; ARight: PBplusNode): Boolean;
    procedure ClearSubtree(ANode: PBplusNode);
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(AKey, AValue: Int64): TBplusResult;
    function Remove(AKey: Int64): TBplusResult;
    function Find(AKey: Int64; out AValue: Int64): Boolean;
    function Contains(AKey: Int64): Boolean;
    function GetCount: Int64;
    procedure ForEach(ACallback: TBplusForEachCallback);
    procedure RangeQuery(ALow, AHigh: Int64; ACallback: TBplusRangeCallback);
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentBPlusTree.Create;
begin
  inherited Create;
  FRoot := CreateLeaf;
  FFirstLeaf := FRoot;
  FCount := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TConcurrentBPlusTree.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TConcurrentBPlusTree.Lock;
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

procedure TConcurrentBPlusTree.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentBPlusTree.CreateLeaf: PBplusNode;
begin
  Result := AllocMem(SizeOf(TBplusNode));
  Result^.IsLeaf := True;
  Result^.KeyCount := 0;
  Result^.Next := nil;
end;

function TConcurrentBPlusTree.CreateInternal: PBplusNode;
begin
  Result := AllocMem(SizeOf(TBplusNode));
  Result^.IsLeaf := False;
  Result^.KeyCount := 0;
end;

procedure TConcurrentBPlusTree.FreeNode(ANode: PBplusNode);
begin
  if ANode <> nil then
    FreeMem(ANode);
end;

function TConcurrentBPlusTree.FindLeaf(AKey: Int64): PBplusNode;
var
  LNode: PBplusNode;
  LI: Integer;
begin
  LNode := FRoot;
  while not LNode^.IsLeaf do
  begin
    LI := 0;
    while (LI < LNode^.KeyCount) and (AKey >= LNode^.Keys[LI]) do
      Inc(LI);
    LNode := LNode^.Children[LI];
  end;
  Result := LNode;
end;

function TConcurrentBPlusTree.SplitLeaf(ALeaf: PBplusNode): PBplusNode;
var
  LNewLeaf: PBplusNode;
  LSplit, LI: Integer;
begin
  LNewLeaf := CreateLeaf;
  LSplit := (ALeaf^.KeyCount + 1) div 2;
  for LI := LSplit to ALeaf^.KeyCount - 1 do
  begin
    LNewLeaf^.Keys[LI - LSplit] := ALeaf^.Keys[LI];
    LNewLeaf^.Values[LI - LSplit] := ALeaf^.Values[LI];
  end;
  LNewLeaf^.KeyCount := ALeaf^.KeyCount - LSplit;
  ALeaf^.KeyCount := LSplit;
  LNewLeaf^.Next := ALeaf^.Next;
  ALeaf^.Next := LNewLeaf;
  Result := LNewLeaf;
end;

function TConcurrentBPlusTree.SplitInternal(AParent: PBplusNode; AIdx: Integer): PBplusNode;
var
  LChild, LNew: PBplusNode;
  LSplit, LI: Integer;
  LMidKey: Int64;
begin
  LChild := AParent^.Children[AIdx];
  LNew := CreateInternal;
  LSplit := (LChild^.KeyCount + 1) div 2;
  LMidKey := LChild^.Keys[LSplit];
  for LI := LSplit + 1 to LChild^.KeyCount - 1 do
  begin
    LNew^.Keys[LI - LSplit - 1] := LChild^.Keys[LI];
    LNew^.Children[LI - LSplit - 1] := LChild^.Children[LI];
  end;
  LNew^.Children[LChild^.KeyCount - LSplit - 1] := LChild^.Children[LChild^.KeyCount];
  LNew^.KeyCount := LChild^.KeyCount - LSplit - 1;
  LChild^.KeyCount := LSplit;
  InsertInternal(AParent, LMidKey, LNew);
  Result := LNew;
end;

procedure TConcurrentBPlusTree.InsertInternal(AParent: PBplusNode; AKey: Int64; ARight: PBplusNode);
var
  LI: Integer;
begin
  LI := AParent^.KeyCount;
  while (LI > 0) and (AParent^.Keys[LI - 1] > AKey) do
  begin
    AParent^.Keys[LI] := AParent^.Keys[LI - 1];
    AParent^.Children[LI + 1] := AParent^.Children[LI];
    Dec(LI);
  end;
  AParent^.Keys[LI] := AKey;
  AParent^.Children[LI + 1] := ARight;
  Inc(AParent^.KeyCount);
end;

function TConcurrentBPlusTree.Insert(AKey, AValue: Int64): TBplusResult;
var
  LLeaf: PBplusNode;
  LI, LJ: Integer;
  LNewRoot, LNewLeaf, LSplitRight: PBplusNode;
  LMidKey: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(bpClosed);
  Lock;
  LLeaf := FindLeaf(AKey);
  LI := 0;
  while (LI < LLeaf^.KeyCount) and (LLeaf^.Keys[LI] < AKey) do
    Inc(LI);
  if (LI < LLeaf^.KeyCount) and (LLeaf^.Keys[LI] = AKey) then
  begin
    LLeaf^.Values[LI] := AValue;
    Unlock;
    Exit(bpUpdated);
  end;
  for LJ := LLeaf^.KeyCount downto LI + 1 do
  begin
    LLeaf^.Keys[LJ] := LLeaf^.Keys[LJ - 1];
    LLeaf^.Values[LJ] := LLeaf^.Values[LJ - 1];
  end;
  LLeaf^.Keys[LI] := AKey;
  LLeaf^.Values[LI] := AValue;
  Inc(LLeaf^.KeyCount);
  AtomicFetchAdd64(FCount, 1, moRelaxed);
  if LLeaf^.KeyCount = BPLUS_MAX_KEYS then
  begin
    LNewLeaf := SplitLeaf(LLeaf);
    if LLeaf = FRoot then
    begin
      LNewRoot := CreateInternal;
      LNewRoot^.Keys[0] := LNewLeaf^.Keys[0];
      LNewRoot^.Children[0] := LLeaf;
      LNewRoot^.Children[1] := LNewLeaf;
      LNewRoot^.KeyCount := 1;
      FRoot := LNewRoot;
    end
    else
    begin
      InsertInternal(FRoot, LNewLeaf^.Keys[0], LNewLeaf);
    end;
  end;
  Unlock;
  Result := bpInserted;
end;

function TConcurrentBPlusTree.Remove(AKey: Int64): TBplusResult;
var
  LLeaf: PBplusNode;
  LI, LJ: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(bpClosed);
  Lock;
  LLeaf := FindLeaf(AKey);
  LI := 0;
  while (LI < LLeaf^.KeyCount) and (LLeaf^.Keys[LI] < AKey) do
    Inc(LI);
  if (LI >= LLeaf^.KeyCount) or (LLeaf^.Keys[LI] <> AKey) then
  begin
    Unlock;
    Exit(bpNotFound);
  end;
  for LJ := LI to LLeaf^.KeyCount - 2 do
  begin
    LLeaf^.Keys[LJ] := LLeaf^.Keys[LJ + 1];
    LLeaf^.Values[LJ] := LLeaf^.Values[LJ + 1];
  end;
  Dec(LLeaf^.KeyCount);
  AtomicFetchSub64(FCount, 1, moRelaxed);
  Unlock;
  Result := bpRemoved;
end;

function TConcurrentBPlusTree.Find(AKey: Int64; out AValue: Int64): Boolean;
var
  LLeaf: PBplusNode;
  LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := 0;
    Exit(False);
  end;
  Lock;
  LLeaf := FindLeaf(AKey);
  for LI := 0 to LLeaf^.KeyCount - 1 do
  begin
    if LLeaf^.Keys[LI] = AKey then
    begin
      AValue := LLeaf^.Values[LI];
      Unlock;
      Exit(True);
    end;
  end;
  Unlock;
  AValue := 0;
  Result := False;
end;

function TConcurrentBPlusTree.Contains(AKey: Int64): Boolean;
var
  LValue: Int64;
begin
  Result := Find(AKey, LValue);
end;

function TConcurrentBPlusTree.GetCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

procedure TConcurrentBPlusTree.ForEach(ACallback: TBplusForEachCallback);
var
  LLeaf: PBplusNode;
  LI: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  Lock;
  LLeaf := FFirstLeaf;
  while LLeaf <> nil do
  begin
    for LI := 0 to LLeaf^.KeyCount - 1 do
      ACallback(LLeaf^.Keys[LI], LLeaf^.Values[LI]);
    LLeaf := LLeaf^.Next;
  end;
  Unlock;
end;

procedure TConcurrentBPlusTree.RangeQuery(ALow, AHigh: Int64; ACallback: TBplusRangeCallback);
var
  LLeaf: PBplusNode;
  LI: Integer;
  LContinue: Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  Lock;
  LLeaf := FindLeaf(ALow);
  LContinue := True;
  while LLeaf <> nil do
  begin
    for LI := 0 to LLeaf^.KeyCount - 1 do
    begin
      if LLeaf^.Keys[LI] > AHigh then
      begin
        Unlock;
        Exit;
      end;
      if LLeaf^.Keys[LI] >= ALow then
      begin
        ACallback(LLeaf^.Keys[LI], LLeaf^.Values[LI], LContinue);
        if not LContinue then
        begin
          Unlock;
          Exit;
        end;
      end;
    end;
    LLeaf := LLeaf^.Next;
  end;
  Unlock;
end;

procedure TConcurrentBPlusTree.ClearSubtree(ANode: PBplusNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  if not ANode^.IsLeaf then
  begin
    for LI := 0 to ANode^.KeyCount do
      ClearSubtree(ANode^.Children[LI]);
  end;
  FreeNode(ANode);
end;

procedure TConcurrentBPlusTree.Clear;
begin
  Lock;
  ClearSubtree(FRoot);
  FRoot := CreateLeaf;
  FFirstLeaf := FRoot;
  FCount := 0;
  Unlock;
end;

procedure TConcurrentBPlusTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentBPlusTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentBPlusTree.BorrowFromLeft(ALeaf: PBplusNode; ALeft: PBplusNode): Boolean;
begin
  if ALeft^.KeyCount <= BPLUS_MIN_KEYS then
    Exit(False);
  Dec(ALeft^.KeyCount);
  Inc(ALeaf^.KeyCount);
end;

function TConcurrentBPlusTree.BorrowFromRight(ALeaf: PBplusNode; ARight: PBplusNode): Boolean;
begin
  if ARight^.KeyCount <= BPLUS_MIN_KEYS then
    Exit(False);
  Inc(ALeaf^.KeyCount);
  Dec(ARight^.KeyCount);
end;

function TConcurrentBPlusTree.MergeLeaves(ALeft: PBplusNode; ARight: PBplusNode): Boolean;
begin
  if ALeft^.KeyCount + ARight^.KeyCount > BPLUS_MAX_KEYS then
    Exit(False);
  ALeft^.Next := ARight^.Next;
  FreeNode(ARight);
  Result := True;
end;

end.
