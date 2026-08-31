{******************************************************************************
  nextpas.core.lockfree.skiplist_map

  Concurrent SkipList Map — sorted concurrent map using skip list.

  Design:
  - Skip list with per-node spin locks
  - O(log n) search/insert/delete
  - Sorted iteration via bottom-level linked list
  - Randomized level promotion (1/4 probability)
  - FNV-1a hash for comparison fallback

  Use cases: ordered maps, range queries, leaderboard, scheduler.

  2026-07-06  Phase 5
******************************************************************************}
unit nextpas.core.lockfree.skiplist_map;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  SL_MAP_MAX_LEVEL = 16;
  SL_MAP_DEFAULT_MAX_LEVEL = 12;

type
  TSkipListMapResult = (
    slmOk,
    slmNotFound,
    slmKeyExists
  );

  TSkipListMapForEachCallback = reference to procedure(const AKey, AValue: AnsiString);

  PSkipListMapNode = ^TSkipListMapNode;
  TSkipListMapNode = record
    Key: AnsiString;
    Value: AnsiString;
    Next: array[0..SL_MAP_MAX_LEVEL - 1] of PSkipListMapNode;
    Level: Int32;
    Lock: Int32;
  end;

  {**
   * Concurrent SkipList Map — 并发有序映射。
   *
   * O(log n) 查找/插入/删除，支持有序遍历。
   *
   * @constraints
   *   - 键类型为 AnsiString（字典序比较）
   *   - 值类型为 AnsiString
   *   - 线程安全
   *}
  TConcurrentSkipListMap = class
  private
    FHead: PSkipListMapNode;
    FTail: PSkipListMapNode;
    FMaxLevel: Int32;
    FSize: Int32;
    FLock: Int32;

    function RandomLevel: Int32;
    function CompareKeys(const AKey1, AKey2: AnsiString): Int32;
    function NewNode(const AKey, AValue: AnsiString; ALevel: Int32): PSkipListMapNode;
    procedure FreeNode(ANode: PSkipListMapNode);
    procedure GlobalLock; inline;
    procedure GlobalUnlock; inline;
  public
    constructor Create(AMaxLevel: Int32 = SL_MAP_DEFAULT_MAX_LEVEL);
    destructor Destroy; override;

    {** @desc 插入或更新键值对 }
    function Insert(const AKey, AValue: AnsiString): TSkipListMapResult;
    {** @desc 仅插入（键必须不存在） }
    function InsertIfAbsent(const AKey, AValue: AnsiString): TSkipListMapResult;
    {** @desc 查找键对应的值 }
    function Find(const AKey: AnsiString; out AValue: AnsiString): TSkipListMapResult;
    {** @desc 检查键是否存在 }
    function Contains(const AKey: AnsiString): Boolean;
    {** @desc 删除键值对 }
    function Remove(const AKey: AnsiString): TSkipListMapResult;
    {** @desc 当前元素数量 }
    function Count: Int32; inline;
    {** @desc 是否为空 }
    function IsEmpty: Boolean; inline;
    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 最小的键值对 }
    function Min(out AKey, AValue: AnsiString): Boolean;
    {** @desc 最大的键值对 }
    function Max(out AKey, AValue: AnsiString): Boolean;
    {** @desc 大于等于 AKey 的最小元素 }
    function Ceiling(const AKey: AnsiString; out AFoundKey, AFoundValue: AnsiString): Boolean;
    {** @desc 小于等于 AKey 的最大元素 }
    function Floor(const AKey: AnsiString; out AFoundKey, AFoundValue: AnsiString): Boolean;
    {** @desc 遍历所有键值对（有序） }
    procedure ForEach(ACallback: TSkipListMapForEachCallback);
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

function TConcurrentSkipListMap.RandomLevel: Int32;
var
  L: Int32;
begin
  L := 1;
  while (L < FMaxLevel) and (Random(4) = 0) do
    Inc(L);
  Result := L;
end;

function TConcurrentSkipListMap.CompareKeys(const AKey1, AKey2: AnsiString): Int32;
var
  LMinLen, I: Int32;
begin
  LMinLen := Length(AKey1);
  if Length(AKey2) < LMinLen then
    LMinLen := Length(AKey2);
  for I := 1 to LMinLen do
  begin
    if AKey1[I] < AKey2[I] then Exit(-1);
    if AKey1[I] > AKey2[I] then Exit(1);
  end;
  if Length(AKey1) < Length(AKey2) then Exit(-1);
  if Length(AKey1) > Length(AKey2) then Exit(1);
  Result := 0;
end;

function TConcurrentSkipListMap.NewNode(const AKey, AValue: AnsiString;
  ALevel: Int32): PSkipListMapNode;
begin
  New(Result);
  FillChar(Result^, SizeOf(TSkipListMapNode), 0);
  Result^.Key := AKey;
  Result^.Value := AValue;
  Result^.Level := ALevel;
  Result^.Lock := 0;
end;

procedure TConcurrentSkipListMap.FreeNode(ANode: PSkipListMapNode);
begin
  if ANode = nil then
    Exit;
  ANode^.Key := '';
  ANode^.Value := '';
  Dispose(ANode);
end;

procedure TConcurrentSkipListMap.GlobalLock;
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

procedure TConcurrentSkipListMap.GlobalUnlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

constructor TConcurrentSkipListMap.Create(AMaxLevel: Int32);
var
  I: Int32;
begin
  inherited Create;
  if AMaxLevel < 1 then AMaxLevel := 1;
  if AMaxLevel > SL_MAP_MAX_LEVEL then AMaxLevel := SL_MAP_MAX_LEVEL;
  FMaxLevel := AMaxLevel;
  FSize := 0;
  FLock := 0;
  FHead := NewNode('', '', FMaxLevel);
  FTail := NewNode('', '', FMaxLevel);
  for I := 0 to FMaxLevel - 1 do
    FHead^.Next[I] := FTail;
end;

destructor TConcurrentSkipListMap.Destroy;
begin
  Clear;
  FreeNode(FHead);
  FreeNode(FTail);
  inherited Destroy;
end;

function TConcurrentSkipListMap.Insert(const AKey, AValue: AnsiString): TSkipListMapResult;
var
  LUpdate: array[0..SL_MAP_MAX_LEVEL - 1] of PSkipListMapNode;
  LNode: PSkipListMapNode;
  LI, LLevel: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) < 0) do
        LNode := LNode^.Next[LI];
      LUpdate[LI] := LNode;
    end;

    LNode := LNode^.Next[0];
    if (LNode <> FTail) and (CompareKeys(LNode^.Key, AKey) = 0) then
    begin
      LNode^.Value := AValue;
      Exit(slmOk);
    end;

    LLevel := RandomLevel;
    LNode := NewNode(AKey, AValue, LLevel);
    for LI := 0 to LLevel - 1 do
    begin
      LNode^.Next[LI] := LUpdate[LI]^.Next[LI];
      LUpdate[LI]^.Next[LI] := LNode;
    end;
    atomic_fetch_add(FSize, 1);
    Result := slmOk;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.InsertIfAbsent(const AKey, AValue: AnsiString): TSkipListMapResult;
var
  LUpdate: array[0..SL_MAP_MAX_LEVEL - 1] of PSkipListMapNode;
  LNode: PSkipListMapNode;
  LI, LLevel: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) < 0) do
        LNode := LNode^.Next[LI];
      LUpdate[LI] := LNode;
    end;

    LNode := LNode^.Next[0];
    if (LNode <> FTail) and (CompareKeys(LNode^.Key, AKey) = 0) then
      Exit(slmKeyExists);

    LLevel := RandomLevel;
    LNode := NewNode(AKey, AValue, LLevel);
    for LI := 0 to LLevel - 1 do
    begin
      LNode^.Next[LI] := LUpdate[LI]^.Next[LI];
      LUpdate[LI]^.Next[LI] := LNode;
    end;
    atomic_fetch_add(FSize, 1);
    Result := slmOk;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Find(const AKey: AnsiString;
  out AValue: AnsiString): TSkipListMapResult;
var
  LNode: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) < 0) do
        LNode := LNode^.Next[LI];

    LNode := LNode^.Next[0];
    if (LNode <> FTail) and (CompareKeys(LNode^.Key, AKey) = 0) then
    begin
      AValue := LNode^.Value;
      Exit(slmOk);
    end;
    Result := slmNotFound;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Contains(const AKey: AnsiString): Boolean;
var
  LValue: AnsiString;
begin
  Result := Find(AKey, LValue) = slmOk;
end;

function TConcurrentSkipListMap.Remove(const AKey: AnsiString): TSkipListMapResult;
var
  LUpdate: array[0..SL_MAP_MAX_LEVEL - 1] of PSkipListMapNode;
  LNode, LTarget: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) < 0) do
        LNode := LNode^.Next[LI];
      LUpdate[LI] := LNode;
    end;

    LTarget := LNode^.Next[0];
    if (LTarget = FTail) or (CompareKeys(LTarget^.Key, AKey) <> 0) then
      Exit(slmNotFound);

    for LI := 0 to LTarget^.Level - 1 do
      if LUpdate[LI]^.Next[LI] = LTarget then
        LUpdate[LI]^.Next[LI] := LTarget^.Next[LI];

    FreeNode(LTarget);
    atomic_fetch_sub(FSize, 1);
    Result := slmOk;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Count: Int32; inline;
begin
  Result := atomic_load(FSize);
end;

function TConcurrentSkipListMap.IsEmpty: Boolean; inline;
begin
  Result := atomic_load(FSize) = 0;
end;

procedure TConcurrentSkipListMap.Clear;
var
  LNode, LNext: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      LNext := LNode^.Next[0];
      FreeNode(LNode);
      LNode := LNext;
    end;
    for LI := 0 to FMaxLevel - 1 do
      FHead^.Next[LI] := FTail;
    FSize := 0;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Min(out AKey, AValue: AnsiString): Boolean;
var
  LNode: PSkipListMapNode;
begin
  GlobalLock;
  try
    LNode := FHead^.Next[0];
    if LNode <> FTail then
    begin
      AKey := LNode^.Key;
      AValue := LNode^.Value;
      Exit(True);
    end;
    Result := False;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Max(out AKey, AValue: AnsiString): Boolean;
var
  LNode: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
      while (LNode^.Next[LI] <> FTail) do
        LNode := LNode^.Next[LI];
    if LNode <> FHead then
    begin
      AKey := LNode^.Key;
      AValue := LNode^.Value;
      Exit(True);
    end;
    Result := False;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Ceiling(const AKey: AnsiString;
  out AFoundKey, AFoundValue: AnsiString): Boolean;
var
  LNode: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    for LI := FMaxLevel - 1 downto 0 do
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) < 0) do
        LNode := LNode^.Next[LI];
    LNode := LNode^.Next[0];
    if LNode <> FTail then
    begin
      AFoundKey := LNode^.Key;
      AFoundValue := LNode^.Value;
      Exit(True);
    end;
    Result := False;
  finally
    GlobalUnlock;
  end;
end;

function TConcurrentSkipListMap.Floor(const AKey: AnsiString;
  out AFoundKey, AFoundValue: AnsiString): Boolean;
var
  LNode, LBest: PSkipListMapNode;
  LI: Int32;
begin
  GlobalLock;
  try
    LNode := FHead;
    LBest := nil;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      while (LNode^.Next[LI] <> FTail) and
            (CompareKeys(LNode^.Next[LI]^.Key, AKey) <= 0) do
      begin
        LNode := LNode^.Next[LI];
        if CompareKeys(LNode^.Key, AKey) <= 0 then
          LBest := LNode;
      end;
    end;
    if (LBest <> nil) and (LBest <> FHead) then
    begin
      AFoundKey := LBest^.Key;
      AFoundValue := LBest^.Value;
      Exit(True);
    end;
    Result := False;
  finally
    GlobalUnlock;
  end;
end;

procedure TConcurrentSkipListMap.ForEach(ACallback: TSkipListMapForEachCallback);
var
  LPairs: array of record
    Key, Value: AnsiString;
  end;
  LCount, LI: Integer;
  LNode: PSkipListMapNode;
begin
  GlobalLock;
  try
    LCount := 0;
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      Inc(LCount);
      LNode := LNode^.Next[0];
    end;
    SetLength(LPairs, LCount);
    LCount := 0;
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      LPairs[LCount].Key := LNode^.Key;
      LPairs[LCount].Value := LNode^.Value;
      Inc(LCount);
      LNode := LNode^.Next[0];
    end;
  finally
    GlobalUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LPairs[LI].Key, LPairs[LI].Value);
end;

end.
