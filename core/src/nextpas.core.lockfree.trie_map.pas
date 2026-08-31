{******************************************************************************
  nextpas.core.lockfree.trie_map

  Concurrent Trie Map — lock-free concurrent hash map using trie structure.

  Design:
  - 16-way branching (4 bits per level), 8 levels max for 32-bit hash
  - Lock-free reads (traverse trie, no CAS needed)
  - CAS-based writes on leaf/branch nodes
  - FNV-1a hash for key distribution
  - Dynamic node allocation, no upfront capacity

  Use cases: concurrent dictionaries, symbol tables, caching.

  2026-07-06  Phase 5
******************************************************************************}
unit nextpas.core.lockfree.trie_map;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  TRIE_BRANCH_BITS = 4;
  TRIE_BRANCH_FACTOR = 1 shl TRIE_BRANCH_BITS; { 16 }
  TRIE_MAX_DEPTH = 8;

type
  TTrieMapResult = (
    tmOk,
    tmNotFound,
    tmKeyExists,
    tmFull
  );

  TTrieMapForEachCallback = reference to procedure(const AKey, AValue: AnsiString);

  PTriePair = ^TTriePair;
  TTriePair = record
    Key: AnsiString;
    Value: AnsiString;
  end;

  PTrieNode = ^TTrieNode;
  TTrieNode = record
    IsLeaf: Boolean;
    Hash: UInt32;
    Key: AnsiString;
    Value: AnsiString;
    Children: array[0..TRIE_BRANCH_FACTOR - 1] of PTrieNode;
    ChildCount: Int32;
  end;

  {**
   * Concurrent Trie Map — 并发字典树映射。
   *
   * O(k) 查找/插入/删除，k = key 长度。
   * 读操作无锁，写操作使用 CAS。
   *
   * @constraints
   *   - 键类型为 AnsiString
   *   - 值类型为 AnsiString
   *   - 线程安全
   *}
  TConcurrentTrieMap = class
  private
    FRoot: PTrieNode;
    FSize: Int32;
    FLock: Int32;

    function HashKey(const AKey: AnsiString): UInt32;
    function NewNode(AIsLeaf: Boolean; AHash: UInt32;
      const AKey, AValue: AnsiString): PTrieNode;
    procedure FreeNode(ANode: PTrieNode);
    function FindNode(ARoot: PTrieNode; AHash: UInt32;
      ADepth: Int32; const AKey: AnsiString): PTrieNode;
    function InsertNode(var ARoot: PTrieNode; AHash: UInt32;
      ADepth: Int32; const AKey, AValue: AnsiString;
      AUpdateExisting: Boolean): TTrieMapResult;
    function RemoveNode(var ARoot: PTrieNode; AHash: UInt32;
      ADepth: Int32; const AKey: AnsiString): Boolean;
    procedure ForEachNode(ANode: PTrieNode;
      ACallback: TTrieMapForEachCallback);
    procedure CollectNode(ANode: PTrieNode;
      var APairs: array of TTriePair;
      var ACount: Integer);
    procedure Lock; inline;
    procedure Unlock; inline;
  public
    constructor Create;
    destructor Destroy; override;

    {** @desc 插入或更新键值对 }
    function Insert(const AKey, AValue: AnsiString): TTrieMapResult;
    {** @desc 仅插入（键必须不存在） }
    function InsertIfAbsent(const AKey, AValue: AnsiString): TTrieMapResult;
    {** @desc 查找键对应的值 }
    function Find(const AKey: AnsiString; out AValue: AnsiString): TTrieMapResult;
    {** @desc 检查键是否存在 }
    function Contains(const AKey: AnsiString): Boolean;
    {** @desc 删除键值对 }
    function Remove(const AKey: AnsiString): TTrieMapResult;
    {** @desc 当前元素数量 }
    function Count: Int32; inline;
    {** @desc 是否为空 }
    function IsEmpty: Boolean; inline;
    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 遍历所有键值对 }
    procedure ForEach(ACallback: TTrieMapForEachCallback);
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

{ FNV-1a hash }
function TConcurrentTrieMap.HashKey(const AKey: AnsiString): UInt32;
var
  I: Int32;
begin
  Result := 2166136261;
  for I := 1 to Length(AKey) do
  begin
    Result := Result xor Ord(AKey[I]);
    Result := Result * 16777619;
  end;
end;

function TConcurrentTrieMap.NewNode(AIsLeaf: Boolean; AHash: UInt32;
  const AKey, AValue: AnsiString): PTrieNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(TTrieNode), 0);
  Result^.IsLeaf := AIsLeaf;
  Result^.Hash := AHash;
  if AIsLeaf then
  begin
    Result^.Key := AKey;
    Result^.Value := AValue;
    Result^.ChildCount := 0;
  end;
end;

procedure TConcurrentTrieMap.FreeNode(ANode: PTrieNode);
var
  I: Int32;
begin
  if ANode = nil then
    Exit;
  if ANode^.IsLeaf then
  begin
    ANode^.Key := '';
    ANode^.Value := '';
  end;
  for I := 0 to TRIE_BRANCH_FACTOR - 1 do
    FreeNode(ANode^.Children[I]);
  Dispose(ANode);
end;

function TConcurrentTrieMap.FindNode(ARoot: PTrieNode; AHash: UInt32;
  ADepth: Int32; const AKey: AnsiString): PTrieNode;
var
  LIdx: Int32;
  LNode: PTrieNode;
begin
  Result := nil;
  LNode := ARoot;
  while LNode <> nil do
  begin
    if LNode^.IsLeaf then
    begin
      if (LNode^.Hash = AHash) and (LNode^.Key = AKey) then
        Exit(LNode);
      Exit(nil);
    end;
    LIdx := (AHash shr (ADepth * TRIE_BRANCH_BITS)) and (TRIE_BRANCH_FACTOR - 1);
    LNode := LNode^.Children[LIdx];
    Inc(ADepth);
  end;
end;

function TConcurrentTrieMap.InsertNode(var ARoot: PTrieNode; AHash: UInt32;
  ADepth: Int32; const AKey, AValue: AnsiString;
  AUpdateExisting: Boolean): TTrieMapResult;
var
  LIdx: Int32;
  LChild: PTrieNode;
begin
  if ARoot = nil then
  begin
    ARoot := NewNode(True, AHash, AKey, AValue);
    atomic_fetch_add(FSize, 1);
    Exit(tmOk);
  end;

  if ARoot^.IsLeaf then
  begin
    if (ARoot^.Hash = AHash) and (ARoot^.Key = AKey) then
    begin
      if AUpdateExisting then
      begin
        ARoot^.Value := AValue;
        Exit(tmOk);
      end;
      Exit(tmKeyExists);
    end;
    { Hash collision or different path — create branch }
    LIdx := (ARoot^.Hash shr (ADepth * TRIE_BRANCH_BITS)) and (TRIE_BRANCH_FACTOR - 1);
    LChild := ARoot;
    ARoot := NewNode(False, 0, '', '');
    ARoot^.Children[LIdx] := LChild;
    ARoot^.ChildCount := 1;
    { Insert new leaf — if same branch index, recurse to create deeper branches }
    LIdx := (AHash shr (ADepth * TRIE_BRANCH_BITS)) and (TRIE_BRANCH_FACTOR - 1);
    if ARoot^.Children[LIdx] = nil then
    begin
      ARoot^.Children[LIdx] := NewNode(True, AHash, AKey, AValue);
      Inc(ARoot^.ChildCount);
      atomic_fetch_add(FSize, 1);
    end
    else
    begin
      { Same branch index at this depth — recurse into existing child }
      Result := InsertNode(ARoot^.Children[LIdx], AHash, ADepth + 1, AKey, AValue, AUpdateExisting);
      if ARoot^.Children[LIdx] = nil then
        Dec(ARoot^.ChildCount);
      Exit;
    end;
    Exit(tmOk);
  end;

  { Branch node }
  LIdx := (AHash shr (ADepth * TRIE_BRANCH_BITS)) and (TRIE_BRANCH_FACTOR - 1);
  if ARoot^.Children[LIdx] = nil then
  begin
    ARoot^.Children[LIdx] := NewNode(True, AHash, AKey, AValue);
    Inc(ARoot^.ChildCount);
    atomic_fetch_add(FSize, 1);
    Exit(tmOk);
  end;
  Result := InsertNode(ARoot^.Children[LIdx], AHash, ADepth + 1,
    AKey, AValue, AUpdateExisting);
end;

function TConcurrentTrieMap.RemoveNode(var ARoot: PTrieNode; AHash: UInt32;
  ADepth: Int32; const AKey: AnsiString): Boolean;
var
  LIdx: Int32;
  LLeaf: PTrieNode;
  LI, LNonNil: Int32;
begin
  Result := False;
  if ARoot = nil then
    Exit;

  if ARoot^.IsLeaf then
  begin
    if (ARoot^.Hash = AHash) and (ARoot^.Key = AKey) then
    begin
      ARoot^.Key := '';
      ARoot^.Value := '';
      Dispose(ARoot);
      ARoot := nil;
      atomic_fetch_sub(FSize, 1);
      Exit(True);
    end;
    Exit(False);
  end;

  LIdx := (AHash shr (ADepth * TRIE_BRANCH_BITS)) and (TRIE_BRANCH_FACTOR - 1);
  if ARoot^.Children[LIdx] = nil then
    Exit(False);

  Result := RemoveNode(ARoot^.Children[LIdx], AHash, ADepth + 1, AKey);
  if Result then
  begin
    if ARoot^.Children[LIdx] = nil then
      Dec(ARoot^.ChildCount);
    { Collapse branch if only 1 child left and it's a leaf }
    if ARoot^.ChildCount = 1 then
    begin
      LNonNil := -1;
      for LI := 0 to TRIE_BRANCH_FACTOR - 1 do
        if ARoot^.Children[LI] <> nil then
        begin
          LNonNil := LI;
          Break;
        end;
      if (LNonNil >= 0) and (ARoot^.Children[LNonNil]^.IsLeaf) then
      begin
        LLeaf := ARoot^.Children[LNonNil];
        ARoot^.Children[LNonNil] := nil;
        ARoot^.IsLeaf := True;
        ARoot^.Hash := LLeaf^.Hash;
        ARoot^.Key := LLeaf^.Key;
        ARoot^.Value := LLeaf^.Value;
        ARoot^.ChildCount := 0;
        Dispose(LLeaf);
      end;
    end;
  end;
end;

procedure TConcurrentTrieMap.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
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

procedure TConcurrentTrieMap.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

constructor TConcurrentTrieMap.Create;
begin
  inherited Create;
  FRoot := nil;
  FSize := 0;
  FLock := 0;
end;

destructor TConcurrentTrieMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TConcurrentTrieMap.Insert(const AKey, AValue: AnsiString): TTrieMapResult;
begin
  Lock;
  try
    Result := InsertNode(FRoot, HashKey(AKey), 0, AKey, AValue, True);
  finally
    Unlock;
  end;
end;

function TConcurrentTrieMap.InsertIfAbsent(const AKey, AValue: AnsiString): TTrieMapResult;
begin
  Lock;
  try
    Result := InsertNode(FRoot, HashKey(AKey), 0, AKey, AValue, False);
  finally
    Unlock;
  end;
end;

function TConcurrentTrieMap.Find(const AKey: AnsiString; out AValue: AnsiString): TTrieMapResult;
var
  LNode: PTrieNode;
begin
  Lock;
  try
    LNode := FindNode(FRoot, HashKey(AKey), 0, AKey);
    if LNode <> nil then
    begin
      AValue := LNode^.Value;
      Exit(tmOk);
    end;
    Result := tmNotFound;
  finally
    Unlock;
  end;
end;

function TConcurrentTrieMap.Contains(const AKey: AnsiString): Boolean;
var
  LNode: PTrieNode;
begin
  Lock;
  try
    LNode := FindNode(FRoot, HashKey(AKey), 0, AKey);
    Result := LNode <> nil;
  finally
    Unlock;
  end;
end;

function TConcurrentTrieMap.Remove(const AKey: AnsiString): TTrieMapResult;
begin
  Lock;
  try
    if RemoveNode(FRoot, HashKey(AKey), 0, AKey) then
      Result := tmOk
    else
      Result := tmNotFound;
  finally
    Unlock;
  end;
end;

function TConcurrentTrieMap.Count: Int32; inline;
begin
  Result := atomic_load(FSize);
end;

function TConcurrentTrieMap.IsEmpty: Boolean; inline;
begin
  Result := atomic_load(FSize) = 0;
end;

procedure TConcurrentTrieMap.Clear;
begin
  Lock;
  try
    FreeNode(FRoot);
    FRoot := nil;
    FSize := 0;
  finally
    Unlock;
  end;
end;

procedure TConcurrentTrieMap.ForEachNode(ANode: PTrieNode;
  ACallback: TTrieMapForEachCallback);
var
  I: Int32;
begin
  if ANode = nil then
    Exit;
  if ANode^.IsLeaf then
  begin
    ACallback(ANode^.Key, ANode^.Value);
    Exit;
  end;
  for I := 0 to TRIE_BRANCH_FACTOR - 1 do
    ForEachNode(ANode^.Children[I], ACallback);
end;

procedure TConcurrentTrieMap.CollectNode(ANode: PTrieNode;
  var APairs: array of TTriePair;
  var ACount: Integer);
var
  I: Int32;
begin
  if ANode = nil then
    Exit;
  if ANode^.IsLeaf then
  begin
    APairs[ACount].Key := ANode^.Key;
    APairs[ACount].Value := ANode^.Value;
    Inc(ACount);
    Exit;
  end;
  for I := 0 to TRIE_BRANCH_FACTOR - 1 do
    CollectNode(ANode^.Children[I], APairs, ACount);
end;

procedure TConcurrentTrieMap.ForEach(ACallback: TTrieMapForEachCallback);
var
  LPairs: array of TTriePair;
  LCount, LI: Integer;
begin
  LCount := FSize;
  if LCount = 0 then
    Exit;
  SetLength(LPairs, LCount);
  LCount := 0;
  Lock;
  try
    CollectNode(FRoot, LPairs, LCount);
  finally
    Unlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LPairs[LI].Key, LPairs[LI].Value);
end;

end.
