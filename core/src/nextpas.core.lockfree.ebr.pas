unit nextpas.core.lockfree.ebr;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic;

type
  {** @desc EBR 回调类型：回收时调用 }
  TLockFreeReclaimProc = procedure(const AData: Pointer; const AUserData: Pointer);

  PEbrRetiredNode = ^TEbrRetiredNode;
  {** @desc EBR 退休节点 }
  TEbrRetiredNode = record
    Next: PEbrRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;

  {** @desc 保守型内存回收域（Quiescent-State Based Reclamation, QSBR）
    @details **注意：这是 QSBR 变体，不是真正的 EBR（Epoch-Based Reclamation）。**

    **算法特性**:
    - 设计为 "Zero-Active Reclamation"
    - 仅当 FActiveCount=0 时回收所有退休节点
    - 不维护全局 epoch，不做 epoch 推进
    - 依赖临界区极短（纳秒级）的使用场景

    **Per-thread Retire Buffer (Phase 7)**:
    - 使用 pthread_key_create + 析构函数实现线程安全的 per-thread 缓冲区
    - 每个线程维护本地 retire 缓冲区 (16 slots)
    - 缓冲区满时批量 CAS 提交到全局链表
    - 线程退出时析构函数自动 flush 剩余缓冲区
    - 减少 ~94% 的 CAS 操作（16 次 retire → 1 次 CAS）

    **适用场景**:
    - SegQueue 等临界区仅包含几个原子操作的无锁数据结构
    - 生产者-消费者模式，消费者处理极快

    **不适用场景**:
    - 长时间持有引用的读取端（应改用 THazardDomain）
    - 需要精确控制回收时机的场景

    **与真正 EBR 的区别**:
    - 真正 EBR 维护全局 epoch，允许跨 epoch 的引用
    - QSBR 仅检查当前是否有活跃线程，更保守但更简单

    @see THazardDomain 用于读多写少、临界区较长的场景
  }
  TEbrDomain = class
  private
    FRetired: PEbrRetiredNode;
    FActiveCount: Int32;
    FRetiredCount: Int32;
    FFreeList: PEbrRetiredNode;
    FFreeListCount: Int32;
    {** @desc 直接 CAS 提交（TLS 不可用时的 fallback） }
    procedure RetireDirect(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
  public
    constructor Create;
    destructor Destroy; override;
    {** @desc 进入临界区（ActiveCount+1） }
    procedure Enter;
    {** @desc 离开临界区（ActiveCount-1） }
    procedure Leave;
    {** @desc 退休指针；Collect 时若无活跃者则回收 }
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer = nil);
    {** @desc 尝试回收所有退休项（ActiveCount=0 时生效） }
    procedure Collect;
    {** @desc 当前活跃临界区数（O(1) 原子读，无锁）
      @note 与 THazardDomain.ActiveThreads（O(n) 遍历链表）不同，此方法是 O(1) 原子操作。 }
    function ActiveCount: PtrUInt;
    {** @desc 当前退休待回收数 }
    function RetiredCount: PtrUInt;
  end;

  {** @desc QSBR 哨兵守卫（RAII 自动 Leave）
    @details TEbrGuard 是 QSBR 的 RAII 守卫，用于自动管理临界区进入和离开。
  }
  TEbrGuard = record
  private
    FDomain: TEbrDomain;
    FActive: Boolean;
  public
    {** @desc 获取守卫并进入临界区（ADomain=nil 时为 no-op） }
    class function Acquire(const ADomain: TEbrDomain): TEbrGuard; static;
    {** @desc 释放守卫并离开临界区（重复调用安全） }
    procedure Release;
  end;

implementation

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

const
  {** Per-thread retire buffer 大小 }
  EBR_RETIRE_BUFFER_SIZE = 16;

type
  {** Per-thread retire buffer }
  PEbrThreadBuffer = ^TEbrThreadBuffer;
  TEbrThreadBuffer = record
    Domain: TEbrDomain;
    Count: Int32;
    Entries: array[0..EBR_RETIRE_BUFFER_SIZE - 1] of record
      Data: Pointer;
      Reclaim: TLockFreeReclaimProc;
      UserData: Pointer;
    end;
  end;

var
  {** pthread_key for per-thread buffer }
  GEbrTlsKey: pthread_key_t;
  {** 是否已初始化 }
  GEbrTlsInitialized: Boolean = False;
  {** 全局 orphaned 列表：线程退出时 domain 已销毁的 retired nodes }
  GEbrOrphanedRetired: PEbrRetiredNode = nil;

{** @desc pthread 析构函数：线程退出时 flush 到 orphaned 列表（不访问 domain）
  @note 不访问 domain 避免 use-after-free（domain 可能已销毁）。
        orphaned 节点在 Collect/Destroy 中被回收。 }
procedure EbrThreadBufferDestructor(AValue: Pointer); cdecl;
var
  LBuffer: PEbrThreadBuffer;
  LHead, LLast, LNode: PEbrRetiredNode;
  LI: Int32;
begin
  LBuffer := PEbrThreadBuffer(AValue);
  if LBuffer = nil then
    Exit;
  if LBuffer^.Count > 0 then
  begin
    { 构建本地链表（不复用 freelist，避免访问 domain） }
    LHead := nil;
    LLast := nil;
    for LI := LBuffer^.Count - 1 downto 0 do
    begin
      LNode := GetMem(SizeOf(TEbrRetiredNode));
      LNode^.Data := LBuffer^.Entries[LI].Data;
      LNode^.Reclaim := LBuffer^.Entries[LI].Reclaim;
      LNode^.UserData := LBuffer^.Entries[LI].UserData;
      LNode^.Next := LHead;
      LHead := LNode;
      if LLast = nil then
        LLast := LNode;
    end;
    { CAS 到全局 orphaned 列表（而非 domain.FRetired） }
    if LHead <> nil then
    begin
      repeat
        LLast^.Next := PEbrRetiredNode(atomic_load(PPointer(@GEbrOrphanedRetired)^, moRelaxed));
      until atomic_compare_exchange_strong(
          PPointer(@GEbrOrphanedRetired)^, PPointer(@LLast^.Next)^, LHead, moRelease, moRelaxed);
    end;
  end;
  FreeMem(LBuffer);
end;

{** @desc 获取或创建当前线程的 buffer }
function GetThreadBuffer(ADomain: TEbrDomain): PEbrThreadBuffer;
var
  LBuffer: PEbrThreadBuffer;
  LDomain: TEbrDomain;
  LHead, LLast, LNode: PEbrRetiredNode;
  LI: Int32;
begin
  if not GEbrTlsInitialized then
    Exit(nil);
  LBuffer := PEbrThreadBuffer(pthread_getspecific(GEbrTlsKey));
  if LBuffer = nil then
  begin
    LBuffer := GetMem(SizeOf(TEbrThreadBuffer));
    LBuffer^.Domain := ADomain;
    LBuffer^.Count := 0;
    pthread_setspecific(GEbrTlsKey, LBuffer);
  end
  else if LBuffer^.Domain <> ADomain then
  begin
    { domain 变更: flush 旧 domain 的缓冲区（旧 domain 一定还活着） }
    LDomain := LBuffer^.Domain;
    if (LDomain <> nil) and (LBuffer^.Count > 0) then
    begin
      LHead := nil;
      LLast := nil;
      for LI := LBuffer^.Count - 1 downto 0 do
      begin
        if (LDomain.FFreeList <> nil) and (LDomain.FFreeListCount > 0) then
        begin
          LNode := LDomain.FFreeList;
          LDomain.FFreeList := LNode^.Next;
          Dec(LDomain.FFreeListCount);
        end
        else
          LNode := GetMem(SizeOf(TEbrRetiredNode));
        LNode^.Data := LBuffer^.Entries[LI].Data;
        LNode^.Reclaim := LBuffer^.Entries[LI].Reclaim;
        LNode^.UserData := LBuffer^.Entries[LI].UserData;
        LNode^.Next := LHead;
        LHead := LNode;
        if LLast = nil then
          LLast := LNode;
      end;
      if LHead <> nil then
      begin
        repeat
          LLast^.Next := PEbrRetiredNode(atomic_load(PPointer(@LDomain.FRetired)^, moRelaxed));
        until atomic_compare_exchange_strong(
            PPointer(@LDomain.FRetired)^, PPointer(@LLast^.Next)^, LHead, moRelease, moRelaxed);
      end;
    end;
    LBuffer^.Domain := ADomain;
    LBuffer^.Count := 0;
  end;
  Result := LBuffer;
end;

{** @desc Flush 当前线程的缓冲区到全局链表 }
procedure FlushThreadBuffer(ADomain: TEbrDomain);
var
  LBuffer: PEbrThreadBuffer;
  LHead, LLast, LNode: PEbrRetiredNode;
  LI: Int32;
begin
  if not GEbrTlsInitialized then
    Exit;
  LBuffer := PEbrThreadBuffer(pthread_getspecific(GEbrTlsKey));
  if (LBuffer = nil) or (LBuffer^.Count <= 0) then
    Exit;
  { 构建本地链表 }
  LHead := nil;
  LLast := nil;
  for LI := LBuffer^.Count - 1 downto 0 do
  begin
    { Try to reuse from freelist }
    if (ADomain.FFreeList <> nil) and (ADomain.FFreeListCount > 0) then
    begin
      LNode := ADomain.FFreeList;
      ADomain.FFreeList := LNode^.Next;
      Dec(ADomain.FFreeListCount);
    end
    else
      LNode := GetMem(SizeOf(TEbrRetiredNode));
    LNode^.Data := LBuffer^.Entries[LI].Data;
    LNode^.Reclaim := LBuffer^.Entries[LI].Reclaim;
    LNode^.UserData := LBuffer^.Entries[LI].UserData;
    LNode^.Next := LHead;
    LHead := LNode;
    if LLast = nil then
      LLast := LNode;
  end;
  { 批量 CAS: 整条链表一次提交 }
  if LHead <> nil then
  begin
    repeat
      LLast^.Next := PEbrRetiredNode(atomic_load(PPointer(@ADomain.FRetired)^, moRelaxed));
    until atomic_compare_exchange_strong(
        PPointer(@ADomain.FRetired)^, PPointer(@LLast^.Next)^, LHead, moRelease, moRelaxed);
  end;
  LBuffer^.Count := 0;
end;

{ TEbrDomain }

constructor TEbrDomain.Create;
begin
  inherited Create;
  FRetired := nil;
  FActiveCount := 0;
  FRetiredCount := 0;
  FFreeList := nil;
  FFreeListCount := 0;
end;

destructor TEbrDomain.Destroy;
var
  LNode, LNext: PEbrRetiredNode;
begin
  { Flush 当前线程的缓冲区 }
  FlushThreadBuffer(Self);
  { 回收 orphaned 节点（线程退出时 domain 已销毁的遗留节点） }
  LNode := PEbrRetiredNode(atomic_exchange(PPointer(@GEbrOrphanedRetired)^, nil, moAcqRel));
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
  LNode := PEbrRetiredNode(atomic_exchange(PPointer(@FRetired)^, nil, moAcqRel));
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
  LNode := FFreeList;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    FreeMem(LNode);
    LNode := LNext;
  end;
  inherited;
end;

procedure TEbrDomain.Enter;
begin
  AtomicFetchAdd32(FActiveCount, 1, moAcquire);
end;

procedure TEbrDomain.Leave;
begin
  AtomicFetchSub32(FActiveCount, 1, moRelease);
end;

procedure TEbrDomain.Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LBuffer: PEbrThreadBuffer;
begin
  if AData = nil then
    Exit;
  { 尝试使用 per-thread buffer }
  LBuffer := GetThreadBuffer(Self);
  if LBuffer <> nil then
  begin
    LBuffer^.Entries[LBuffer^.Count].Data := AData;
    LBuffer^.Entries[LBuffer^.Count].Reclaim := AReclaim;
    LBuffer^.Entries[LBuffer^.Count].UserData := AUserData;
    Inc(LBuffer^.Count);
    AtomicFetchAdd32(FRetiredCount, 1, moRelaxed);
    if LBuffer^.Count >= EBR_RETIRE_BUFFER_SIZE then
      FlushThreadBuffer(Self);
    Exit;
  end;
  { Fallback: 直接 CAS (TLS 不可用) }
  RetireDirect(AData, AReclaim, AUserData);
end;

procedure TEbrDomain.RetireDirect(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LNode: PEbrRetiredNode;
begin
  { Try to reuse from freelist }
  if (FFreeList <> nil) and (FFreeListCount > 0) then
  begin
    LNode := FFreeList;
    FFreeList := LNode^.Next;
    Dec(FFreeListCount);
  end
  else
    LNode := GetMem(SizeOf(TEbrRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  repeat
    LNode^.Next := PEbrRetiredNode(atomic_load(PPointer(@FRetired)^, moRelaxed));
  until atomic_compare_exchange_strong(PPointer(@FRetired)^, PPointer(@LNode^.Next)^, LNode, moRelease, moRelaxed);
  AtomicFetchAdd32(FRetiredCount, 1, moRelaxed);
end;

procedure TEbrDomain.Collect;
var
  LList: PEbrRetiredNode;
  LNode, LNext: PEbrRetiredNode;
begin
  { 先 flush 当前线程的缓冲区 }
  FlushThreadBuffer(Self);
  { 回收 orphaned 节点（线程退出时 domain 已销毁的遗留节点） }
  LList := PEbrRetiredNode(atomic_exchange(PPointer(@GEbrOrphanedRetired)^, nil, moAcqRel));
  LNode := LList;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
  if AtomicLoad32(FActiveCount, moAcquire) <> 0 then
    Exit;
  LList := PEbrRetiredNode(atomic_exchange(PPointer(@FRetired)^, nil, moAcqRel));
  if LList = nil then
    Exit;
  { 二次检查：atomic_exchange(moAcqRel) 与 Enter 的 AtomicFetchAdd32(moAcquire)
    建立 happens-before 链。若 exchange 后 FActiveCount <> 0，说明有新 reader
    在 exchange 前已 Enter，此时不能释放，需归还列表。 }
  if AtomicLoad32(FActiveCount, moAcquire) <> 0 then
  begin
    LNode := LList;
    while LNode^.Next <> nil do
      LNode := LNode^.Next;
    repeat
      LNext := PEbrRetiredNode(atomic_load(PPointer(@FRetired)^, moRelaxed));
      LNode^.Next := LNext;
    until atomic_compare_exchange_weak(
        PPointer(@FRetired)^, PPointer(@LNode^.Next)^, LList, moRelease, moRelaxed);
    Exit;
  end;
  LNode := LList;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    { Add to freelist for reuse }
    if FFreeListCount < 32 then
    begin
      LNode^.Next := FFreeList;
      FFreeList := LNode;
      Inc(FFreeListCount);
    end
    else
      FreeMem(LNode);
    LNode := LNext;
  end;
  AtomicStore32(FRetiredCount, 0, moRelease);
end;

function TEbrDomain.ActiveCount: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad32(FActiveCount, moRelaxed));
end;

function TEbrDomain.RetiredCount: PtrUInt;
begin
  Result := AtomicLoad32(FRetiredCount, moRelaxed);
end;

class function TEbrGuard.Acquire(const ADomain: TEbrDomain): TEbrGuard;
begin
  Result.FDomain := ADomain;
  Result.FActive := False;
  if ADomain <> nil then
  begin
    ADomain.Enter;
    Result.FActive := True;
  end;
end;

procedure TEbrGuard.Release;
begin
  if FActive and (FDomain <> nil) then
  begin
    FDomain.Leave;
    FActive := False;
  end;
end;

{ 初始化 pthread_key }
procedure InitEbrTls;
begin
  if GEbrTlsInitialized then
    Exit;
  if pthread_key_create(@GEbrTlsKey, @EbrThreadBufferDestructor) = 0 then
    GEbrTlsInitialized := True;
end;

{** @desc 释放 orphaned 节点 }
procedure EbrFreeOrphanedNodes;
var
  LNode, LNext: PEbrRetiredNode;
begin
  LNode := PEbrRetiredNode(atomic_exchange(PPointer(@GEbrOrphanedRetired)^, nil, moAcqRel));
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
end;

initialization
  InitEbrTls;

finalization
  { Flush 主线程的 buffer }
  if GEbrTlsInitialized then
  begin
    EbrThreadBufferDestructor(pthread_getspecific(GEbrTlsKey));
    pthread_setspecific(GEbrTlsKey, nil);
    pthread_key_delete(GEbrTlsKey);
  end;
  { 释放 orphaned 节点 }
  EbrFreeOrphanedNodes;

end.
