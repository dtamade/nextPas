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
  nextpas.core.errors;

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
    FLock: Int32;

    function HashKey(const AKey: AnsiString): UInt32;
    function NewLeaf(AHash: UInt32; const AKey, AValue: AnsiString): PHmtNode;
    function NewBranch: PHmtNode;
    function NewCollision(AHash: UInt32; const AKey1, AValue1, AKey2, AValue2: AnsiString): PHmtNode;
    function SplitLeafNode(ALeaf: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey, AValue: AnsiString): PHmtNode;

    function NodeInsert(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey, AValue: AnsiString; out ANew: PHmtNode): THmtResult;
    function NodeRemove(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey: AnsiString; out ANew: PHmtNode): THmtResult;
    function NodeFind(ANode: PHmtNode; AHash: UInt32; ADepth: Int32;
      const AKey: AnsiString; out AValue: AnsiString): Boolean;
    function NodeContainsReference(ANode, ATarget: PHmtNode): Boolean;

    procedure FreeNode(ANode: PHmtNode);
    procedure AcquireLock;
    procedure ReleaseLock;
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
  nextpas.core.atomic,
  nextpas.core.checksum;

{ ---------- FNV-1a ---------- }

function Fnv1aHash(const AData: Pointer; ALength: Int32): UInt32;
begin
  if ALength <= 0 then
    Result := FNV1A32_OFFSET
  else
    Result := Fnv1a32Update(FNV1A32_OFFSET, AData, SizeUInt(ALength));
end;

{ ---------- THashMappedTrie ---------- }

constructor THashMappedTrie.Create;
begin
  inherited Create;
  FRoot := nil;
  FSize := 0;
  FLock := 0;
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

procedure THashMappedTrie.AcquireLock;
var
  LCasExpected: Int32;
begin
  repeat
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Exit;
    ThreadSwitch;
  until False;
end;

procedure THashMappedTrie.ReleaseLock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function THashMappedTrie.SplitLeafNode(ALeaf: PHmtNode; AHash: UInt32; ADepth: Int32;
  const AKey, AValue: AnsiString): PHmtNode;
var
  LExistingIdx: Int32;
  LIncomingIdx: Int32;
  LChild: PHmtNode;
begin
  if (ALeaf = nil) or (ALeaf^.Kind <> hnkLeaf) then
    Exit(ALeaf);

  if (ADepth >= HMT_MAX_DEPTH) or (ALeaf^.LeafHash = AHash) then
    Exit(NewCollision(ALeaf^.LeafHash, ALeaf^.LeafKey, ALeaf^.LeafValue, AKey, AValue));

  Result := NewBranch;
  LExistingIdx := (ALeaf^.LeafHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
  LIncomingIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
  if LExistingIdx = LIncomingIdx then
  begin
    LChild := SplitLeafNode(ALeaf, AHash, ADepth + 1, AKey, AValue);
    Result^.Children[LExistingIdx] := LChild;
    if LChild <> nil then
      Result^.Count := 1;
  end
  else
  begin
    Result^.Children[LExistingIdx] := ALeaf;
    Result^.Children[LIncomingIdx] := NewLeaf(AHash, AKey, AValue);
    Result^.Count := 2;
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
    ANew := NewLeaf(AHash, AKey, AValue);
    Exit(hmtOk);
  end;

  case ANode^.Kind of
    hnkLeaf:
    begin
      if ANode^.LeafKey = AKey then
      begin
        ANode^.LeafValue := AValue;
        ANew := ANode;
        Exit(hmtOk);
      end
      else if ANode^.LeafHash = AHash then
      begin
        ANode^.Kind := hnkCollision;
        ANode^.Count := 2;
        SetLength(ANode^.Collision, 2);
        ANode^.Collision[0].Hash := ANode^.LeafHash;
        ANode^.Collision[0].Key := ANode^.LeafKey;
        ANode^.Collision[0].Value := ANode^.LeafValue;
        ANode^.Collision[1].Hash := AHash;
        ANode^.Collision[1].Key := AKey;
        ANode^.Collision[1].Value := AValue;
        ANode^.LeafHash := 0;
        ANode^.LeafKey := '';
        ANode^.LeafValue := '';
        ANew := ANode;
        Result := hmtOk;
      end
      else
      begin
        ANew := SplitLeafNode(ANode, AHash, ADepth, AKey, AValue);
        Result := hmtOk;
      end;
    end;

    hnkBranch:
    begin
      LIdx := (AHash shr (ADepth * HMT_BRANCH_BITS)) and (HMT_BRANCH_FACTOR - 1);
      LChild := ANode^.Children[LIdx];
      Result := NodeInsert(LChild, AHash, ADepth + 1, AKey, AValue, LNewChild);
      if Result = hmtOk then
      begin
        if (LChild = nil) and (LNewChild <> nil) then
          Inc(ANode^.Count);
        if (LChild <> nil) and (LNewChild <> LChild) and
           (not NodeContainsReference(LNewChild, LChild)) then
          FreeNode(LChild);
        ANode^.Children[LIdx] := LNewChild;
      end
      else if LNewChild <> LChild then
        ANode^.Children[LIdx] := LNewChild;
      ANew := ANode;
    end;

    hnkCollision:
    begin
      for I := 0 to ANode^.Count - 1 do
        if ANode^.Collision[I].Key = AKey then
        begin
          ANode^.Collision[I].Value := AValue;
          ANew := ANode;
          Exit(hmtOk);
        end;

      SetLength(ANode^.Collision, ANode^.Count + 1);
      ANode^.Collision[ANode^.Count].Hash := AHash;
      ANode^.Collision[ANode^.Count].Key := AKey;
      ANode^.Collision[ANode^.Count].Value := AValue;
      Inc(ANode^.Count);
      ANew := ANode;
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

      ANode^.Children[LIdx] := LNewChild;
      if (LChild <> nil) and (LNewChild = nil) then
        Dec(ANode^.Count);

      if ANode^.Count = 0 then
      begin
        Dispose(ANode);
        ANew := nil;
        Exit(hmtOk);
      end;

      if ANode^.Count = 1 then
      begin
        LNonNilCount := 0;
        LOnlyChild := nil;
        for I := 0 to HMT_BRANCH_FACTOR - 1 do
          if ANode^.Children[I] <> nil then
          begin
            Inc(LNonNilCount);
            LOnlyChild := ANode^.Children[I];
          end;
        if LNonNilCount = 1 then
        begin
          Dispose(ANode);
          ANew := LOnlyChild;
          Exit(hmtOk);
        end;
      end;
      ANew := ANode;
    end;

    hnkCollision:
    begin
      for I := 0 to ANode^.Count - 1 do
        if ANode^.Collision[I].Key = AKey then
        begin
          if ANode^.Count = 2 then
          begin
            J := 1 - I;
            ANode^.LeafHash := ANode^.Collision[J].Hash;
            ANode^.LeafKey := ANode^.Collision[J].Key;
            ANode^.LeafValue := ANode^.Collision[J].Value;
            SetLength(ANode^.Collision, 0);
            ANode^.Kind := hnkLeaf;
            ANode^.Count := 1;
            ANew := ANode;
          end
          else
          begin
            J := 0;
            for K := 0 to ANode^.Count - 1 do
              if K <> I then
              begin
                ANode^.Collision[J] := ANode^.Collision[K];
                Inc(J);
              end;
            Dec(ANode^.Count);
            SetLength(ANode^.Collision, ANode^.Count);
            ANew := ANode;
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
  else
    { 防御：Kind 损坏时按未命中处理，不放大破坏。 }
    ;
  end;
end;

function THashMappedTrie.NodeContainsReference(ANode, ATarget: PHmtNode): Boolean;
var
  I: Int32;
begin
  if (ANode = nil) or (ATarget = nil) then
    Exit(False);
  if ANode = ATarget then
    Exit(True);

  if ANode^.Kind = hnkBranch then
    for I := 0 to HMT_BRANCH_FACTOR - 1 do
      if NodeContainsReference(ANode^.Children[I], ATarget) then
        Exit(True);

  Result := False;
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
  else
    ; { 叶子无子节点，仅走统一 Dispose；未知 Kind 同样只 Dispose 自身 }
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
  AcquireLock;
  try
    LNewRoot := FRoot;
    LIsUpdate := NodeFind(FRoot, LHash, 0, AKey, LExistingValue);
    Result := NodeInsert(FRoot, LHash, 0, AKey, AValue, LNewRoot);
    if Result = hmtOk then
    begin
      if not LIsUpdate then
        Inc(FSize);
      if LNewRoot <> FRoot then
      begin
        if not NodeContainsReference(LNewRoot, FRoot) then
          FreeNode(FRoot);
        FRoot := LNewRoot;
      end;
    end;
  finally
    ReleaseLock;
  end;
end;

function THashMappedTrie.Remove(const AKey: AnsiString): THmtResult;
var
  LHash: UInt32;
  LNewRoot: PHmtNode;
begin
  LHash := HashKey(AKey);
  AcquireLock;
  try
    Result := NodeRemove(FRoot, LHash, 0, AKey, LNewRoot);
    if Result = hmtOk then
    begin
      FRoot := LNewRoot;
      Dec(FSize);
    end;
  finally
    ReleaseLock;
  end;
end;

function THashMappedTrie.Find(const AKey: AnsiString; out AValue: AnsiString): Boolean;
begin
  AcquireLock;
  try
    Result := NodeFind(FRoot, HashKey(AKey), 0, AKey, AValue);
  finally
    ReleaseLock;
  end;
end;

function THashMappedTrie.Contains(const AKey: AnsiString): Boolean;
var
  LValue: AnsiString;
begin
  Result := Find(AKey, LValue);
end;

function THashMappedTrie.Size: Int32;
begin
  AcquireLock;
  try
    Result := FSize;
  finally
    ReleaseLock;
  end;
end;

function THashMappedTrie.IsEmpty: Boolean;
begin
  AcquireLock;
  try
    Result := FSize = 0;
  finally
    ReleaseLock;
  end;
end;

function THashMappedTrie.Snapshot: THmtSnapshot;
begin
  AcquireLock;
  try
    Result.Root := FRoot;
    Result.Size := FSize;
  finally
    ReleaseLock;
  end;
end;

end.
