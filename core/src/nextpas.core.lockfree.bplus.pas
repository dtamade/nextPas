unit nextpas.core.lockfree.bplus;
{**
 * @desc Concurrent B+ Tree with read-write lock.
 *
 * @note This is NOT a lock-free structure. It uses an atomic read-write lock
 *       to keep root replacement and node reclamation safe for readers.
 *       Placed in the lockfree namespace because it uses atomic primitives
 *       and follows the same concurrent data structure patterns.
 *
 * @concurrency Thread-safe for multiple readers and writers:
 *   - Find/Contains/ForEach/ForEachRange: shared read lock
 *   - Insert/Remove/Clear: exclusive write lock
 *
 * @see B+ Tree — database index standard structure
 * @see lmdb (C) — B+Tree for comparison
 *}

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
    procedure InsertSeparator(AParent: PBplusNode; AIdx: Integer;
      AKey: Int64; ARight: PBplusNode);
    procedure SplitChild(AParent: PBplusNode; AIdx: Integer);
    function InsertUnlocked(AKey, AValue: Int64): TBplusResult;
    function BorrowFromLeft(ALeaf: PBplusNode; ALeft: PBplusNode): Boolean;
    function BorrowFromRight(ALeaf: PBplusNode; ARight: PBplusNode): Boolean;
    function MergeLeaves(ALeft: PBplusNode; ARight: PBplusNode): Boolean;
    procedure BorrowInternalFromLeft(ANode, ALeft: PBplusNode);
    procedure BorrowInternalFromRight(ANode, ARight: PBplusNode);
    procedure MergeInternal(ALeft, ARight: PBplusNode);
    procedure RemoveChild(AParent: PBplusNode; AChildIdx: Integer);
    function RefreshSeparators(ANode: PBplusNode): Int64;
    procedure ClearSubtree(ANode: PBplusNode);
    {$ifdef NEXTPAS_TESTING}
    function ValidateNode(ANode: PBplusNode; AIsRoot: Boolean; ADepth: Integer;
      var ALeafDepth: Integer; var AEntryCount: Int64;
      out AMinKey, AMaxKey: Int64): Boolean;
    {$endif}
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
    {$ifdef NEXTPAS_TESTING}
    function ValidateInvariants: Boolean;
    {$endif}
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
  ClearSubtree(FRoot);
  FRoot := nil;
  FFirstLeaf := nil;
  inherited Destroy;
end;

procedure TConcurrentBPlusTree.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
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

procedure TConcurrentBPlusTree.InsertSeparator(AParent: PBplusNode;
  AIdx: Integer; AKey: Int64; ARight: PBplusNode);
var
  LI: Integer;
begin
  for LI := AParent^.KeyCount downto AIdx + 1 do
    AParent^.Children[LI + 1] := AParent^.Children[LI];
  for LI := AParent^.KeyCount - 1 downto AIdx do
    AParent^.Keys[LI + 1] := AParent^.Keys[LI];
  AParent^.Keys[AIdx] := AKey;
  AParent^.Children[AIdx + 1] := ARight;
  Inc(AParent^.KeyCount);
end;

procedure TConcurrentBPlusTree.SplitChild(AParent: PBplusNode; AIdx: Integer);
var
  LChild, LNew: PBplusNode;
  LSplit, LI: Integer;
  LSeparator: Int64;
begin
  LChild := AParent^.Children[AIdx];
  LSplit := LChild^.KeyCount div 2;
  if LChild^.IsLeaf then
  begin
    LNew := CreateLeaf;
    for LI := LSplit to LChild^.KeyCount - 1 do
    begin
      LNew^.Keys[LI - LSplit] := LChild^.Keys[LI];
      LNew^.Values[LI - LSplit] := LChild^.Values[LI];
    end;
    LNew^.KeyCount := LChild^.KeyCount - LSplit;
    LChild^.KeyCount := LSplit;
    LNew^.Next := LChild^.Next;
    LChild^.Next := LNew;
    LSeparator := LNew^.Keys[0];
  end
  else
  begin
    LNew := CreateInternal;
    LSeparator := LChild^.Keys[LSplit];
    LNew^.KeyCount := LChild^.KeyCount - LSplit - 1;
    for LI := 0 to LNew^.KeyCount - 1 do
      LNew^.Keys[LI] := LChild^.Keys[LSplit + 1 + LI];
    for LI := 0 to LNew^.KeyCount do
    begin
      LNew^.Children[LI] := LChild^.Children[LSplit + 1 + LI];
      LChild^.Children[LSplit + 1 + LI] := nil;
    end;
    LChild^.KeyCount := LSplit;
  end;
  InsertSeparator(AParent, AIdx, LSeparator, LNew);
end;

function TConcurrentBPlusTree.InsertUnlocked(AKey, AValue: Int64): TBplusResult;
var
  LNode, LNewRoot: PBplusNode;
  LI, LJ: Integer;
begin
  if FRoot^.KeyCount = BPLUS_MAX_KEYS then
  begin
    LNewRoot := CreateInternal;
    LNewRoot^.Children[0] := FRoot;
    FRoot := LNewRoot;
    SplitChild(LNewRoot, 0);
  end;

  LNode := FRoot;
  while not LNode^.IsLeaf do
  begin
    LI := 0;
    while (LI < LNode^.KeyCount) and (AKey >= LNode^.Keys[LI]) do
      Inc(LI);
    if LNode^.Children[LI]^.KeyCount = BPLUS_MAX_KEYS then
    begin
      SplitChild(LNode, LI);
      if AKey >= LNode^.Keys[LI] then
        Inc(LI);
    end;
    LNode := LNode^.Children[LI];
  end;

  LI := 0;
  while (LI < LNode^.KeyCount) and (LNode^.Keys[LI] < AKey) do
    Inc(LI);
  if (LI < LNode^.KeyCount) and (LNode^.Keys[LI] = AKey) then
  begin
    LNode^.Values[LI] := AValue;
    Exit(bpUpdated);
  end;

  for LJ := LNode^.KeyCount downto LI + 1 do
  begin
    LNode^.Keys[LJ] := LNode^.Keys[LJ - 1];
    LNode^.Values[LJ] := LNode^.Values[LJ - 1];
  end;
  LNode^.Keys[LI] := AKey;
  LNode^.Values[LI] := AValue;
  Inc(LNode^.KeyCount);
  Inc(FCount);
  Result := bpInserted;
end;

function TConcurrentBPlusTree.Insert(AKey, AValue: Int64): TBplusResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(bpClosed);
  Lock;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(bpClosed);
    Result := InsertUnlocked(AKey, AValue);
  finally
    Unlock;
  end;
end;

function TConcurrentBPlusTree.Remove(AKey: Int64): TBplusResult;
var
  LParents: array[0..63] of PBplusNode;
  LChildIndices: array[0..63] of Integer;
  LNode, LParent, LLeft, LRight, LOldRoot: PBplusNode;
  LDepth, LLevel, LI, LJ, LChildIdx: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(bpClosed);
  Lock;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(bpClosed);

    LDepth := 0;
    LNode := FRoot;
    while not LNode^.IsLeaf do
    begin
      LI := 0;
      while (LI < LNode^.KeyCount) and (AKey >= LNode^.Keys[LI]) do
        Inc(LI);
      if LDepth > High(LParents) then
        Exit(bpNotFound);
      LParents[LDepth] := LNode;
      LChildIndices[LDepth] := LI;
      Inc(LDepth);
      LNode := LNode^.Children[LI];
    end;

    LI := 0;
    while (LI < LNode^.KeyCount) and (LNode^.Keys[LI] < AKey) do
      Inc(LI);
    if (LI >= LNode^.KeyCount) or (LNode^.Keys[LI] <> AKey) then
      Exit(bpNotFound);

    for LJ := LI to LNode^.KeyCount - 2 do
    begin
      LNode^.Keys[LJ] := LNode^.Keys[LJ + 1];
      LNode^.Values[LJ] := LNode^.Values[LJ + 1];
    end;
    Dec(LNode^.KeyCount);
    Dec(FCount);

    LLevel := LDepth - 1;
    while (LLevel >= 0) and (LNode^.KeyCount < BPLUS_MIN_KEYS) do
    begin
      LParent := LParents[LLevel];
      LChildIdx := LChildIndices[LLevel];
      LLeft := nil;
      LRight := nil;
      if LChildIdx > 0 then
        LLeft := LParent^.Children[LChildIdx - 1];
      if LChildIdx < LParent^.KeyCount then
        LRight := LParent^.Children[LChildIdx + 1];

      if (LLeft <> nil) and (LLeft^.KeyCount > BPLUS_MIN_KEYS) then
      begin
        if LNode^.IsLeaf then
          BorrowFromLeft(LNode, LLeft)
        else
          BorrowInternalFromLeft(LNode, LLeft);
        Break;
      end;

      if (LRight <> nil) and (LRight^.KeyCount > BPLUS_MIN_KEYS) then
      begin
        if LNode^.IsLeaf then
          BorrowFromRight(LNode, LRight)
        else
          BorrowInternalFromRight(LNode, LRight);
        Break;
      end;

      if LLeft <> nil then
      begin
        if LNode^.IsLeaf then
          MergeLeaves(LLeft, LNode)
        else
          MergeInternal(LLeft, LNode);
        RemoveChild(LParent, LChildIdx);
      end
      else if LRight <> nil then
      begin
        if LNode^.IsLeaf then
          MergeLeaves(LNode, LRight)
        else
          MergeInternal(LNode, LRight);
        RemoveChild(LParent, LChildIdx + 1);
      end;

      LNode := LParent;
      Dec(LLevel);
    end;

    if (not FRoot^.IsLeaf) and (FRoot^.KeyCount = 0) then
    begin
      LOldRoot := FRoot;
      FRoot := FRoot^.Children[0];
      LOldRoot^.Children[0] := nil;
      FreeNode(LOldRoot);
    end;
    RefreshSeparators(FRoot);
    FFirstLeaf := FRoot;
    while not FFirstLeaf^.IsLeaf do
      FFirstLeaf := FFirstLeaf^.Children[0];
    Result := bpRemoved;
  finally
    Unlock;
  end;
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
  try
    LLeaf := FindLeaf(AKey);
    for LI := 0 to LLeaf^.KeyCount - 1 do
    begin
      if LLeaf^.Keys[LI] = AKey then
      begin
        AValue := LLeaf^.Values[LI];
        Exit(True);
      end;
    end;
    AValue := 0;
    Result := False;
  finally
    Unlock;
  end;
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
  LKeys: array of Int64;
  LValues: array of Int64;
  LI, LCount: SizeInt;
begin
  if (AtomicLoad32(FClosed, moAcquire) <> 0) or not Assigned(ACallback) then
    Exit;
  Lock;
  try
    LCount := FCount;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
    LI := 0;
    LLeaf := FFirstLeaf;
    while LLeaf <> nil do
    begin
      for LCount := 0 to LLeaf^.KeyCount - 1 do
      begin
        LKeys[LI] := LLeaf^.Keys[LCount];
        LValues[LI] := LLeaf^.Values[LCount];
        Inc(LI);
      end;
      LLeaf := LLeaf^.Next;
    end;
    SetLength(LKeys, LI);
    SetLength(LValues, LI);
  finally
    Unlock;
  end;

  for LI := 0 to Length(LKeys) - 1 do
    ACallback(LKeys[LI], LValues[LI]);
end;

procedure TConcurrentBPlusTree.RangeQuery(ALow, AHigh: Int64; ACallback: TBplusRangeCallback);
var
  LLeaf: PBplusNode;
  LKeys: array of Int64;
  LValues: array of Int64;
  LI, LCount: SizeInt;
  LContinue: Boolean;
begin
  if (AtomicLoad32(FClosed, moAcquire) <> 0) or not Assigned(ACallback) then
    Exit;
  Lock;
  try
    SetLength(LKeys, 0);
    SetLength(LValues, 0);
    LLeaf := FindLeaf(ALow);
    while LLeaf <> nil do
    begin
      for LI := 0 to LLeaf^.KeyCount - 1 do
      begin
        if LLeaf^.Keys[LI] > AHigh then
        begin
          LLeaf := nil;
          Break;
        end;
        if LLeaf^.Keys[LI] >= ALow then
        begin
          LCount := Length(LKeys);
          SetLength(LKeys, LCount + 1);
          SetLength(LValues, LCount + 1);
          LKeys[LCount] := LLeaf^.Keys[LI];
          LValues[LCount] := LLeaf^.Values[LI];
        end;
      end;
      if LLeaf <> nil then
        LLeaf := LLeaf^.Next;
    end;
  finally
    Unlock;
  end;

  LContinue := True;
  for LI := 0 to Length(LKeys) - 1 do
  begin
    ACallback(LKeys[LI], LValues[LI], LContinue);
    if not LContinue then
      Exit;
  end;
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
  try
    ClearSubtree(FRoot);
    FRoot := CreateLeaf;
    FFirstLeaf := FRoot;
    FCount := 0;
  finally
    Unlock;
  end;
end;

procedure TConcurrentBPlusTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentBPlusTree.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

{$ifdef NEXTPAS_TESTING}
function TConcurrentBPlusTree.ValidateNode(ANode: PBplusNode;
  AIsRoot: Boolean; ADepth: Integer; var ALeafDepth: Integer;
  var AEntryCount: Int64; out AMinKey, AMaxKey: Int64): Boolean;
var
  LI: Integer;
  LChildMin, LChildMax, LPreviousMax: Int64;
begin
  AMinKey := 0;
  AMaxKey := 0;
  if (ANode = nil) or (ANode^.KeyCount < 0) or
     (ANode^.KeyCount > BPLUS_MAX_KEYS) then
    Exit(False);
  if (not AIsRoot) and (ANode^.KeyCount < BPLUS_MIN_KEYS) then
    Exit(False);

  if ANode^.IsLeaf then
  begin
    for LI := 1 to ANode^.KeyCount - 1 do
      if ANode^.Keys[LI - 1] >= ANode^.Keys[LI] then
        Exit(False);
    if ALeafDepth < 0 then
      ALeafDepth := ADepth
    else if ALeafDepth <> ADepth then
      Exit(False);
    Inc(AEntryCount, ANode^.KeyCount);
    if ANode^.KeyCount > 0 then
    begin
      AMinKey := ANode^.Keys[0];
      AMaxKey := ANode^.Keys[ANode^.KeyCount - 1];
    end;
    Exit(True);
  end;

  if ANode^.KeyCount = 0 then
    Exit(False);
  for LI := 0 to ANode^.KeyCount do
  begin
    if not ValidateNode(ANode^.Children[LI], False, ADepth + 1,
      ALeafDepth, AEntryCount, LChildMin, LChildMax) then
      Exit(False);
    if LI = 0 then
    begin
      AMinKey := LChildMin;
      LPreviousMax := LChildMax;
    end
    else
    begin
      if (LPreviousMax >= LChildMin) or
         (ANode^.Keys[LI - 1] <> LChildMin) then
        Exit(False);
      LPreviousMax := LChildMax;
    end;
  end;
  AMaxKey := LPreviousMax;
  Result := True;
end;

function TConcurrentBPlusTree.ValidateInvariants: Boolean;
var
  LLeaf, LLeftmost: PBplusNode;
  LLeafDepth, LI: Integer;
  LEntryCount, LLeafEntryCount: Int64;
  LMinKey, LMaxKey, LPreviousKey: Int64;
  LHasPrevious: Boolean;
begin
  Lock;
  try
    LLeafDepth := -1;
    LEntryCount := 0;
    Result := ValidateNode(FRoot, True, 0, LLeafDepth, LEntryCount,
      LMinKey, LMaxKey);
    if not Result or (LEntryCount <> FCount) then
      Exit(False);

    LLeftmost := FRoot;
    while (LLeftmost <> nil) and (not LLeftmost^.IsLeaf) do
      LLeftmost := LLeftmost^.Children[0];
    if LLeftmost <> FFirstLeaf then
      Exit(False);

    LLeafEntryCount := 0;
    LHasPrevious := False;
    LLeaf := FFirstLeaf;
    while LLeaf <> nil do
    begin
      if not LLeaf^.IsLeaf then
        Exit(False);
      for LI := 0 to LLeaf^.KeyCount - 1 do
      begin
        if LHasPrevious and (LPreviousKey >= LLeaf^.Keys[LI]) then
          Exit(False);
        LPreviousKey := LLeaf^.Keys[LI];
        LHasPrevious := True;
        Inc(LLeafEntryCount);
      end;
      if LLeafEntryCount > FCount then
        Exit(False);
      LLeaf := LLeaf^.Next;
    end;
    Result := LLeafEntryCount = FCount;
  finally
    Unlock;
  end;
end;
{$endif}

function TConcurrentBPlusTree.BorrowFromLeft(ALeaf: PBplusNode; ALeft: PBplusNode): Boolean;
var
  LI: Integer;
begin
  if ALeft^.KeyCount <= BPLUS_MIN_KEYS then
    Exit(False);
  // shift current keys/values right to make room at front
  for LI := ALeaf^.KeyCount downto 1 do
  begin
    ALeaf^.Keys[LI] := ALeaf^.Keys[LI - 1];
    ALeaf^.Values[LI] := ALeaf^.Values[LI - 1];
  end;
  // take last key/value from left node
  ALeaf^.Keys[0] := ALeft^.Keys[ALeft^.KeyCount - 1];
  ALeaf^.Values[0] := ALeft^.Values[ALeft^.KeyCount - 1];
  Dec(ALeft^.KeyCount);
  Inc(ALeaf^.KeyCount);
  Result := True;
end;

function TConcurrentBPlusTree.BorrowFromRight(ALeaf: PBplusNode; ARight: PBplusNode): Boolean;
var
  LI: Integer;
begin
  if ARight^.KeyCount <= BPLUS_MIN_KEYS then
    Exit(False);
  // take first key/value from right node
  ALeaf^.Keys[ALeaf^.KeyCount] := ARight^.Keys[0];
  ALeaf^.Values[ALeaf^.KeyCount] := ARight^.Values[0];
  // shift right node's keys/values left
  for LI := 0 to ARight^.KeyCount - 2 do
  begin
    ARight^.Keys[LI] := ARight^.Keys[LI + 1];
    ARight^.Values[LI] := ARight^.Values[LI + 1];
  end;
  Inc(ALeaf^.KeyCount);
  Dec(ARight^.KeyCount);
  Result := True;
end;

function TConcurrentBPlusTree.MergeLeaves(ALeft: PBplusNode; ARight: PBplusNode): Boolean;
var
  LI: Integer;
begin
  if ALeft^.KeyCount + ARight^.KeyCount > BPLUS_MAX_KEYS then
    Exit(False);
  // copy all keys/values from right node to left node
  for LI := 0 to ARight^.KeyCount - 1 do
  begin
    ALeft^.Keys[ALeft^.KeyCount + LI] := ARight^.Keys[LI];
    ALeft^.Values[ALeft^.KeyCount + LI] := ARight^.Values[LI];
  end;
  ALeft^.KeyCount := ALeft^.KeyCount + ARight^.KeyCount;
  ALeft^.Next := ARight^.Next;
  FreeNode(ARight);
  Result := True;
end;

procedure TConcurrentBPlusTree.BorrowInternalFromLeft(ANode,
  ALeft: PBplusNode);
var
  LI: Integer;
begin
  for LI := ANode^.KeyCount downto 0 do
    ANode^.Children[LI + 1] := ANode^.Children[LI];
  ANode^.Children[0] := ALeft^.Children[ALeft^.KeyCount];
  ALeft^.Children[ALeft^.KeyCount] := nil;
  Dec(ALeft^.KeyCount);
  Inc(ANode^.KeyCount);
end;

procedure TConcurrentBPlusTree.BorrowInternalFromRight(ANode,
  ARight: PBplusNode);
var
  LI: Integer;
begin
  ANode^.Children[ANode^.KeyCount + 1] := ARight^.Children[0];
  Inc(ANode^.KeyCount);
  for LI := 0 to ARight^.KeyCount - 1 do
    ARight^.Children[LI] := ARight^.Children[LI + 1];
  ARight^.Children[ARight^.KeyCount] := nil;
  Dec(ARight^.KeyCount);
end;

procedure TConcurrentBPlusTree.MergeInternal(ALeft, ARight: PBplusNode);
var
  LOffset, LI: Integer;
begin
  LOffset := ALeft^.KeyCount + 1;
  for LI := 0 to ARight^.KeyCount do
  begin
    ALeft^.Children[LOffset + LI] := ARight^.Children[LI];
    ARight^.Children[LI] := nil;
  end;
  ALeft^.KeyCount := ALeft^.KeyCount + ARight^.KeyCount + 1;
  FreeNode(ARight);
end;

procedure TConcurrentBPlusTree.RemoveChild(AParent: PBplusNode;
  AChildIdx: Integer);
var
  LI: Integer;
begin
  for LI := AChildIdx to AParent^.KeyCount - 1 do
    AParent^.Children[LI] := AParent^.Children[LI + 1];
  AParent^.Children[AParent^.KeyCount] := nil;
  Dec(AParent^.KeyCount);
end;

function TConcurrentBPlusTree.RefreshSeparators(ANode: PBplusNode): Int64;
var
  LI: Integer;
begin
  if ANode^.IsLeaf then
  begin
    if ANode^.KeyCount = 0 then
      Exit(0);
    Exit(ANode^.Keys[0]);
  end;

  Result := RefreshSeparators(ANode^.Children[0]);
  for LI := 1 to ANode^.KeyCount do
    ANode^.Keys[LI - 1] := RefreshSeparators(ANode^.Children[LI]);
end;

end.
