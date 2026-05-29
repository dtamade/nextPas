unit nextpas.core.collections.btree;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base;

const
  BTREE_ORDER = 16;
  BTREE_MAX_KEYS = BTREE_ORDER * 2 - 1;
  BTREE_MIN_KEYS = BTREE_ORDER - 1;

type
  generic TBTreeMap<K, V> = class
  public type
    TCompareFunc = function(const A, B: K; aData: Pointer): SizeInt;
    TForEachCallback = procedure(const AKey: K; const AValue: V; aData: Pointer);
    TEntry = record
      Key: K;
      Value: V;
    end;
    PNode = ^TNode;
    TNode = record
      Count: Int32;
      IsLeaf: Boolean;
      Keys: array[0..BTREE_MAX_KEYS - 1] of K;
      Values: array[0..BTREE_MAX_KEYS - 1] of V;
      Children: array[0..BTREE_MAX_KEYS] of PNode;
    end;

  public type
    TEnumerator = record
    private
      FStack: array[0..31] of PNode;
      FIndices: array[0..31] of Int32;
      FDepth: Int32;
      FCurrent: TEntry;
      FStarted: Boolean;
      function DoMoveNext: Boolean;
    public
      function MoveNext: Boolean;
      property Current: TEntry read FCurrent;
    end;
  private
    FRoot: PNode;
    FCount: SizeUInt;
    FCompare: TCompareFunc;
    FCompareData: Pointer;

    function NewNode(AIsLeaf: Boolean): PNode;
    procedure FreeNode(ANode: PNode);
    procedure FreeNodeRecursive(ANode: PNode);
    function SearchNode(ANode: PNode; const AKey: K; out AIndex: Int32): Boolean;
    procedure SplitChild(AParent: PNode; AChildIndex: Int32);
    procedure InsertNonFull(ANode: PNode; const AKey: K; const AValue: V);
    function FindPredecessor(ANode: PNode): PNode;
    function FindSuccessor(ANode: PNode): PNode;
    procedure RemoveFromNode(ANode: PNode; const AKey: K);
    procedure RemoveFromLeaf(ANode: PNode; AIndex: Int32);
    procedure RemoveFromInternal(ANode: PNode; AIndex: Int32);
    procedure Fill(ANode: PNode; AIndex: Int32);
    procedure BorrowFromPrev(ANode: PNode; AIndex: Int32);
    procedure BorrowFromNext(ANode: PNode; AIndex: Int32);
    procedure MergeChildren(ANode: PNode; AIndex: Int32);
    procedure InorderTraverse(ANode: PNode; ACallback: TForEachCallback; AData: Pointer);
    procedure RangeTraverse(ANode: PNode; const ALo, AHi: K;
      ACallback: TForEachCallback; AData: Pointer);
    function SubtreeSize(ANode: PNode): SizeUInt;

  public
    constructor Create(ACompare: TCompareFunc; ACompareData: Pointer = nil);
    destructor Destroy; override;

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function Get(const AKey: K): V;
    function Remove(const AKey: K): Boolean;
    procedure Clear;

    function Min(out AKey: K; out AValue: V): Boolean;
    function Max(out AKey: K; out AValue: V): Boolean;

    function LowerBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function UpperBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Floor(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Rank(const AKey: K): SizeUInt;
    function Select(ARank: SizeUInt; out AKey: K; out AValue: V): Boolean;
    procedure ForEach(ACallback: TForEachCallback; AData: Pointer = nil);
    procedure Range(const ALo, AHi: K; ACallback: TForEachCallback; AData: Pointer = nil);
    function GetEnumerator: TEnumerator;

    property Count: SizeUInt read FCount;
  end;

  generic TBTreeSet<T> = class
  public type
    TCompareFunc = function(const A, B: T; aData: Pointer): SizeInt;
    TForEachCallback = procedure(const AItem: T; aData: Pointer);
  private type
    TInner = specialize TBTreeMap<T, Byte>;
  private
    FInner: TInner;
  public
    constructor Create(ACompare: TCompareFunc; ACompareData: Pointer = nil);
    destructor Destroy; override;

    procedure Add(const AItem: T);
    function Contains(const AItem: T): Boolean;
    function Remove(const AItem: T): Boolean;
    procedure Clear;

    function Min(out AItem: T): Boolean;
    function Max(out AItem: T): Boolean;
    function LowerBound(const AItem: T; out AFound: T): Boolean;
    function UpperBound(const AItem: T; out AFound: T): Boolean;
    function Floor(const AItem: T; out AFound: T): Boolean;

    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

{ Node management }

function TBTreeMap.NewNode(AIsLeaf: Boolean): PNode;
begin
  New(Result);
  Result^.Count := 0;
  Result^.IsLeaf := AIsLeaf;
  FillChar(Result^.Children, SizeOf(Result^.Children), 0);
end;

procedure TBTreeMap.FreeNode(ANode: PNode);
var i: Int32;
begin
  if ANode = nil then Exit;
  if System.IsManagedType(K) then
    for i := 0 to ANode^.Count - 1 do Finalize(ANode^.Keys[i]);
  if System.IsManagedType(V) then
    for i := 0 to ANode^.Count - 1 do Finalize(ANode^.Values[i]);
  Dispose(ANode);
end;

procedure TBTreeMap.FreeNodeRecursive(ANode: PNode);
var i: Int32;
begin
  if ANode = nil then Exit;
  if not ANode^.IsLeaf then
    for i := 0 to ANode^.Count do
      FreeNodeRecursive(ANode^.Children[i]);
  FreeNode(ANode);
end;

{ Search }

function TBTreeMap.SearchNode(ANode: PNode; const AKey: K; out AIndex: Int32): Boolean;
var lo, hi, mid, cmp: Int32;
begin
  lo := 0; hi := ANode^.Count - 1;
  if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
  begin
    while lo <= hi do
    begin
      mid := (lo + hi) shr 1;
      if PInt32(@AKey)^ = PInt32(@ANode^.Keys[mid])^ then
        begin AIndex := mid; Exit(True); end;
      if PInt32(@AKey)^ < PInt32(@ANode^.Keys[mid])^ then
        hi := mid - 1
      else
        lo := mid + 1;
    end;
  end
  else
  begin
    while lo <= hi do
    begin
      mid := (lo + hi) shr 1;
      cmp := FCompare(AKey, ANode^.Keys[mid], FCompareData);
      if cmp = 0 then begin AIndex := mid; Exit(True); end;
      if cmp < 0 then hi := mid - 1 else lo := mid + 1;
    end;
  end;
  AIndex := lo;
  Result := False;
end;

{ Public API }

constructor TBTreeMap.Create(ACompare: TCompareFunc; ACompareData: Pointer);
begin
  inherited Create;
  FCompare := ACompare;
  FCompareData := ACompareData;
  FRoot := nil;
  FCount := 0;
end;

destructor TBTreeMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TBTreeMap.TryGetValue(const AKey: K; out AValue: V): Boolean;
var
  LNode: PNode;
  LIdx: Int32;
begin
  LNode := FRoot;
  while LNode <> nil do
  begin
    if SearchNode(LNode, AKey, LIdx) then
    begin
      AValue := LNode^.Values[LIdx];
      Exit(True);
    end;
    if LNode^.IsLeaf then Exit(False);
    LNode := LNode^.Children[LIdx];
  end;
  Result := False;
end;

function TBTreeMap.ContainsKey(const AKey: K): Boolean;
var LDummy: V;
begin
  Result := TryGetValue(AKey, LDummy);
end;

function TBTreeMap.Get(const AKey: K): V;
begin
  if not TryGetValue(AKey, Result) then
    raise EInvalidOperation.Create('TBTreeMap.Get: key not found');
end;

{ Split }

procedure TBTreeMap.SplitChild(AParent: PNode; AChildIndex: Int32);
var
  LFull, LNew: PNode;
  LMidIdx, i: Int32;
begin
  LFull := AParent^.Children[AChildIndex];
  LMidIdx := BTREE_ORDER - 1;
  LNew := NewNode(LFull^.IsLeaf);
  LNew^.Count := LFull^.Count - LMidIdx - 1;

  for i := 0 to LNew^.Count - 1 do
  begin
    LNew^.Keys[i] := LFull^.Keys[LMidIdx + 1 + i];
    LNew^.Values[i] := LFull^.Values[LMidIdx + 1 + i];
  end;
  if not LFull^.IsLeaf then
    for i := 0 to LNew^.Count do
      LNew^.Children[i] := LFull^.Children[LMidIdx + 1 + i];

  // shift parent keys/children right
  for i := AParent^.Count - 1 downto AChildIndex do
  begin
    AParent^.Keys[i + 1] := AParent^.Keys[i];
    AParent^.Values[i + 1] := AParent^.Values[i];
  end;
  for i := AParent^.Count downto AChildIndex + 1 do
    AParent^.Children[i + 1] := AParent^.Children[i];

  AParent^.Keys[AChildIndex] := LFull^.Keys[LMidIdx];
  AParent^.Values[AChildIndex] := LFull^.Values[LMidIdx];
  AParent^.Children[AChildIndex + 1] := LNew;
  Inc(AParent^.Count);

  LFull^.Count := LMidIdx;
end;

{ Insert }

procedure TBTreeMap.InsertNonFull(ANode: PNode; const AKey: K; const AValue: V);
var
  i, cmp: Int32;
begin
  i := ANode^.Count - 1;

  if ANode^.IsLeaf then
  begin
    if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    begin
      while (i >= 0) and (PInt32(@AKey)^ < PInt32(@ANode^.Keys[i])^) do
      begin
        ANode^.Keys[i + 1] := ANode^.Keys[i];
        ANode^.Values[i + 1] := ANode^.Values[i];
        Dec(i);
      end;
    end
    else
    begin
      while (i >= 0) and (FCompare(AKey, ANode^.Keys[i], FCompareData) < 0) do
      begin
        ANode^.Keys[i + 1] := ANode^.Keys[i];
        ANode^.Values[i + 1] := ANode^.Values[i];
        Dec(i);
      end;
    end;
    ANode^.Keys[i + 1] := AKey;
    ANode^.Values[i + 1] := AValue;
    Inc(ANode^.Count);
    Inc(FCount);
  end
  else
  begin
    if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    begin
      while (i >= 0) and (PInt32(@AKey)^ < PInt32(@ANode^.Keys[i])^) do
        Dec(i);
    end
    else
    begin
      while (i >= 0) and (FCompare(AKey, ANode^.Keys[i], FCompareData) < 0) do
        Dec(i);
    end;
    Inc(i);
    if ANode^.Children[i]^.Count = BTREE_MAX_KEYS then
    begin
      SplitChild(ANode, i);
      if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
      begin
        if PInt32(@AKey)^ = PInt32(@ANode^.Keys[i])^ then
        begin
          if System.IsManagedType(V) then Finalize(ANode^.Values[i]);
          ANode^.Values[i] := AValue;
          Exit;
        end;
        if PInt32(@AKey)^ > PInt32(@ANode^.Keys[i])^ then Inc(i);
      end
      else
      begin
        cmp := FCompare(AKey, ANode^.Keys[i], FCompareData);
        if cmp = 0 then
        begin
          if System.IsManagedType(V) then Finalize(ANode^.Values[i]);
          ANode^.Values[i] := AValue;
          Exit;
        end;
        if cmp > 0 then Inc(i);
      end;
    end;
    InsertNonFull(ANode^.Children[i], AKey, AValue);
  end;
end;

procedure TBTreeMap.Put(const AKey: K; const AValue: V);
var
  LNode: PNode;
  LIdx: Int32;
  LNewRoot: PNode;
begin
  if FRoot = nil then
  begin
    FRoot := NewNode(True);
    FRoot^.Keys[0] := AKey;
    FRoot^.Values[0] := AValue;
    FRoot^.Count := 1;
    FCount := 1;
    Exit;
  end;

  // Check if key already exists (update)
  LNode := FRoot;
  while LNode <> nil do
  begin
    if SearchNode(LNode, AKey, LIdx) then
    begin
      if System.IsManagedType(V) then Finalize(LNode^.Values[LIdx]);
      LNode^.Values[LIdx] := AValue;
      Exit;
    end;
    if LNode^.IsLeaf then Break;
    LNode := LNode^.Children[LIdx];
  end;

  // Insert new key
  if FRoot^.Count = BTREE_MAX_KEYS then
  begin
    LNewRoot := NewNode(False);
    LNewRoot^.Children[0] := FRoot;
    FRoot := LNewRoot;
    SplitChild(FRoot, 0);
  end;
  InsertNonFull(FRoot, AKey, AValue);
end;

{ Remove — simplified: mark as not implemented for now }

function TBTreeMap.Remove(const AKey: K): Boolean;
var LOld: PNode;
begin
  if FRoot = nil then Exit(False);
  RemoveFromNode(FRoot, AKey);
  if FRoot^.Count = 0 then
  begin
    if FRoot^.IsLeaf then
    begin
      FreeNode(FRoot);
      FRoot := nil;
    end
    else
    begin
      LOld := FRoot;
      FRoot := FRoot^.Children[0];
      LOld^.Count := 0;
      FreeNode(LOld);
    end;
  end;
  Result := True;
end;

procedure TBTreeMap.RemoveFromNode(ANode: PNode; const AKey: K);
var LIdx: Int32; LLastChild: Boolean;
begin
  if SearchNode(ANode, AKey, LIdx) then
  begin
    if ANode^.IsLeaf then
      RemoveFromLeaf(ANode, LIdx)
    else
      RemoveFromInternal(ANode, LIdx);
  end
  else
  begin
    if ANode^.IsLeaf then Exit;
    LLastChild := (LIdx = ANode^.Count);
    if ANode^.Children[LIdx]^.Count < BTREE_ORDER then
      Fill(ANode, LIdx);
    if LLastChild and (LIdx > ANode^.Count) then
      RemoveFromNode(ANode^.Children[LIdx - 1], AKey)
    else
      RemoveFromNode(ANode^.Children[LIdx], AKey);
  end;
end;

procedure TBTreeMap.RemoveFromLeaf(ANode: PNode; AIndex: Int32);
var i: Int32;
begin
  if System.IsManagedType(K) then Finalize(ANode^.Keys[AIndex]);
  if System.IsManagedType(V) then Finalize(ANode^.Values[AIndex]);
  for i := AIndex to ANode^.Count - 2 do
  begin
    ANode^.Keys[i] := ANode^.Keys[i + 1];
    ANode^.Values[i] := ANode^.Values[i + 1];
  end;
  Dec(ANode^.Count);
  Dec(FCount);
end;

procedure TBTreeMap.RemoveFromInternal(ANode: PNode; AIndex: Int32);
var
  LPred, LSucc: PNode;
begin
  if ANode^.Children[AIndex]^.Count >= BTREE_ORDER then
  begin
    LPred := FindPredecessor(ANode^.Children[AIndex]);
    ANode^.Keys[AIndex] := LPred^.Keys[LPred^.Count - 1];
    ANode^.Values[AIndex] := LPred^.Values[LPred^.Count - 1];
    RemoveFromNode(ANode^.Children[AIndex], LPred^.Keys[LPred^.Count - 1]);
  end
  else if ANode^.Children[AIndex + 1]^.Count >= BTREE_ORDER then
  begin
    LSucc := FindSuccessor(ANode^.Children[AIndex + 1]);
    ANode^.Keys[AIndex] := LSucc^.Keys[0];
    ANode^.Values[AIndex] := LSucc^.Values[0];
    RemoveFromNode(ANode^.Children[AIndex + 1], LSucc^.Keys[0]);
  end
  else
  begin
    MergeChildren(ANode, AIndex);
    RemoveFromNode(ANode^.Children[AIndex], ANode^.Keys[AIndex]);
  end;
end;

procedure TBTreeMap.Fill(ANode: PNode; AIndex: Int32);
begin
  if (AIndex > 0) and (ANode^.Children[AIndex - 1]^.Count >= BTREE_ORDER) then
    BorrowFromPrev(ANode, AIndex)
  else if (AIndex < ANode^.Count) and (ANode^.Children[AIndex + 1]^.Count >= BTREE_ORDER) then
    BorrowFromNext(ANode, AIndex)
  else
  begin
    if AIndex < ANode^.Count then
      MergeChildren(ANode, AIndex)
    else
      MergeChildren(ANode, AIndex - 1);
  end;
end;

procedure TBTreeMap.BorrowFromPrev(ANode: PNode; AIndex: Int32);
var
  LChild, LSibling: PNode;
  i: Int32;
begin
  LChild := ANode^.Children[AIndex];
  LSibling := ANode^.Children[AIndex - 1];

  for i := LChild^.Count - 1 downto 0 do
  begin
    LChild^.Keys[i + 1] := LChild^.Keys[i];
    LChild^.Values[i + 1] := LChild^.Values[i];
  end;
  if not LChild^.IsLeaf then
    for i := LChild^.Count downto 0 do
      LChild^.Children[i + 1] := LChild^.Children[i];

  LChild^.Keys[0] := ANode^.Keys[AIndex - 1];
  LChild^.Values[0] := ANode^.Values[AIndex - 1];
  if not LChild^.IsLeaf then
    LChild^.Children[0] := LSibling^.Children[LSibling^.Count];

  ANode^.Keys[AIndex - 1] := LSibling^.Keys[LSibling^.Count - 1];
  ANode^.Values[AIndex - 1] := LSibling^.Values[LSibling^.Count - 1];

  Inc(LChild^.Count);
  Dec(LSibling^.Count);
end;

procedure TBTreeMap.BorrowFromNext(ANode: PNode; AIndex: Int32);
var
  LChild, LSibling: PNode;
  i: Int32;
begin
  LChild := ANode^.Children[AIndex];
  LSibling := ANode^.Children[AIndex + 1];

  LChild^.Keys[LChild^.Count] := ANode^.Keys[AIndex];
  LChild^.Values[LChild^.Count] := ANode^.Values[AIndex];
  if not LChild^.IsLeaf then
    LChild^.Children[LChild^.Count + 1] := LSibling^.Children[0];

  ANode^.Keys[AIndex] := LSibling^.Keys[0];
  ANode^.Values[AIndex] := LSibling^.Values[0];

  for i := 0 to LSibling^.Count - 2 do
  begin
    LSibling^.Keys[i] := LSibling^.Keys[i + 1];
    LSibling^.Values[i] := LSibling^.Values[i + 1];
  end;
  if not LSibling^.IsLeaf then
    for i := 0 to LSibling^.Count - 1 do
      LSibling^.Children[i] := LSibling^.Children[i + 1];

  Inc(LChild^.Count);
  Dec(LSibling^.Count);
end;

procedure TBTreeMap.MergeChildren(ANode: PNode; AIndex: Int32);
var
  LLeft, LRight: PNode;
  i: Int32;
begin
  LLeft := ANode^.Children[AIndex];
  LRight := ANode^.Children[AIndex + 1];

  LLeft^.Keys[LLeft^.Count] := ANode^.Keys[AIndex];
  LLeft^.Values[LLeft^.Count] := ANode^.Values[AIndex];

  for i := 0 to LRight^.Count - 1 do
  begin
    LLeft^.Keys[LLeft^.Count + 1 + i] := LRight^.Keys[i];
    LLeft^.Values[LLeft^.Count + 1 + i] := LRight^.Values[i];
  end;
  if not LLeft^.IsLeaf then
    for i := 0 to LRight^.Count do
      LLeft^.Children[LLeft^.Count + 1 + i] := LRight^.Children[i];

  LLeft^.Count := LLeft^.Count + 1 + LRight^.Count;

  for i := AIndex to ANode^.Count - 2 do
  begin
    ANode^.Keys[i] := ANode^.Keys[i + 1];
    ANode^.Values[i] := ANode^.Values[i + 1];
  end;
  for i := AIndex + 1 to ANode^.Count - 1 do
    ANode^.Children[i] := ANode^.Children[i + 1];
  Dec(ANode^.Count);

  LRight^.Count := 0;
  FreeNode(LRight);
end;

function TBTreeMap.FindPredecessor(ANode: PNode): PNode;
begin
  while not ANode^.IsLeaf do
    ANode := ANode^.Children[ANode^.Count];
  Result := ANode;
end;

function TBTreeMap.FindSuccessor(ANode: PNode): PNode;
begin
  while not ANode^.IsLeaf do
    ANode := ANode^.Children[0];
  Result := ANode;
end;

{ Min/Max }

function TBTreeMap.Min(out AKey: K; out AValue: V): Boolean;
var LNode: PNode;
begin
  if FRoot = nil then Exit(False);
  LNode := FRoot;
  while not LNode^.IsLeaf do
    LNode := LNode^.Children[0];
  AKey := LNode^.Keys[0];
  AValue := LNode^.Values[0];
  Result := True;
end;

function TBTreeMap.Max(out AKey: K; out AValue: V): Boolean;
var LNode: PNode;
begin
  if FRoot = nil then Exit(False);
  LNode := FRoot;
  while not LNode^.IsLeaf do
    LNode := LNode^.Children[LNode^.Count];
  AKey := LNode^.Keys[LNode^.Count - 1];
  AValue := LNode^.Values[LNode^.Count - 1];
  Result := True;
end;

{ Clear }

procedure TBTreeMap.Clear;
begin
  FreeNodeRecursive(FRoot);
  FRoot := nil;
  FCount := 0;
end;

{ LowerBound — first key >= AKey }

function TBTreeMap.LowerBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
var
  LNode: PNode;
  LIdx: Int32;
  LFound: Boolean;
begin
  Result := False;
  LNode := FRoot;
  while LNode <> nil do
  begin
    if SearchNode(LNode, AKey, LIdx) then
    begin
      AFoundKey := LNode^.Keys[LIdx];
      AValue := LNode^.Values[LIdx];
      Exit(True);
    end;
    if LIdx < LNode^.Count then
    begin
      AFoundKey := LNode^.Keys[LIdx];
      AValue := LNode^.Values[LIdx];
      Result := True;
    end;
    if LNode^.IsLeaf then Exit;
    LNode := LNode^.Children[LIdx];
  end;
end;

{ UpperBound — first key > AKey }

function TBTreeMap.UpperBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
var
  LNode: PNode;
  LIdx: Int32;
begin
  Result := False;
  LNode := FRoot;
  while LNode <> nil do
  begin
    SearchNode(LNode, AKey, LIdx);
    if (LIdx < LNode^.Count) and (FCompare(AKey, LNode^.Keys[LIdx], FCompareData) = 0) then
      Inc(LIdx);
    if LIdx < LNode^.Count then
    begin
      AFoundKey := LNode^.Keys[LIdx];
      AValue := LNode^.Values[LIdx];
      Result := True;
    end;
    if LNode^.IsLeaf then Exit;
    if LIdx <= LNode^.Count then
      LNode := LNode^.Children[LIdx]
    else
      Exit;
  end;
end;

{ Floor — last key <= AKey }

function TBTreeMap.Floor(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
var
  LNode: PNode;
  LIdx: Int32;
begin
  Result := False;
  LNode := FRoot;
  while LNode <> nil do
  begin
    if SearchNode(LNode, AKey, LIdx) then
    begin
      AFoundKey := LNode^.Keys[LIdx];
      AValue := LNode^.Values[LIdx];
      Exit(True);
    end;
    if LIdx > 0 then
    begin
      AFoundKey := LNode^.Keys[LIdx - 1];
      AValue := LNode^.Values[LIdx - 1];
      Result := True;
    end;
    if LNode^.IsLeaf then Exit;
    LNode := LNode^.Children[LIdx];
  end;
end;

{ Rank — number of keys strictly less than AKey }

function TBTreeMap.SubtreeSize(ANode: PNode): SizeUInt;
var i: Int32;
begin
  if ANode = nil then Exit(0);
  Result := SizeUInt(ANode^.Count);
  if not ANode^.IsLeaf then
    for i := 0 to ANode^.Count do
      Result := Result + SubtreeSize(ANode^.Children[i]);
end;

function TBTreeMap.Rank(const AKey: K): SizeUInt;
var
  LNode: PNode;
  LIdx, i: Int32;
begin
  Result := 0;
  LNode := FRoot;
  while LNode <> nil do
  begin
    if SearchNode(LNode, AKey, LIdx) then
    begin
      if not LNode^.IsLeaf then
        for i := 0 to LIdx - 1 do
          Result := Result + SubtreeSize(LNode^.Children[i]);
      Result := Result + SizeUInt(LIdx);
      Exit;
    end;
    if not LNode^.IsLeaf then
      for i := 0 to LIdx - 1 do
        Result := Result + SubtreeSize(LNode^.Children[i]);
    Result := Result + SizeUInt(LIdx);
    if LNode^.IsLeaf then Exit;
    LNode := LNode^.Children[LIdx];
  end;
end;

{ Select — find key at given rank (0-based) }

function TBTreeMap.Select(ARank: SizeUInt; out AKey: K; out AValue: V): Boolean;
var
  LNode: PNode;
  i: Int32;
  LChildSize: SizeUInt;
begin
  if ARank >= FCount then Exit(False);
  LNode := FRoot;
  while LNode <> nil do
  begin
    if LNode^.IsLeaf then
    begin
      AKey := LNode^.Keys[ARank];
      AValue := LNode^.Values[ARank];
      Exit(True);
    end;
    for i := 0 to LNode^.Count - 1 do
    begin
      LChildSize := SubtreeSize(LNode^.Children[i]);
      if ARank < LChildSize then
      begin
        LNode := LNode^.Children[i];
        Break;
      end;
      Dec(ARank, LChildSize);
      if ARank = 0 then
      begin
        AKey := LNode^.Keys[i];
        AValue := LNode^.Values[i];
        Exit(True);
      end;
      Dec(ARank);
      if i = LNode^.Count - 1 then
      begin
        LNode := LNode^.Children[LNode^.Count];
        Break;
      end;
    end;
  end;
  Result := False;
end;

{ ForEach — in-order traversal }

procedure TBTreeMap.InorderTraverse(ANode: PNode; ACallback: TForEachCallback; AData: Pointer);
var i: Int32;
begin
  if ANode = nil then Exit;
  if ANode^.IsLeaf then
  begin
    for i := 0 to ANode^.Count - 1 do
      ACallback(ANode^.Keys[i], ANode^.Values[i], AData);
  end
  else
  begin
    for i := 0 to ANode^.Count - 1 do
    begin
      InorderTraverse(ANode^.Children[i], ACallback, AData);
      ACallback(ANode^.Keys[i], ANode^.Values[i], AData);
    end;
    InorderTraverse(ANode^.Children[ANode^.Count], ACallback, AData);
  end;
end;

procedure TBTreeMap.ForEach(ACallback: TForEachCallback; AData: Pointer);
begin
  InorderTraverse(FRoot, ACallback, AData);
end;

{ Range — visit all keys in [ALo..AHi] }

procedure TBTreeMap.RangeTraverse(ANode: PNode; const ALo, AHi: K;
  ACallback: TForEachCallback; AData: Pointer);
var i: Int32;
begin
  if ANode = nil then Exit;
  if ANode^.IsLeaf then
  begin
    for i := 0 to ANode^.Count - 1 do
    begin
      if FCompare(ANode^.Keys[i], ALo, FCompareData) < 0 then Continue;
      if FCompare(ANode^.Keys[i], AHi, FCompareData) > 0 then Exit;
      ACallback(ANode^.Keys[i], ANode^.Values[i], AData);
    end;
  end
  else
  begin
    for i := 0 to ANode^.Count - 1 do
    begin
      if FCompare(ANode^.Keys[i], ALo, FCompareData) >= 0 then
        RangeTraverse(ANode^.Children[i], ALo, AHi, ACallback, AData);
      if FCompare(ANode^.Keys[i], ALo, FCompareData) < 0 then Continue;
      if FCompare(ANode^.Keys[i], AHi, FCompareData) > 0 then Exit;
      ACallback(ANode^.Keys[i], ANode^.Values[i], AData);
    end;
    if FCompare(ANode^.Keys[ANode^.Count - 1], AHi, FCompareData) <= 0 then
      RangeTraverse(ANode^.Children[ANode^.Count], ALo, AHi, ACallback, AData);
  end;
end;

procedure TBTreeMap.Range(const ALo, AHi: K; ACallback: TForEachCallback; AData: Pointer);
begin
  RangeTraverse(FRoot, ALo, AHi, ACallback, AData);
end;

{ TEnumerator }

function TBTreeMap.TEnumerator.DoMoveNext: Boolean;
var
  LNode: PNode;
  LIdx: Int32;
begin
  while FDepth >= 0 do
  begin
    LNode := FStack[FDepth];
    LIdx := FIndices[FDepth];

    if LNode^.IsLeaf then
    begin
      if LIdx < LNode^.Count then
      begin
        FCurrent.Key := LNode^.Keys[LIdx];
        FCurrent.Value := LNode^.Values[LIdx];
        Inc(FIndices[FDepth]);
        Exit(True);
      end;
      Dec(FDepth);
    end
    else
    begin
      if LIdx <= LNode^.Count then
      begin
        if LIdx > 0 then
        begin
          FCurrent.Key := LNode^.Keys[LIdx - 1];
          FCurrent.Value := LNode^.Values[LIdx - 1];
          Inc(FIndices[FDepth]);
          Inc(FDepth);
          FStack[FDepth] := LNode^.Children[LIdx];
          FIndices[FDepth] := 0;
          Exit(True);
        end
        else
        begin
          Inc(FIndices[FDepth]);
          Inc(FDepth);
          FStack[FDepth] := LNode^.Children[0];
          FIndices[FDepth] := 0;
        end;
      end
      else
        Dec(FDepth);
    end;
  end;
  Result := False;
end;

function TBTreeMap.TEnumerator.MoveNext: Boolean;
begin
  Result := DoMoveNext;
end;

function TBTreeMap.GetEnumerator: TEnumerator;
begin
  Result.FDepth := -1;
  Result.FStarted := False;
  FillChar(Result.FCurrent, SizeOf(TEntry), 0);
  if FRoot <> nil then
  begin
    Result.FDepth := 0;
    Result.FStack[0] := FRoot;
    Result.FIndices[0] := 0;
  end;
end;

{ TBTreeSet }

constructor TBTreeSet.Create(ACompare: TCompareFunc; ACompareData: Pointer);
begin
  inherited Create;
  FInner := TInner.Create(TInner.TCompareFunc(ACompare), ACompareData);
end;

destructor TBTreeSet.Destroy;
begin
  FInner.Free;
  inherited Destroy;
end;

procedure TBTreeSet.Add(const AItem: T);
begin
  FInner.Put(AItem, 0);
end;

function TBTreeSet.Contains(const AItem: T): Boolean;
begin
  Result := FInner.ContainsKey(AItem);
end;

function TBTreeSet.Remove(const AItem: T): Boolean;
begin
  Result := FInner.Remove(AItem);
end;

procedure TBTreeSet.Clear;
begin
  FInner.Clear;
end;

function TBTreeSet.Min(out AItem: T): Boolean;
var LDummy: Byte;
begin
  Result := FInner.Min(AItem, LDummy);
end;

function TBTreeSet.Max(out AItem: T): Boolean;
var LDummy: Byte;
begin
  Result := FInner.Max(AItem, LDummy);
end;

function TBTreeSet.GetCount: SizeUInt;
begin
  Result := FInner.Count;
end;

function TBTreeSet.LowerBound(const AItem: T; out AFound: T): Boolean;
var LDummy: Byte;
begin
  Result := FInner.LowerBound(AItem, AFound, LDummy);
end;

function TBTreeSet.UpperBound(const AItem: T; out AFound: T): Boolean;
var LDummy: Byte;
begin
  Result := FInner.UpperBound(AItem, AFound, LDummy);
end;

function TBTreeSet.Floor(const AItem: T; out AFound: T): Boolean;
var LDummy: Byte;
begin
  Result := FInner.Floor(AItem, AFound, LDummy);
end;

end.