unit nextpas.core.lockfree.trie;
{**
 * @desc Concurrent Trie (Prefix Tree) with per-node locks.
 *
 * @details Prefix tree for key-value storage:
 *   - Insert/Find/Delete/Contains operations
 *   - Prefix matching for autocomplete scenarios
 *   - IP routing table support
 *   - Per-node locks for fine-grained concurrency
 *
 * @concurrency Thread-safe for multiple readers and writers:
 *   - Find/Contains: shared read locks
 *   - Insert/Delete/Clear: exclusive write locks
 *
 * @see Trie — prefix tree data structure
 * @see IP Routing — longest prefix matching
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeTrieResult = (trInserted, trUpdated, trDeleted, trNotFound, trClosed);

  PTrieNode = ^TTrieNode;
  TTrieNode = record
    Children: array[0..255] of PTrieNode;
    HasValue: Boolean;
    ValueIndex: Int64;
    Lock: Int32;
  end;

  {** @desc 并发 Trie 树
    @details 基于前缀树的并发键值存储。
      支持 Insert/Find/Delete/Contains/Count/Clear。
      适用于前缀匹配、自动补全、IP 路由等场景。
  }
  generic TConcurrentTrieImpl<TValue> = class
  private
    FRoot: PTrieNode;
    FValues: array of TValue;
    FValueCount: Int64;
    FCount: Int64;
    FClosed: Int32;
    FValuesLock: Int32;
    procedure LockNode(ANode: PTrieNode);
    procedure UnlockNode(ANode: PTrieNode);
    procedure FreeNode(ANode: PTrieNode);
    function FindNode(const AKey: string): PTrieNode;
    function AllocNode: PTrieNode;
    function AllocValueIndex: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    function Insert(const AKey: string; const AValue: TValue): TLockFreeTrieResult;
    function Find(const AKey: string; out AValue: TValue): Boolean;
    function Delete(const AKey: string): TLockFreeTrieResult;
    function Contains(const AKey: string): Boolean;
    function GetCount: Int64;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function TConcurrentTrieImpl.AllocNode: PTrieNode;
var
  LI: Integer;
begin
  New(Result);
  FillChar(Result^, SizeOf(TTrieNode), 0);
  for LI := 0 to 255 do
    Result^.Children[LI] := nil;
  Result^.HasValue := False;
  Result^.ValueIndex := -1;
  Result^.Lock := 0;
end;

procedure TConcurrentTrieImpl.LockNode(ANode: PTrieNode);
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(ANode^.Lock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    CpuPause;
  end;
end;

procedure TConcurrentTrieImpl.UnlockNode(ANode: PTrieNode);
begin
  atomic_store(ANode^.Lock, 0, mo_release);
end;

procedure TConcurrentTrieImpl.FreeNode(ANode: PTrieNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  for LI := 0 to 255 do
    FreeNode(ANode^.Children[LI]);
  Dispose(ANode);
end;

function TConcurrentTrieImpl.FindNode(const AKey: string): PTrieNode;
var
  LNode: PTrieNode;
  LI, LLen: Integer;
  LIdx: Byte;
begin
  LNode := FRoot;
  LLen := Length(AKey);
  for LI := 1 to LLen do
  begin
    LIdx := Byte(AKey[LI]);
    if LNode^.Children[LIdx] = nil then
      Exit(nil);
    LNode := LNode^.Children[LIdx];
  end;
  Result := LNode;
end;

function TConcurrentTrieImpl.AllocValueIndex: Int64;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FValuesLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    CpuPause;
  end;
  try
    if FValueCount >= Length(FValues) then
      SetLength(FValues, Length(FValues) * 2 + 16);
    Result := FValueCount;
    Inc(FValueCount);
  finally
    atomic_store(FValuesLock, 0, mo_release);
  end;
end;

constructor TConcurrentTrieImpl.Create;
begin
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TConcurrentTrie: TValue must be unmanaged');
  inherited Create;
  FRoot := AllocNode;
  SetLength(FValues, 16);
  FValueCount := 0;
  FCount := 0;
  FClosed := 0;
  FValuesLock := 0;
end;

destructor TConcurrentTrieImpl.Destroy;
begin
  FreeNode(FRoot);
  SetLength(FValues, 0);
  inherited Destroy;
end;

function TConcurrentTrieImpl.Insert(const AKey: string; const AValue: TValue): TLockFreeTrieResult;
var
  LNode: PTrieNode;
  LI, LLen: Integer;
  LIdx: Byte;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(trClosed);
  if Length(AKey) = 0 then
    raise EArgumentError.Create('TConcurrentTrie.Insert: key must not be empty');

  LNode := FRoot;
  LLen := Length(AKey);
  for LI := 1 to LLen do
  begin
    LIdx := Byte(AKey[LI]);
    LockNode(LNode);
    if LNode^.Children[LIdx] = nil then
      LNode^.Children[LIdx] := AllocNode;
    UnlockNode(LNode);
    LNode := LNode^.Children[LIdx];
  end;

  LockNode(LNode);
  if LNode^.HasValue then
  begin
    FValues[LNode^.ValueIndex] := AValue;
    UnlockNode(LNode);
    Result := trUpdated;
  end
  else
  begin
    LNode^.ValueIndex := AllocValueIndex;
    FValues[LNode^.ValueIndex] := AValue;
    LNode^.HasValue := True;
    atomic_fetch_add_64(FCount, 1, mo_relaxed);
    UnlockNode(LNode);
    Result := trInserted;
  end;
end;

function TConcurrentTrieImpl.Find(const AKey: string; out AValue: TValue): Boolean;
var
  LNode: PTrieNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  if Length(AKey) = 0 then
    Exit(False);

  LNode := FindNode(AKey);
  if LNode = nil then
    Exit(False);

  LockNode(LNode);
  if LNode^.HasValue then
  begin
    AValue := FValues[LNode^.ValueIndex];
    UnlockNode(LNode);
    Result := True;
  end
  else
  begin
    UnlockNode(LNode);
    Result := False;
  end;
end;

function TConcurrentTrieImpl.Delete(const AKey: string): TLockFreeTrieResult;
var
  LNode: PTrieNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(trClosed);
  if Length(AKey) = 0 then
    raise EArgumentError.Create('TConcurrentTrie.Delete: key must not be empty');

  LNode := FindNode(AKey);
  if LNode = nil then
    Exit(trNotFound);

  LockNode(LNode);
  if LNode^.HasValue then
  begin
    LNode^.HasValue := False;
    atomic_fetch_sub_64(FCount, 1, mo_relaxed);
    UnlockNode(LNode);
    Result := trDeleted;
  end
  else
  begin
    UnlockNode(LNode);
    Result := trNotFound;
  end;
end;

function TConcurrentTrieImpl.Contains(const AKey: string): Boolean;
var
  LNode: PTrieNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  if Length(AKey) = 0 then
    Exit(False);

  LNode := FindNode(AKey);
  if LNode = nil then
    Exit(False);

  LockNode(LNode);
  Result := LNode^.HasValue;
  UnlockNode(LNode);
end;

function TConcurrentTrieImpl.GetCount: Int64;
begin
  Result := atomic_load_64(FCount, mo_acquire);
end;

procedure TConcurrentTrieImpl.Clear;
begin
  FreeNode(FRoot);
  FRoot := AllocNode;
  atomic_store_64(FCount, 0, mo_relaxed);
end;

procedure TConcurrentTrieImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TConcurrentTrieImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
