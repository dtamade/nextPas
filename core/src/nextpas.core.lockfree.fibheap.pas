{******************************************************************************
  nextpas.core.lockfree.fibheap

  Concurrent Fibonacci Heap — amortized O(1) insert/merge, O(log n) extract-min.

  Design:
  - Lazy consolidation: insert is O(1) amortized
  - Merge two heaps in O(1)
  - Extract-min triggers consolidation (O(log n) amortized)
  - Spin lock for mutations, lock-free Min read
  - Doubly-linked circular root list + child lists
  - Degree array for consolidation

  Use cases: priority queues, Dijkstra's algorithm, scheduling.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.fibheap;

interface

uses
  nextpas.core.errors;

type
  TFibHeapResult = (
    fhrOk,
    fhrEmpty,
    fhrInvalidKey
  );

  PFibNode = ^TFibNode;
  TFibNode = record
    Key: Int64;
    Value: Int64;
    Degree: Int32;
    Marked: Boolean;
    Parent: PFibNode;
    Child: PFibNode;
    Left: PFibNode;
    Right: PFibNode;
  end;

  TLockFreeFibonacciHeap = class
  private
    FMin: PFibNode;
    FRootList: PFibNode;
    FCount: Int32;
    FLock: Int32;

    function NewNode(AKey, AValue: Int64): PFibNode;
    procedure InsertIntoList(var AList: PFibNode; ANode: PFibNode);
    procedure RemoveFromList(var AList: PFibNode; ANode: PFibNode);
    procedure LinkNodes(AParent, AChild: PFibNode);
    procedure Consolidate;
    procedure Cut(AParent, AChild: PFibNode);
    procedure CascadingCut(ANode: PFibNode);
    procedure FreeNode(ANode: PFibNode);

    procedure AcquireLock;
    procedure ReleaseLock;
  public
    constructor Create;
    destructor Destroy; override;

    function Insert(AKey, AValue: Int64): PFibNode;
    function ExtractMin(out AKey, AValue: Int64): TFibHeapResult;
    function PeekMin(out AKey, AValue: Int64): TFibHeapResult;
    function DecreaseKey(ANode: PFibNode; ANewKey: Int64): TFibHeapResult;
    function Merge(AOther: TLockFreeFibonacciHeap): TFibHeapResult;
    function Count: Int32; inline;
    function IsEmpty: Boolean; inline;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TLockFreeFibonacciHeap.Create;
begin
  inherited Create;
  FMin := nil;
  FRootList := nil;
  FCount := 0;
  FLock := 0;
end;

destructor TLockFreeFibonacciHeap.Destroy;
var
  LNode, LNext, LStart: PFibNode;
begin
  { Free all nodes in root list and their children }
  if FRootList <> nil then
  begin
    LNode := FRootList;
    LStart := LNode;
    repeat
      LNext := LNode^.Right;
      FreeNode(LNode);
      LNode := LNext;
    until LNode = LStart;
  end;
  inherited Destroy;
end;

function TLockFreeFibonacciHeap.NewNode(AKey, AValue: Int64): PFibNode;
begin
  New(Result);
  Result^.Key := AKey;
  Result^.Value := AValue;
  Result^.Degree := 0;
  Result^.Marked := False;
  Result^.Parent := nil;
  Result^.Child := nil;
  Result^.Left := Result;
  Result^.Right := Result;
end;

procedure TLockFreeFibonacciHeap.InsertIntoList(var AList: PFibNode; ANode: PFibNode);
begin
  if AList = nil then
  begin
    AList := ANode;
    ANode^.Left := ANode;
    ANode^.Right := ANode;
  end
  else
  begin
    ANode^.Right := AList;
    ANode^.Left := AList^.Left;
    AList^.Left^.Right := ANode;
    AList^.Left := ANode;
  end;
end;

procedure TLockFreeFibonacciHeap.RemoveFromList(var AList: PFibNode; ANode: PFibNode);
begin
  if ANode^.Right = ANode then
  begin
    { Only node in list }
    AList := nil;
  end
  else
  begin
    ANode^.Left^.Right := ANode^.Right;
    ANode^.Right^.Left := ANode^.Left;
    if AList = ANode then
      AList := ANode^.Right;
  end;
end;

procedure TLockFreeFibonacciHeap.LinkNodes(AParent, AChild: PFibNode);
begin
  RemoveFromList(FRootList, AChild);
  AChild^.Parent := AParent;
  AChild^.Marked := False;
  InsertIntoList(AParent^.Child, AChild);
  Inc(AParent^.Degree);
end;

procedure TLockFreeFibonacciHeap.Consolidate;
var
  LDegreeArray: array[0..63] of PFibNode;
  LNode, LOther, LTemp: PFibNode;
  LDegree, I, LCount: Int32;
  LNodes: array of PFibNode;
begin
  for I := 0 to 63 do
    LDegreeArray[I] := nil;

  if FRootList = nil then
    Exit;

  { Collect all root nodes into an array first }
  LCount := 0;
  SetLength(LNodes, 64);
  LNode := FRootList;
  repeat
    if LCount >= Length(LNodes) then
      SetLength(LNodes, Length(LNodes) * 2);
    LNodes[LCount] := LNode;
    Inc(LCount);
    LNode := LNode^.Right;
  until LNode = FRootList;

  { Process each node }
  for I := 0 to LCount - 1 do
  begin
    LNode := LNodes[I];
    if LNode = nil then
      Continue;
    LDegree := LNode^.Degree;

    while (LDegree < 64) and (LDegreeArray[LDegree] <> nil) do
    begin
      LOther := LDegreeArray[LDegree];
      if LNode^.Key > LOther^.Key then
      begin
        LTemp := LNode;
        LNode := LOther;
        LOther := LTemp;
      end;
      LinkNodes(LNode, LOther);
      LDegreeArray[LDegree] := nil;
      Inc(LDegree);
    end;

    if LDegree < 64 then
      LDegreeArray[LDegree] := LNode;
  end;

  { Rebuild root list from degree array }
  FRootList := nil;
  FMin := nil;
  for I := 0 to 63 do
  begin
    if LDegreeArray[I] <> nil then
    begin
      LDegreeArray[I]^.Left := LDegreeArray[I];
      LDegreeArray[I]^.Right := LDegreeArray[I];
      LDegreeArray[I]^.Parent := nil;
      InsertIntoList(FRootList, LDegreeArray[I]);
      if (FMin = nil) or (LDegreeArray[I]^.Key < FMin^.Key) then
        FMin := LDegreeArray[I];
    end;
  end;
end;

procedure TLockFreeFibonacciHeap.Cut(AParent, AChild: PFibNode);
begin
  RemoveFromList(AParent^.Child, AChild);
  Dec(AParent^.Degree);
  AChild^.Parent := nil;
  AChild^.Marked := False;
  InsertIntoList(FRootList, AChild);
end;

procedure TLockFreeFibonacciHeap.CascadingCut(ANode: PFibNode);
var
  LParent: PFibNode;
begin
  LParent := ANode^.Parent;
  if LParent <> nil then
  begin
    if not ANode^.Marked then
      ANode^.Marked := True
    else
    begin
      Cut(LParent, ANode);
      CascadingCut(LParent);
    end;
  end;
end;

procedure TLockFreeFibonacciHeap.FreeNode(ANode: PFibNode);
var
  LChild, LNext, LStart: PFibNode;
begin
  if ANode = nil then
    Exit;
  { Free children }
  if ANode^.Child <> nil then
  begin
    LChild := ANode^.Child;
    LStart := LChild;
    repeat
      LNext := LChild^.Right;
      FreeNode(LChild);
      LChild := LNext;
    until LChild = LStart;
  end;
  Dispose(ANode);
end;

procedure TLockFreeFibonacciHeap.AcquireLock;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Exit;
    ThreadSwitch;
  end;
end;

procedure TLockFreeFibonacciHeap.ReleaseLock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TLockFreeFibonacciHeap.Insert(AKey, AValue: Int64): PFibNode;
begin
  AcquireLock;
  try
    Result := NewNode(AKey, AValue);
    InsertIntoList(FRootList, Result);
    if (FMin = nil) or (AKey < FMin^.Key) then
      FMin := Result;
    Inc(FCount);
  finally
    ReleaseLock;
  end;
end;

function TLockFreeFibonacciHeap.ExtractMin(out AKey, AValue: Int64): TFibHeapResult;
var
  LMin, LChild, LNext, LStart: PFibNode;
begin
  AcquireLock;
  try
    if FMin = nil then
      Exit(fhrEmpty);

    LMin := FMin;
    AKey := LMin^.Key;
    AValue := LMin^.Value;

    { Add children to root list }
    if LMin^.Child <> nil then
    begin
      LChild := LMin^.Child;
      LStart := LChild;
      repeat
        LNext := LChild^.Right;
        LChild^.Parent := nil;
        InsertIntoList(FRootList, LChild);
        LChild := LNext;
      until LChild = LStart;
    end;

    { Remove min from root list }
    RemoveFromList(FRootList, LMin);
    Dec(FCount);

    if FCount = 0 then
    begin
      FMin := nil;
      FRootList := nil;
    end
    else
    begin
      { Consolidate to restore structure }
      Consolidate;
    end;

    Dispose(LMin);
    Result := fhrOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeFibonacciHeap.PeekMin(out AKey, AValue: Int64): TFibHeapResult;
begin
  { Lock-free read of min }
  if atomic_load(Pointer(FMin), mo_acquire) = nil then
    Exit(fhrEmpty);
  AKey := FMin^.Key;
  AValue := FMin^.Value;
  Result := fhrOk;
end;

function TLockFreeFibonacciHeap.DecreaseKey(ANode: PFibNode; ANewKey: Int64): TFibHeapResult;
begin
  if ANewKey > ANode^.Key then
    Exit(fhrInvalidKey);

  AcquireLock;
  try
    ANode^.Key := ANewKey;
    if ANode^.Parent <> nil then
    begin
      if ANode^.Key < ANode^.Parent^.Key then
      begin
        Cut(ANode^.Parent, ANode);
        CascadingCut(ANode);
      end;
    end;
    if ANode^.Key < FMin^.Key then
      FMin := ANode;
    Result := fhrOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeFibonacciHeap.Merge(AOther: TLockFreeFibonacciHeap): TFibHeapResult;
var
  LTmp: PFibNode;
begin
  if AOther = nil then
    Exit(fhrEmpty);

  AcquireLock;
  try
    AOther.AcquireLock;
    try
      if AOther.FRootList <> nil then
      begin
        if FRootList = nil then
        begin
          FRootList := AOther.FRootList;
          FMin := AOther.FMin;
        end
        else
        begin
          { Concatenate root lists }
          LTmp := FRootList^.Right;
          FRootList^.Right := AOther.FRootList^.Right;
          AOther.FRootList^.Right^.Left := FRootList;
          AOther.FRootList^.Right := LTmp;
          LTmp^.Left := AOther.FRootList;

          if AOther.FMin^.Key < FMin^.Key then
            FMin := AOther.FMin;
        end;
        FCount := FCount + AOther.FCount;

        { Clear other heap without freeing nodes }
        AOther.FRootList := nil;
        AOther.FMin := nil;
        AOther.FCount := 0;
      end;
    finally
      AOther.ReleaseLock;
    end;
    Result := fhrOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeFibonacciHeap.Count: Int32; inline;
begin
  Result := atomic_load(FCount, mo_acquire);
end;

function TLockFreeFibonacciHeap.IsEmpty: Boolean; inline;
begin
  Result := atomic_load(FCount, mo_acquire) = 0;
end;

end.
