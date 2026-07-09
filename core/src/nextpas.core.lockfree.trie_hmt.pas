{******************************************************************************
  nextpas.core.lockfree.trie_hmt

  Hash Mapped Trie (HMT) — persistent immutable trie for concurrent maps.

  Design:
  - 32-way branching (5 bits per level), 7 levels max for 32-bit hash
  - Path copying for persistence: writes create new nodes along the path
  - CAS swap of root pointer for atomic updates
  - Reads follow any root snapshot — lock-free
  - Immutable nodes: safe to share across threads without synchronization

  Use cases: persistent maps, version snapshots, functional programming.

  2026-07-06  Phase 3
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.trie_hmt;

interface

uses
  SysUtils;

const
  HMT_BRANCH_BITS = 5;
  HMT_BRANCH_FACTOR = 1 shl HMT_BRANCH_BITS; { 32 }
  HMT_MAX_DEPTH = 7; { 32 / 5 = 6.4, round up }

type
  THmtResult = (
    hmtOk,
    hmtNotFound,
    hmtKeyExists,
    hmtEmpty
  );

  THmtNodeKind = (
    hnkEmpty,
    hnkLeaf,
    hnkBranch,
    hnkCollision
  );

  THmtLeaf = record
    Hash: UInt32;
    Key: AnsiString;
    Value: AnsiString;
  end;

  PHmtNode = ^THmtNode;
  THmtNode = record
    Kind: THmtNodeKind;
    Count: Int32;
    { Leaf data }
    LeafHash: UInt32;
    LeafKey: AnsiString;
    LeafValue: AnsiString;
    { Branch data }
    Children: array[0..HMT_BRANCH_FACTOR - 1] of PHmtNode;
    { Collision data }
    Collision: array of THmtLeaf;
  end;

  THmtSnapshot = record
    Root: PHmtNode;
    Size: Int32;
  end;

  THashMappedTrie = class
  private
    FRoot: PHmtNode;
    FSize: Int32;

    function HashKey(const AKey: AnsiString): UInt32;
    function NewLeaf(AHash: UInt32; const AKey, AValue: AnsiString): PHmtNode;
    function NewBranch: PHmtNode;
    function NewCollision(AHash: UInt32; const AKey1, AValue1, AKey2, AValue2: AnsiString): PHmtNode;

    function NodeInsert(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey, AValue: AnsiString; out ANew: PHmtNode): THmtResult;
    function NodeRemove(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey: AnsiString; out ANew: PHmtNode): THmtResult;
    function NodeFind(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey: AnsiString; out AValue: AnsiString): Boolean;

    procedure FreeNode(ANode: PHmtNode);
    function CloneBranch(ANode: PHmtNode): PHmtNode;
  public
    constructor Create;
    destructor Destroy; override;

    function Insert(const AKey, AValue: AnsiString): THmtResult;
    function Remove(const AKey: AnsiString): THmtResult;
    function Find(const AKey: AnsiString; out AValue: AnsiString): Boolean;
    function Contains(const AKey: AnsiString): Boolean;
    function Size: Int32;
    function IsEmpty: Boolean;

    { Snapshot: returns an immutable view }
    function Snapshot: THmtSnapshot;
  end;

implementation

uses
  nextpas.core.atomic;

{ ---------- FNV-1a ---------- }

function Fnv1aHash(const AData: Pointer; ALength: Int32): UInt32;
const
  FNV_OFFSET = 2166136261;
  FNV_PRIME  = 16777619;
var
  I: Int32;
  LByte: PByte;
begin
  Result := FNV_OFFSET;
  LByte := PByte(AData);
  for I := 0 to ALength - 1 do
  begin
    Result := Result xor LByte^;
    Result := Result * FNV_PRIME;
    Inc(LByte);
  end;
end;

{ ---------- THashMappedTrie ---------- }

constructor THashMappedTrie.Create;
begin
  inherited Create;
  FRoot := nil;
  FSize := 0;
end;

destructor THashMappedTrie.Destroy;
begin
  FreeNode(FRoot);
  inherited Destroy;
end;

function THashMappedTrie.HashKey(const AKey: AnsiString): UInt32;
begin
  if Length(AKey) = 0 then
    Result := 0
  else
    Result := Fnv1aHash(@AKey[1], Length(AKey));
end;

function THashMappedTrie.NewLeaf(AHash: UInt32; const AKey, AValue: AnsiString): PHmtNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(THmtNode), 0);
  Result^.Kind := hnkLeaf;
  Result^.Count := 1;
  Result^.LeafHash := AHash;
  Result^.LeafKey := AKey;
  Result^.LeafValue := AValue;
end;

function THashMappedTrie.NewBranch: PHmtNode;
var
  I: Int32;
begin
  New(Result);
  FillChar(Result^, SizeOf(THmtNode), 0);
  Result^.Kind := hnkBranch;
  Result^.Count := 0;
  for I := 0 to HMT_BRANCH_FACTOR - 1 do
    Result^.Children[I] := nil;
end;

function THashMappedTrie.NewCollision(AHash: UInt32;
  const AKey1, AValue1, AKey2, AValue2: AnsiString): PHmtNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(THmtNode), 0);
  Result^.Kind := hnkCollision;
  Result^.Count := 2;
  SetLength(Result^.Collision, 2);
  Result^.Collision[0].Hash := AHash;
  Result^.Collision[0].Key := AKey1;
  Result^.Collision[0].Value := AValue1;
  Result^.Collision[1].Hash := AHash;
  Result^.Collision[1].Key := AKey2;
  Result^.Collision[1].Value := AValue2;
end;

function THashMappedTrie.CloneBranch(ANode: PHmtNode): PHmtNode;
var
  I: Int32;
begin
  if ANode = nil then
    Exit(nil);
  New(Result);
  FillChar(Result^, SizeOf(THmtNode), 0);
  Result^.Kind := ANode^.Kind;
  Result^.Count := ANode^.Count;
  case ANode^.Kind of
    hnkLeaf:
    begin
      Result^.LeafHash := ANode^.LeafHash;
      Result^.LeafKey := ANode^.LeafKey;
      Result^.LeafValue := ANode^.LeafValue;
    end;
    hnkBranch:
    begin
      for I := 0 to HMT_BRANCH_FACTOR - 1 do
        Result^.Children[I] := ANode^.Children[I];
    end;
    hnkCollision:
    begin
      SetLength(Result^.Collision, Length(ANode^.Collision));
      for I := 0 to Length(ANode^.Collision) - 1 do
        Result^.Collision[I] := ANode^.Collision[I];
    end;
  end;
end;

function THashMappedTrie.NodeInsert(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
  const AKey, AValue: AnsiString; out ANew: PHmtNode): THmtResult;
var
  LIdx, J: Int32;
  LChild, LNewChild: PHmtNode;
  I: Int32;
begin
  if ANode = nil then
  begin
    { Empty slot: insert leaf }
    ANew := NewLeaf(AHash, AKey, AValue);
    Exit(hmtOk);
  end;

  case ANode^.Kind of
    hnkLeaf:
    begin
      if ANode^.LeafKey = AKey then
      begin
        { Update existing key }
        if ANode^.LeafValue = AValue then
        begin
          ANew := ANode;
          Exit(hmtOk);
        end;
        ANew := NewLeaf(AHash, AKey, AValue);
        Result := hmtOk;
      end
      else if ANode^.LeafHash = AHash then
      begin
        { Hash collision: create collision node }
        ANew := NewCollision(AHash, ANode^.LeafKey, ANode^.LeafValue, AKey, AValue);
        Result := hmtOk;
      end
      else
      begin
        { Different hash: create branch and split }
        ANew := NewBranch;
        LIdx := (ANode^.LeafHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
        ANew^.Children[LIdx] := ANode;
        LIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
        ANew^.Children[LIdx] := NewLeaf(AHash, AKey, AValue);
        ANew^.Count := 2;
        Result := hmtOk;
      end;
    end;

    hnkBranch:
    begin
      LIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
      LChild := ANode^.Children[LIdx];
      Result := NodeInsert(LChild, AHash, ADepth + 1, AKey, AValue, LNewChild);
      if (Result = hmtOk) and (LNewChild <> LChild) then
      begin
        { Path copy: clone branch, update one child }
        ANew := CloneBranch(ANode);
        if (LChild = nil) and (LNewChild <> nil) then
          Inc(ANew^.Count);
        ANew^.Children[LIdx] := LNewChild;
      end
      else
        ANew := ANode;
    end;

    hnkCollision:
    begin
      { Check if key exists in collision list }
      for I := 0 to ANode^.Count - 1 do
        if ANode^.Collision[I].Key = AKey then
        begin
          { Update value in collision list }
          New(ANew);
          FillChar(ANew^, SizeOf(THmtNode), 0);
          ANew^.Kind := hnkCollision;
          ANew^.Count := ANode^.Count;
          SetLength(ANew^.Collision, ANew^.Count);
          for J := 0 to ANode^.Count - 1 do
            ANew^.Collision[J] := ANode^.Collision[J];
          ANew^.Collision[I].Value := AValue;
          Exit(hmtOk);
        end;

      { Add to collision list }
      New(ANew);
      FillChar(ANew^, SizeOf(THmtNode), 0);
      ANew^.Kind := hnkCollision;
      ANew^.Count := ANode^.Count + 1;
      SetLength(ANew^.Collision, ANew^.Count);
      for I := 0 to ANode^.Count - 1 do
        ANew^.Collision[I] := ANode^.Collision[I];
      ANew^.Collision[ANew^.Count - 1].Hash := AHash;
      ANew^.Collision[ANew^.Count - 1].Key := AKey;
      ANew^.Collision[ANew^.Count - 1].Value := AValue;
      Result := hmtOk;
    end;
  else
    ANew := ANode;
    Result := hmtEmpty;
  end;
end;

function THashMappedTrie.NodeRemove(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
  const AKey: AnsiString; out ANew: PHmtNode): THmtResult;
var
  LIdx, I, J, K: Int32;
  LChild, LNewChild: PHmtNode;
  LNonNilCount: Int32;
  LOnlyChild: PHmtNode;
begin
  if ANode = nil then
  begin
    ANew := nil;
    Exit(hmtNotFound);
  end;

  case ANode^.Kind of
    hnkLeaf:
    begin
      if ANode^.LeafKey = AKey then
      begin
        ANew := nil;
        Exit(hmtOk);
      end;
      ANew := ANode;
      Result := hmtNotFound;
    end;

    hnkBranch:
    begin
      LIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
      LChild := ANode^.Children[LIdx];
      Result := NodeRemove(LChild, AHash, ADepth + 1, AKey, LNewChild);
      if Result <> hmtOk then
      begin
        ANew := ANode;
        Exit;
      end;

      { Path copy }
      ANew := CloneBranch(ANode);
      ANew^.Children[LIdx] := LNewChild;
      if (LChild <> nil) and (LNewChild = nil) then
        Dec(ANew^.Count);

      { Collapse branch with single child }
      if ANew^.Count <= 1 then
      begin
        LNonNilCount := 0;
        LOnlyChild := nil;
        for I := 0 to HMT_BRANCH_FACTOR - 1 do
          if ANew^.Children[I] <> nil then
          begin
            Inc(LNonNilCount);
            LOnlyChild := ANew^.Children[I];
          end;
        if LNonNilCount = 1 then
        begin
          Dispose(ANew);
          ANew := LOnlyChild;
        end;
      end;
    end;

    hnkCollision:
    begin
      for I := 0 to ANode^.Count - 1 do
        if ANode^.Collision[I].Key = AKey then
        begin
          if ANode^.Count = 2 then
          begin
            { Collapse to single leaf }
            J := 1 - I;
            ANew := NewLeaf(ANode^.Collision[J].Hash, ANode^.Collision[J].Key, ANode^.Collision[J].Value);
          end
          else
          begin
            { Remove from collision list }
            New(ANew);
            FillChar(ANew^, SizeOf(THmtNode), 0);
            ANew^.Kind := hnkCollision;
            ANew^.Count := ANode^.Count - 1;
            SetLength(ANew^.Collision, ANew^.Count);
            J := 0;
            for K := 0 to ANode^.Count - 1 do
              if K <> I then
              begin
                ANew^.Collision[J] := ANode^.Collision[K];
                Inc(J);
              end;
          end;
          Exit(hmtOk);
        end;
      ANew := ANode;
      Result := hmtNotFound;
    end;
  else
    ANew := ANode;
    Result := hmtNotFound;
  end;
end;

function THashMappedTrie.NodeFind(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
  const AKey: AnsiString; out AValue: AnsiString): Boolean;
var
  LIdx, I: Int32;
begin
  Result := False;
  AValue := '';
  if ANode = nil then
    Exit;

  case ANode^.Kind of
    hnkLeaf:
    begin
      if ANode^.LeafKey = AKey then
      begin
        AValue := ANode^.LeafValue;
        Result := True;
      end;
    end;

    hnkBranch:
    begin
      LIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
      Result := NodeFind(ANode^.Children[LIdx], AHash, ADepth + 1, AKey, AValue);
    end;

    hnkCollision:
    begin
      for I := 0 to ANode^.Count - 1 do
        if ANode^.Collision[I].Key = AKey then
        begin
          AValue := ANode^.Collision[I].Value;
          Exit(True);
        end;
    end;
  end;
end;

procedure THashMappedTrie.FreeNode(ANode: PHmtNode);
var
  I: Int32;
begin
  if ANode = nil then
    Exit;
  case ANode^.Kind of
    hnkBranch:
      for I := 0 to HMT_BRANCH_FACTOR - 1 do
        FreeNode(ANode^.Children[I]);
    hnkCollision:
      SetLength(ANode^.Collision, 0);
  end;
  Dispose(ANode);
end;

function THashMappedTrie.Insert(const AKey, AValue: AnsiString): THmtResult;
var
  LHash: UInt32;
  LNewRoot: PHmtNode;
  LExistingValue: AnsiString;
  LIsUpdate: Boolean;
begin
  LHash := HashKey(AKey);

  { Check if key already exists (update vs insert) }
  LIsUpdate := NodeFind(FRoot, LHash, 0, AKey, LExistingValue);

  Result := NodeInsert(FRoot, LHash, 0, AKey, AValue, LNewRoot);
  if (Result = hmtOk) and (LNewRoot <> FRoot) then
  begin
    { Swap root atomically }
    AtomicStorePtr(Pointer(FRoot), Pointer(LNewRoot), moRelease);
    if not LIsUpdate then
      AtomicFetchAdd32(FSize, 1);
  end;
end;

function THashMappedTrie.Remove(const AKey: AnsiString): THmtResult;
var
  LHash: UInt32;
  LNewRoot: PHmtNode;
begin
  LHash := HashKey(AKey);
  Result := NodeRemove(FRoot, LHash, 0, AKey, LNewRoot);
  if (Result = hmtOk) and (LNewRoot <> FRoot) then
  begin
    AtomicStorePtr(Pointer(FRoot), Pointer(LNewRoot), moRelease);
    AtomicFetchAdd32(FSize, -1);
  end;
end;

function THashMappedTrie.Find(const AKey: AnsiString; out AValue: AnsiString): Boolean;
begin
  Result := NodeFind(FRoot, HashKey(AKey), 0, AKey, AValue);
end;

function THashMappedTrie.Contains(const AKey: AnsiString): Boolean;
var
  LValue: AnsiString;
begin
  Result := Find(AKey, LValue);
end;

function THashMappedTrie.Size: Int32;
begin
  Result := AtomicLoad32(FSize, moAcquire);
end;

function THashMappedTrie.IsEmpty: Boolean;
begin
  Result := AtomicLoad32(FSize, moAcquire) = 0;
end;

function THashMappedTrie.Snapshot: THmtSnapshot;
begin
  Result.Root := AtomicLoadPtr(Pointer(FRoot), moAcquire);
  Result.Size := AtomicLoad32(FSize, moAcquire);
end;

end.
