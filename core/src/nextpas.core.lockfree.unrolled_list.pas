{******************************************************************************
  nextpas.core.lockfree.unrolled_list

  Concurrent Unrolled Linked List — cache-friendly sorted linked list.

  Design:
  - Each node holds a fixed-size array of elements + count
  - Elements within a node are kept sorted
  - Nodes are linked in a singly-linked list
  - On insert: find node, insert in sorted order, split if full
  - On delete: find and remove, merge with neighbor if underfull
  - Concurrent-safe: CAS spin lock
  - Better cache locality than plain linked list (fewer pointers)

  Benefits:
  - Fewer pointer chases → better cache performance
  - Less memory overhead per element (amortized)
  - Sorted traversal is cache-friendly

  2026-07-06  Phase 10
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.unrolled_list;

interface

uses
  nextpas.core.lockfree.base;

const
  UNROLLED_NODE_CAPACITY = 16;

type
  TUnrolledResult = (ulOk, ulNotFound, ulExists, ulFull, ulClosed);

  generic TConcurrentUnrolledListImpl<T> = class
  private
    type
      PNode = ^TNode;
      TNode = record
        Values: array[0..UNROLLED_NODE_CAPACITY - 1] of T;
        Count: Int32;
        Next: PNode;
      end;
  private
    FHead: PNode;
    FCount: Int32;
    FNodeCount: Int32;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function CreateNode: PNode;
    procedure SplitNode(AParent: PNode);
    procedure MergeIfNeeded(AParent: PNode);
    function CompareValues(const A, B: T): Int32;
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(const AValue: T): TUnrolledResult;
    function Delete(const AValue: T): TUnrolledResult;
    function Contains(const AValue: T): Boolean;
    function GetCount: Int32;
    function GetNodeCount: Int32;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

  generic TConcurrentUnrolledList<T> = class(specialize TConcurrentUnrolledListImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentUnrolledListImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TConcurrentUnrolledList: T must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FHead := nil;
  FCount := 0;
  FNodeCount := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TConcurrentUnrolledListImpl.Destroy;
var
  LNode, LNext: PNode;
begin
  LNode := FHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    Dispose(LNode);
    LNode := LNext;
  end;
  inherited Destroy;
end;

procedure TConcurrentUnrolledListImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TConcurrentUnrolledListImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TConcurrentUnrolledListImpl.CreateNode: PNode;
begin
  New(Result);
  Result^.Count := 0;
  Result^.Next := nil;
end;

function TConcurrentUnrolledListImpl.CompareValues(const A, B: T): Int32;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

procedure TConcurrentUnrolledListImpl.SplitNode(AParent: PNode);
var
  LNewNode: PNode;
  LHalf, LI: Int32;
begin
  if AParent^.Count < 2 then
    Exit;
  LHalf := AParent^.Count div 2;
  LNewNode := CreateNode;
  { Move upper half to new node }
  for LI := LHalf to AParent^.Count - 1 do
  begin
    LNewNode^.Values[LNewNode^.Count] := AParent^.Values[LI];
    Inc(LNewNode^.Count);
  end;
  AParent^.Count := LHalf;
  { Link new node after parent }
  LNewNode^.Next := AParent^.Next;
  AParent^.Next := LNewNode;
  Inc(FNodeCount);
end;

procedure TConcurrentUnrolledListImpl.MergeIfNeeded(AParent: PNode);
var
  LNext: PNode;
  LI: Int32;
begin
  LNext := AParent^.Next;
  if LNext = nil then
    Exit;
  { Merge if combined size fits in one node }
  if AParent^.Count + LNext^.Count <= UNROLLED_NODE_CAPACITY then
  begin
    for LI := 0 to LNext^.Count - 1 do
    begin
      AParent^.Values[AParent^.Count] := LNext^.Values[LI];
      Inc(AParent^.Count);
    end;
    AParent^.Next := LNext^.Next;
    Dispose(LNext);
    Dec(FNodeCount);
  end;
end;

function TConcurrentUnrolledListImpl.Insert(const AValue: T): TUnrolledResult;
var
  LNode, LPrev, LNewNode: PNode;
  LI, LJ, LPos: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(ulClosed);
  Lock;
  try
    { Empty list: create first node }
    if FHead = nil then
    begin
      FHead := CreateNode;
      FHead^.Values[0] := AValue;
      FHead^.Count := 1;
      FCount := 1;
      FNodeCount := 1;
      Exit(ulOk);
    end;
    { Find the right node for insertion }
    LPrev := nil;
    LNode := FHead;
    while LNode^.Next <> nil do
    begin
      { Check if value belongs before the next node's first element }
      if CompareValues(AValue, LNode^.Next^.Values[0]) < 0 then
        Break;
      { Check if value belongs in the last position of current node }
      if (LNode^.Count < UNROLLED_NODE_CAPACITY) and
         (CompareValues(AValue, LNode^.Values[LNode^.Count - 1]) <= 0) then
        Break;
      LPrev := LNode;
      LNode := LNode^.Next;
    end;
    { Find insertion position within node (sorted order) }
    LPos := LNode^.Count;
    for LI := 0 to LNode^.Count - 1 do
    begin
      case CompareValues(AValue, LNode^.Values[LI]) of
        0: Exit(ulExists);
        -1: begin
          LPos := LI;
          Break;
        end;
      end;
    end;
    { Insert at LPos }
    if LNode^.Count >= UNROLLED_NODE_CAPACITY then
    begin
      { Node full: split first }
      SplitNode(LNode);
      { Re-determine which node to insert into }
      if LPos >= LNode^.Count then
      begin
        { Insert in the new (right) node }
        LNode := LNode^.Next;
        LPos := LPos - (LNode^.Count);
        if LPos < 0 then LPos := 0;
      end;
    end;
    { Shift elements right }
    for LJ := LNode^.Count - 1 downto LPos do
      LNode^.Values[LJ + 1] := LNode^.Values[LJ];
    LNode^.Values[LPos] := AValue;
    Inc(LNode^.Count);
    Inc(FCount);
    Result := ulOk;
  finally
    Unlock;
  end;
end;

function TConcurrentUnrolledListImpl.Delete(const AValue: T): TUnrolledResult;
var
  LNode, LPrev: PNode;
  LI, LJ: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(ulClosed);
  Lock;
  try
    LPrev := nil;
    LNode := FHead;
    while LNode <> nil do
    begin
      for LI := 0 to LNode^.Count - 1 do
      begin
        if CompareValues(LNode^.Values[LI], AValue) = 0 then
        begin
          { Shift elements left }
          for LJ := LI to LNode^.Count - 2 do
            LNode^.Values[LJ] := LNode^.Values[LJ + 1];
          LNode^.Values[LNode^.Count - 1] := Default(T);
          Dec(LNode^.Count);
          Dec(FCount);
          { Merge if node is too empty }
          if LPrev <> nil then
            MergeIfNeeded(LPrev)
          else if LNode^.Count = 0 then
          begin
            FHead := LNode^.Next;
            Dispose(LNode);
            Dec(FNodeCount);
          end;
          Exit(ulOk);
        end;
        { Early exit if current element > target (sorted) }
        if CompareValues(LNode^.Values[LI], AValue) > 0 then
          Exit(ulNotFound);
      end;
      LPrev := LNode;
      LNode := LNode^.Next;
    end;
    Result := ulNotFound;
  finally
    Unlock;
  end;
end;

function TConcurrentUnrolledListImpl.Contains(const AValue: T): Boolean;
var
  LNode: PNode;
  LI: Int32;
begin
  Lock;
  try
    LNode := FHead;
    while LNode <> nil do
    begin
      for LI := 0 to LNode^.Count - 1 do
      begin
        if CompareValues(LNode^.Values[LI], AValue) = 0 then
          Exit(True);
        if CompareValues(LNode^.Values[LI], AValue) > 0 then
          Exit(False);
      end;
      LNode := LNode^.Next;
    end;
    Result := False;
  finally
    Unlock;
  end;
end;

function TConcurrentUnrolledListImpl.GetCount: Int32;
begin
  Lock;
  try
    Result := FCount;
  finally
    Unlock;
  end;
end;

function TConcurrentUnrolledListImpl.GetNodeCount: Int32;
begin
  Lock;
  try
    Result := FNodeCount;
  finally
    Unlock;
  end;
end;

procedure TConcurrentUnrolledListImpl.Clear;
var
  LNode, LNext: PNode;
begin
  Lock;
  try
    LNode := FHead;
    while LNode <> nil do
    begin
      LNext := LNode^.Next;
      Dispose(LNode);
      LNode := LNext;
    end;
    FHead := nil;
    FCount := 0;
    FNodeCount := 0;
  finally
    Unlock;
  end;
end;

procedure TConcurrentUnrolledListImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TConcurrentUnrolledListImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
