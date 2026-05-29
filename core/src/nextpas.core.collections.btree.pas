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
    PNode = ^TNode;
    TNode = record
      Count: Int32;
      IsLeaf: Boolean;
      Keys: array[0..BTREE_MAX_KEYS - 1] of K;
      Values: array[0..BTREE_MAX_KEYS - 1] of V;
      Children: array[0..BTREE_MAX_KEYS] of PNode;
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

    property Count: SizeUInt read FCount;
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
  while lo <= hi do
  begin
    mid := (lo + hi) shr 1;
    cmp := FCompare(AKey, ANode^.Keys[mid], FCompareData);
    if cmp = 0 then begin AIndex := mid; Exit(True); end;
    if cmp < 0 then hi := mid - 1 else lo := mid + 1;
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
    while (i >= 0) and (FCompare(AKey, ANode^.Keys[i], FCompareData) < 0) do
    begin
      ANode^.Keys[i + 1] := ANode^.Keys[i];
      ANode^.Values[i + 1] := ANode^.Values[i];
      Dec(i);
    end;
    ANode^.Keys[i + 1] := AKey;
    ANode^.Values[i + 1] := AValue;
    Inc(ANode^.Count);
    Inc(FCount);
  end
  else
  begin
    while (i >= 0) and (FCompare(AKey, ANode^.Keys[i], FCompareData) < 0) do
      Dec(i);
    Inc(i);
    if ANode^.Children[i]^.Count = BTREE_MAX_KEYS then
    begin
      SplitChild(ANode, i);
      cmp := FCompare(AKey, ANode^.Keys[i], FCompareData);
      if cmp = 0 then
      begin
        // key already exists at split point — update
        if System.IsManagedType(V) then Finalize(ANode^.Values[i]);
        ANode^.Values[i] := AValue;
        Exit;
      end;
      if cmp > 0 then Inc(i);
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
begin
  // TODO: full B-tree deletion (complex: borrow/merge)
  Result := False;
end;

procedure TBTreeMap.RemoveFromNode(ANode: PNode; const AKey: K); begin end;
procedure TBTreeMap.RemoveFromLeaf(ANode: PNode; AIndex: Int32); begin end;
procedure TBTreeMap.RemoveFromInternal(ANode: PNode; AIndex: Int32); begin end;
procedure TBTreeMap.Fill(ANode: PNode; AIndex: Int32); begin end;
procedure TBTreeMap.BorrowFromPrev(ANode: PNode; AIndex: Int32); begin end;
procedure TBTreeMap.BorrowFromNext(ANode: PNode; AIndex: Int32); begin end;
procedure TBTreeMap.MergeChildren(ANode: PNode; AIndex: Int32); begin end;
function TBTreeMap.FindPredecessor(ANode: PNode): PNode; begin Result := nil; end;
function TBTreeMap.FindSuccessor(ANode: PNode): PNode; begin Result := nil; end;

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

end.