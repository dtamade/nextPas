unit nextpas.core.lockfree.hazard;
{**
 * @desc Hazard Pointer memory reclamation scheme.
 *
 * @details Lock-free memory reclamation using hazard pointers:
 *   - Each thread publishes pointers it's currently accessing
 *   - Retired nodes are only reclaimed when no thread holds a hazard pointer
 *   - Complements EBR (Epoch-Based Reclamation) for different use cases
 *
 * @concurrency Thread-safe for multiple threads:
 *   - Acquire/Release: per-thread hazard pointer management
 *   - Retire: thread-safe retirement list
 *   - Reclaim: safe reclamation when no hazards exist
 *
 * @see Hazard Pointers — Maged Michael, 2004
 * @see EBR — Epoch-Based Reclamation (complementary approach)
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.ebr;

const
  HAZARD_DEFAULT_HP_COUNT = 2;
  HAZARD_RETIRE_BATCH = 10;

type
  PHazardThreadRec = ^THazardThreadRec;
  THazardThreadRec = record
    Next: PHazardThreadRec;
    HP: array of Pointer;
  end;

  PHazardRetiredNode = ^THazardRetiredNode;
  THazardRetiredNode = record
    Next: PHazardRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;

  {** @desc Hazard Pointer 内存回收域（与 EBR 互补，适合读多写少场景）
    @details **与 TEbrDomain 的关键区别**:
    - TEbrDomain.Enter/Leave 是轻量级原子计数（O(1)），TEbrGuard 仅管理计数
    - THazardDomain.RegisterThread 分配线程节点并加入链表，THazardGuard 会自动调用 RegisterThread/UnregisterThread
    - TEbrDomain.ActiveCount 是 O(1) 原子读，THazardDomain.ActiveThreads 遍历链表 O(n)
    - THazardDomain 保护单个指针（HP slot），TEbrDomain 保护整个临界区

    **Guard 语义差异**:
    - TEbrGuard.Acquire(Domain) → Domain.Enter（计数+1）
    - THazardGuard.Acquire(Domain) → Domain.RegisterThread（分配线程节点）；Release → UnregisterThread
    - 从 EBR 切换到 Hazard 时，Guard 的生命周期语义完全不同，必须重新评估使用模式
  }
  THazardDomain = class
  private
    FHPCount: PtrUInt;
    FThreads: PHazardThreadRec;
    FThreadsLock: Int32;
    FRetired: PHazardRetiredNode;
    FGlobalRetiredCount: Int32;
    procedure AcquireThreads;
    procedure ReleaseThreads;
    procedure IncrementRetiredCount;
  public
    {** @desc 创建 Hazard Domain（AHPCount 每线程 HP 数） }
    constructor Create(const AHPCount: PtrUInt = HAZARD_DEFAULT_HP_COUNT);
    destructor Destroy; override;

    {** @desc 注册调用线程，返回线程 ID }
    function RegisterThread: PtrUInt;
    {** @desc 注销线程 }
    procedure UnregisterThread(const AThreadId: PtrUInt);

    {** @desc 保护指针（返回 APtr，带 memory barrier） }
    function Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
    {** @desc Atomically load, publish, and revalidate a replaceable source pointer. }
    function ProtectSource(const AThreadId: PtrUInt; const AHPIndex: PtrUInt;
      const ASource: PPointer): Pointer;
    {** @desc 清除保护 }
    procedure Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);

    {** @desc 退休指针（批量触发 Collect） }
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer = nil);
    {** @desc 回收未被任何线程保护的退休指针 }
    procedure Collect(const AThreadId: PtrUInt);

    {** @desc 活跃线程数（O(n) 遍历链表，跳过已逻辑删除的线程）
      @note 与 TEbrDomain.ActiveCount（O(1) 原子读）不同，此方法需要遍历整个线程链表。
        高频调用场景应缓存结果或改用 TEbrDomain。 }
    function ActiveThreads: PtrUInt;
    {** @desc 退休待回收数 }
    function RetiredCount: PtrUInt; inline;
  end;

  {** @desc Hazard Pointer RAII 守卫（自动 Register/Protect/Clear/Unregister）
    @details 获取时注册线程并保护指针，释放时清除保护并注销线程。
      重复 Release 安全（FActive 守卫）。

      **与 TEbrGuard 的区别**:
      - TEbrGuard.Acquire 仅调用 Domain.Enter（原子计数+1）
      - THazardGuard.Acquire 调用 Domain.RegisterThread（分配线程节点加入链表）
      - 因此 THazardGuard 的创建/销毁开销高于 TEbrGuard，但提供精确的指针级保护

      **nil Domain 行为**: Acquire(nil) 返回 FActive=False 的空守卫，Protect 直接透传指针（不做保护），
      Release 为空操作。用于需要统一代码路径但某些执行环境不需要内存保护的场景。
    @example
      var LGuard: THazardGuard;
      LGuard := THazardGuard.Acquire(LDomain, 0);
      try
        LPtr := LGuard.Protect(LSrcPtr);
        // 安全访问 LPtr
      finally
        LGuard.Release;
      end;
  }
  THazardGuard = record
  private
    FDomain: THazardDomain;
    FThreadId: PtrUInt;
    FHPIndex: PtrUInt;
    FActive: Boolean;
  public
    {** @desc 获取守卫：注册线程 + 设置 HP 索引 }
    class function Acquire(const ADomain: THazardDomain; const AHPIndex: PtrUInt = 0): THazardGuard; static;
    {** @desc 保护指针（返回 APtr，带 memory barrier） }
    function Protect(const APtr: Pointer): Pointer;
    function ProtectSource(const ASource: PPointer): Pointer;
    {** @desc 释放守卫：清除保护 + 注销线程（重复调用安全） }
    procedure Release;
  end;

implementation

{ THazardDomain }

constructor THazardDomain.Create(const AHPCount: PtrUInt);
begin
  inherited Create;
  if AHPCount = 0 then
    raise EArgumentError.Create('THazardDomain: HP count must be > 0');
  FHPCount := AHPCount;
  FThreads := nil;
  FThreadsLock := 0;
  FRetired := nil;
  FGlobalRetiredCount := 0;
end;

procedure THazardDomain.AcquireThreads;
var
  LSpinCount: Int32;
begin
  LSpinCount := 0;
  while AtomicCompareExchange32(FThreadsLock, 0, 1, moAcquire) <> 0 do
  begin
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure THazardDomain.ReleaseThreads;
begin
  AtomicStore32(FThreadsLock, 0, moRelease);
end;

procedure THazardDomain.IncrementRetiredCount;
var
  LCount: Int32;
begin
  repeat
    LCount := AtomicLoad32(FGlobalRetiredCount, moAcquire);
    if LCount = High(Int32) then
      raise EInvalidOperationError.Create('THazardDomain.Retire: retired count overflow');
  until AtomicCompareExchange32(FGlobalRetiredCount, LCount, LCount + 1,
    moAcqRel) = LCount;
end;

destructor THazardDomain.Destroy;
var
  LThread: PHazardThreadRec;
  LNextThread: PHazardThreadRec;
  LNode: PHazardRetiredNode;
  LNext: PHazardRetiredNode;
begin
  // 释放所有线程节点（包括已逻辑删除的）
  LThread := FThreads;
  while LThread <> nil do
  begin
    LNextThread := LThread^.Next;
    SetLength(LThread^.HP, 0);
    FreeMem(LThread, SizeOf(THazardThreadRec));
    LThread := LNextThread;
  end;
  // 释放所有退休节点
  LNode := FRetired;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode, SizeOf(THazardRetiredNode));
    LNode := LNext;
  end;
  inherited;
end;

function THazardDomain.RegisterThread: PtrUInt;
var
  LThread: PHazardThreadRec;
  LI: PtrUInt;
begin
  LThread := AllocMem(SizeOf(THazardThreadRec));
  LThread^.Next := nil;
  SetLength(LThread^.HP, FHPCount);
  for LI := 0 to FHPCount - 1 do
    LThread^.HP[LI] := nil;
  AcquireThreads;
  try
    LThread^.Next := FThreads;
    FThreads := LThread;
  finally
    ReleaseThreads;
  end;
  Result := PtrUInt(LThread);
end;

procedure THazardDomain.UnregisterThread(const AThreadId: PtrUInt);
var
  LThread: PHazardThreadRec;
  LCurrent: PHazardThreadRec;
  LPrevious: PHazardThreadRec;
  LI: PtrUInt;
begin
  LThread := PHazardThreadRec(AThreadId);
  if LThread = nil then
    Exit;
  AcquireThreads;
  try
    LPrevious := nil;
    LCurrent := FThreads;
    while (LCurrent <> nil) and (LCurrent <> LThread) do
    begin
      LPrevious := LCurrent;
      LCurrent := LCurrent^.Next;
    end;
    if LCurrent = nil then
      Exit;
    if LPrevious = nil then
      FThreads := LCurrent^.Next
    else
      LPrevious^.Next := LCurrent^.Next;
    for LI := 0 to FHPCount - 1 do
      AtomicStorePtr(LCurrent^.HP[LI], nil, moRelease);
    SetLength(LCurrent^.HP, 0);
    FreeMem(LCurrent, SizeOf(THazardThreadRec));
  finally
    ReleaseThreads;
  end;
end;

function THazardDomain.Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
var
  LThread: PHazardThreadRec;
begin
  LThread := PHazardThreadRec(AThreadId);
  {$IFDEF DEBUG}
  if LThread = nil then
    raise EArgumentError.CreateFmt('THazardDomain.Protect: nil thread ID (HP index=%d)', [AHPIndex]);
  if AHPIndex >= FHPCount then
    raise EArgumentError.CreateFmt('THazardDomain.Protect: HP index %d out of bounds (max=%d)', [AHPIndex, FHPCount - 1]);
  {$ENDIF}
  if (LThread = nil) or (AHPIndex >= FHPCount) then
  begin
    Result := APtr;
    Exit;
  end;
  AtomicStorePtr(LThread^.HP[AHPIndex], APtr, moRelease);
  Result := APtr;
end;

function THazardDomain.ProtectSource(const AThreadId: PtrUInt;
  const AHPIndex: PtrUInt; const ASource: PPointer): Pointer;
var
  LThread: PHazardThreadRec;
begin
  if ASource = nil then
    raise EArgumentError.Create('THazardDomain.ProtectSource: source must not be nil');
  LThread := PHazardThreadRec(AThreadId);
  if (LThread = nil) or (AHPIndex >= FHPCount) then
    raise EArgumentError.Create('THazardDomain.ProtectSource: invalid thread or HP index');
  repeat
    Result := AtomicLoadPtr(ASource^, moAcquire);
    AtomicStorePtr(LThread^.HP[AHPIndex], Result, moRelease);
  until AtomicLoadPtr(ASource^, moAcquire) = Result;
end;

procedure THazardDomain.Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);
var
  LThread: PHazardThreadRec;
begin
  LThread := PHazardThreadRec(AThreadId);
  {$IFDEF DEBUG}
  if LThread = nil then
    raise EArgumentError.CreateFmt('THazardDomain.Clear: nil thread ID (HP index=%d)', [AHPIndex]);
  if AHPIndex >= FHPCount then
    raise EArgumentError.CreateFmt('THazardDomain.Clear: HP index %d out of bounds (max=%d)', [AHPIndex, FHPCount - 1]);
  {$ENDIF}
  if (LThread = nil) or (AHPIndex >= FHPCount) then
    Exit;
  AtomicStorePtr(LThread^.HP[AHPIndex], nil, moRelease);
end;

procedure THazardDomain.Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LNode: PHazardRetiredNode;
begin
  if AData = nil then
    Exit;
  LNode := GetMem(SizeOf(THazardRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  try
    IncrementRetiredCount;
  except
    FreeMem(LNode, SizeOf(THazardRetiredNode));
    raise;
  end;
  repeat
    LNode^.Next := PHazardRetiredNode(AtomicLoadPtr(Pointer(FRetired), moRelaxed));
  until AtomicCompareExchangePtr(Pointer(FRetired), LNode^.Next, LNode, moRelease) = LNode^.Next;
  // 不遍历线程链表触发 Collect（避免并发修改链表导致悬空指针）
  // Collect 由调用者显式触发，或在 Destroy 中统一回收
end;

procedure THazardDomain.Collect(const AThreadId: PtrUInt);
var
  LList: PHazardRetiredNode;
  LNode: PHazardRetiredNode;
  LPrev: PHazardRetiredNode;
  LNext: PHazardRetiredNode;
  LThread: PHazardThreadRec;
  LProtected: Boolean;
  LI: PtrUInt;
  LHazardIndex: PtrUInt;
  LHazards: array of Pointer;
  LHazardCount: PtrUInt;
  LReclaimCount: Int32;
begin
  LHazardCount := 0;
  AcquireThreads;
  try
    LThread := FThreads;
    while LThread <> nil do
    begin
      Inc(LHazardCount, FHPCount);
      LThread := LThread^.Next;
    end;
    SetLength(LHazards, LHazardCount);
    LHazardIndex := 0;
    LThread := FThreads;
    while LThread <> nil do
    begin
      for LI := 0 to FHPCount - 1 do
      begin
        LHazards[LHazardIndex] := AtomicLoadPtr(LThread^.HP[LI], moAcquire);
        Inc(LHazardIndex);
      end;
      LThread := LThread^.Next;
    end;
  finally
    ReleaseThreads;
  end;

  LList := PHazardRetiredNode(AtomicExchangePtr(Pointer(FRetired), nil, moAcqRel));
  if LList = nil then
    Exit;
  LReclaimCount := 0;
  LPrev := nil;
  LNode := LList;
  while LNode <> nil do
  begin
    LProtected := False;
    if LHazardCount > 0 then
      for LHazardIndex := 0 to LHazardCount - 1 do
      begin
        if LHazards[LHazardIndex] = LNode^.Data then
        begin
          LProtected := True;
          Break;
        end;
      end;
    if LProtected then
    begin
      LPrev := LNode;
      LNode := LNode^.Next;
    end
    else
    begin
      LNext := LNode^.Next;
      if Assigned(LNode^.Reclaim) then
        LNode^.Reclaim(LNode^.Data, LNode^.UserData);
      FreeMem(LNode, SizeOf(THazardRetiredNode));
      Inc(LReclaimCount);
      if LPrev = nil then
        LList := LNext
      else
        LPrev^.Next := LNext;
      LNode := LNext;
    end;
  end;
  if LList <> nil then
  begin
    LNode := LList;
    while LNode^.Next <> nil do
      LNode := LNode^.Next;
    repeat
      LNode^.Next := PHazardRetiredNode(AtomicLoadPtr(Pointer(FRetired), moRelaxed));
    until AtomicCompareExchangePtr(Pointer(FRetired), LNode^.Next, LList, moRelease) = LNode^.Next;
  end;
  AtomicFetchSub32(FGlobalRetiredCount, LReclaimCount, moRelaxed);
end;

function THazardDomain.ActiveThreads: PtrUInt;
var
  LThread: PHazardThreadRec;
begin
  Result := 0;
  AcquireThreads;
  try
    LThread := FThreads;
    while LThread <> nil do
    begin
      Inc(Result);
      LThread := LThread^.Next;
    end;
  finally
    ReleaseThreads;
  end;
end;

function THazardDomain.RetiredCount: PtrUInt; inline;
begin
  Result := PtrUInt(AtomicLoad32(FGlobalRetiredCount, moAcquire));
end;

{ THazardGuard }

class function THazardGuard.Acquire(const ADomain: THazardDomain; const AHPIndex: PtrUInt): THazardGuard;
begin
  Result.FDomain := ADomain;
  Result.FHPIndex := AHPIndex;
  Result.FActive := False;
  if ADomain <> nil then
  begin
    Result.FThreadId := ADomain.RegisterThread;
    Result.FActive := True;
  end
  else
    Result.FThreadId := 0;
end;

function THazardGuard.Protect(const APtr: Pointer): Pointer;
begin
  if FActive and (FDomain <> nil) then
    Result := FDomain.Protect(FThreadId, FHPIndex, APtr)
  else
    Result := APtr;
end;

function THazardGuard.ProtectSource(const ASource: PPointer): Pointer;
begin
  if ASource = nil then
    raise EArgumentError.Create('THazardGuard.ProtectSource: source must not be nil');
  if FActive and (FDomain <> nil) then
    Result := FDomain.ProtectSource(FThreadId, FHPIndex, ASource)
  else
    Result := AtomicLoadPtr(ASource^, moAcquire);
end;

procedure THazardGuard.Release;
begin
  if FActive and (FDomain <> nil) then
  begin
    FDomain.Clear(FThreadId, FHPIndex);
    FDomain.UnregisterThread(FThreadId);
    FActive := False;
  end;
end;

end.
