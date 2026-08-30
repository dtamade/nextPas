unit nextpas.core.mem.pool.fixed;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.mem.base,           // MEM_POISON_FREED
  nextpas.core.mem.pool.base,    // IPool (decoupled from facade)
  nextpas.core.mem.allocator,    // IAllocator + GetRtlAllocator
  nextpas.core.mem.mutex,

  nextpas.core.mem.error;        // EAllocError, TAllocError

// 说明：
// - 固定块内存池（Fixed-size Pool），支持逐块分配/归还
// - 当前版本：
//   * Free(nil) = no-op（统一语义）
//   * Reset 重建自由栈，避免后续分配退化扫描
//   * 释放与分配均为 O(1)（自由栈 + 索引快速定位）
//   * 默认对齐：Alignment = max(SizeOf(Pointer), 16)；BlockSize 必须是 Alignment 的倍数
//   * 线程安全：当前实现不内置并发控制，需要外部同步；或采用后续线程本地/并发变体

type
  {** 固定块池基础异常（继承自 EAllocError）| Fixed pool base exception *}
  EMemFixedPoolError = class(EAllocError);
  {** 无效指针异常 | Invalid pointer exception *}
  EMemFixedPoolInvalidPointer = class(EMemFixedPoolError);
  {** 双重释放异常 | Double free exception *}
  EMemFixedPoolDoubleFree = class(EMemFixedPoolError);

  {** TFixedPool 配置参数 *}
  TFixedPoolConfig = record
    BlockSize: SizeUInt;
    Capacity: Integer;
    Alignment: SizeUInt;    // 新增：对齐（默认 max(pointer,16)）
    ZeroOnAlloc: Boolean;   // 分配后清零（可选，默认 False）
    Allocator: IAllocator;
  end;

  {**
   * TFixedPool
   *
   * @desc
   *   固定块内存池，为相同大小的对象提供 O(1) 分配和释放性能。
   *   Fixed-size memory pool providing O(1) allocation and deallocation for same-sized objects.
   *
   * @usage
   *   适用于频繁分配/释放固定大小对象的场景，如节点池、对象池等。
   *   Ideal for frequent allocation/deallocation of fixed-size objects like node pools, object pools.
   *
   * @features
   *   - O(1) 分配和释放：使用自由栈实现常数时间操作
   *   - 零碎片：预分配固定大小块，无内存碎片
   *   - 双重释放检测：防止同一块被释放两次
   *   - 可配置对齐：支持自定义对齐要求（默认 max(pointer, 16)）
   *   - 可选零初始化：分配时可选择清零内存
   *   - 性能统计：跟踪峰值使用量和分配次数
   *
   * @thread_safety
   *   不是线程安全的。多线程环境请使用 TFixedPoolConcurrent 或外部同步。
   *   Not thread-safe. Use TFixedPoolConcurrent or external synchronization for multi-threaded scenarios.
   *
   * @example
   *   // 创建固定块池（64 字节块，容量 1000）
   *   var Pool: TFixedPool;
   *   Pool := TFixedPool.Create(64, 1000);
   *   try
   *     // 分配块
   *     Ptr := Pool.Alloc;
   *     if Ptr <> nil then
   *     begin
   *       // 使用内存...
   *       Pool.ReleasePtr(Ptr);
   *     end;
   *
   *     // 批量分配
   *     if Pool.TryAlloc(Ptr) then
   *     begin
   *       // 使用内存...
   *       Pool.ReleasePtr(Ptr);
   *     end;
   *
   *     // 重置池（释放所有块）
   *     Pool.Reset;
   *   finally
   *     Pool.Free;
   *   end;
   *
   * @performance
   *   - 分配：O(1) 常数时间
   *   - 释放：O(1) 常数时间
   *   - 重置：O(n) 线性时间（n = 容量）
   *   - 内存开销：每块约 1 字节（自由标志）+ 栈索引
   *
   * @use_cases
   *   - 链表节点池：为链表节点提供快速分配
   *   - 对象池：管理固定大小的对象实例
   *   - 消息队列：为消息缓冲区提供内存池
   *   - 粒子系统：游戏引擎中的粒子对象池
   *
   * @see TFixedPoolConfig, IPool, TFixedPoolConcurrent, TSlabPool
   *}
  TFixedPool = class(TInterfacedObject, IPool)
  private
    FBlockSize: SizeUInt;
    FCapacity: Integer;
    FAllocatedCount: Integer;
    FBuffer: Pointer;            // 对齐后的可用起始地址（Arena 内部）
    FTotalSize: SizeUInt;        // 总大小 = BlockSize * Capacity
    FFreeStack: array of Integer;// 可用块索引栈
    FFreeTop: Integer;           // 栈顶（可用元素个数）
    FIsFree: array of Boolean;   // 双重释放检测
    FAllocator: IAllocator;
    FZeroOnAlloc: Boolean;       // 每次分配是否清零
    // 对齐与原始缓冲
    FAlignment: SizeUInt;        // 实际使用的对齐（默认为 max(pointer,16)）
    FRawBuffer: Pointer;         // 原始分配指针，用于释放
    FRawAllocSize: SizeUInt;     // GetMem 实际字节数（含对齐 over-alloc）
    // 统计
    FPeakAllocated: Integer;
    FTotalAllocCalls: QWord;
    FTotalFreeCalls: QWord;
  private
    // ✅ M-1: 统一参数命名为小写 a 前缀
    procedure PushFreeIndex(aIndex: Integer); inline;
    function PopFreeIndex(out aIndex: Integer): Boolean; inline;
    procedure RebuildFreeStack; inline;
    function GetAvailable: Integer; inline;
  public
    // 构造/析构
    {** 创建固定块池（块大小 aBlockSize，容量 aCapacity，默认对齐和分配器）*}
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAllocator: IAllocator = nil); overload;
    {** 创建固定块池，可指定对齐字节数 aAlignment（0 = 默认 max(pointer,16)）*}
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator = nil); overload;
    {** 使用 TFixedPoolConfig 记录创建池，支持 ZeroOnAlloc 选项 *}
    constructor Create(const aConfig: TFixedPoolConfig); overload;
    {** 释放 arena 内存，DEBUG 下检测泄漏 *}
    destructor Destroy; override;
  public
    // 固定块 API
    {** 从自由栈分配一个块，成功返回指针，耗尽返回 nil *}
    function Alloc: Pointer; inline;
    {** 分配一个块，成功返回 True 并设置 aPtr，否则返回 False *}
    function TryAlloc(out aPtr: Pointer): Boolean; inline;
    {** 归还一个块到自由栈，nil 为 no-op；不合法指针或双重释放抛异常 *}
    procedure ReleasePtr(aPtr: Pointer); inline;
    {** 重建自由栈，所有块标记为空闲，计数器归零 *}
    procedure Reset; inline;
    {** 获取 arena 连续内存范围（起始地址 aBase 和字节大小 aSize）*}
    procedure GetArenaRange(out aBase: Pointer; out aSize: SizeUInt); inline;

    // IPool（统一对外最小接口）
    {** IPool 接口：分配一个块，成功返回 True *}
    function Acquire(out aUnit: Pointer): Boolean; inline;
    {** Acquire 的别名 *}
    function TryAcquire(out aUnit: Pointer): Boolean; inline;
    {** 批量分配至多 aCount 个块，返回实际分配数 *}
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    {** IPool 接口：归还一个块（委托给 ReleasePtr）*}
    procedure Release(aUnit: Pointer); inline;
    {** 批量归还 aCount 个块 *}
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);

    // 辅助：判断指针是否属于本池（不检查对齐与双重释放，仅范围）
    {** 判断 aPtr 是否落在本池 arena 范围内（不做对齐/双重释放检查）*}
    function Owns(aPtr: Pointer): Boolean; inline;

    // 只读属性
    {** 每块字节数（构造时固定）*}
    property BlockSize: SizeUInt read FBlockSize;
    {** 总块数 *}
    property Capacity: Integer read FCapacity;
    {** 当前已分配块数 *}
    property AllocatedCount: Integer read FAllocatedCount;
    {** 实际对齐字节数 *}
    property Alignment: SizeUInt read FAlignment;
    {** 空闲块数 = Capacity - AllocatedCount *}
    property Available: Integer read GetAvailable;
    {** 历史峰值已分配块数 *}
    property PeakAllocated: Integer read FPeakAllocated;
    {** 累计 Alloc 调用次数 *}
    property TotalAllocCalls: QWord read FTotalAllocCalls;
    {** 累计 ReleasePtr 调用次数 *}
    property TotalFreeCalls: QWord read FTotalFreeCalls;
  end;

  {**
   * @desc Thread-safe wrapper for TFixedPool (mutex-protected).
   * @note All Acquire/Release operations are serialized via TMemMutex.
   *}
  TFixedPoolConcurrent = class(TInterfacedObject, IPool)
  private
    {**
     * Lock ordering: Single mutex (FLock). No nesting with other locks.
     * BlockSize, Capacity are immutable (lockless reads).
     * AllocatedCount, Acquire, Release, Reset are under FLock.
     *
     * 锁顺序：单锁（FLock），不与其他锁嵌套。
     * BlockSize/Capacity 不可变（无需加锁）；其余操作在 FLock 下。
     *}
    FInner: TFixedPool;
    FLock: TMemMutex;
    function GetBlockSize: SizeUInt; inline;
    function GetCapacity: Integer; inline;
    function GetAllocatedCount: Integer; inline;
  public
    {** 创建线程安全固定块池（可选对齐和分配器）*}
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt = 0; aAllocator: IAllocator = nil); overload;
    {** 使用 TFixedPoolConfig 创建线程安全固定块池 *}
    constructor Create(const aConfig: TFixedPoolConfig); overload;
    {** 加锁释放内部 TFixedPool *}
    destructor Destroy; override;

    {** 加锁分配一个块，成功返回 True *}
    function Acquire(out aUnit: Pointer): Boolean; inline;
    {** Acquire 的别名 *}
    function TryAcquire(out aUnit: Pointer): Boolean; inline;
    {** 加锁批量分配至多 aCount 个块 *}
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    {** 加锁归还一个块 *}
    procedure Release(aUnit: Pointer); inline;
    {** 加锁批量归还 aCount 个块 *}
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);

    {** 加锁分配一个块，成功返回指针，耗尽返回 nil *}
    function Alloc: Pointer; inline;
    {** 加锁分配一个块，成功返回 True *}
    function TryAlloc(out aPtr: Pointer): Boolean; inline;
    {** 加锁归还一个块 *}
    procedure ReleasePtr(aPtr: Pointer); inline;
    {** 加锁重建自由栈 *}
    procedure Reset; inline;

    {** 每块字节数（无锁读取，不可变）*}
    property BlockSize: SizeUInt read GetBlockSize;
    {** 总块数（无锁读取，不可变）*}
    property Capacity: Integer read GetCapacity;
    {** 当前已分配块数（加锁读取）*}
    property AllocatedCount: Integer read GetAllocatedCount;
  end;

implementation

uses
  nextpas.core.mem;

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in pool internals

{ TFixedPool }

procedure TFixedPool.PushFreeIndex(aIndex: Integer);
begin
  FFreeStack[FFreeTop] := aIndex;
  Inc(FFreeTop);
end;

function TFixedPool.PopFreeIndex(out aIndex: Integer): Boolean;
begin
  if FFreeTop > 0 then
  begin
    Dec(FFreeTop);
    aIndex := FFreeStack[FFreeTop];
    Exit(True);
  end;
  Result := False;
end;

procedure TFixedPool.RebuildFreeStack;
var
  LIndex: Integer;
begin
  FFreeTop := 0;
  for LIndex := 0 to FCapacity - 1 do
  begin
    FIsFree[LIndex] := True;
    PushFreeIndex(LIndex);
  end;
  FAllocatedCount := 0;
end;

function FixedPoolLeakMessage(aAllocatedCount: Integer): string;
var
  LCount: string;
begin
  Str(aAllocatedCount, LCount);
  Result := 'Memory leak: ' + LCount + ' blocks not freed';
end;

constructor TFixedPool.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAllocator: IAllocator);
begin
  Create(aBlockSize, aCapacity, 0{use default}, aAllocator);
end;

constructor TFixedPool.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator);
var
  LRaw: Pointer;
  LMask: SizeUInt;
  LAddr, LAligned: PtrUInt;
begin
  inherited Create;
  if aBlockSize = 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'Block size cannot be zero'));
  if (SizeOf(Pointer) <> 0) and ((aBlockSize mod SizeOf(Pointer)) <> 0) then
    raise EMemFixedPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Block size must be a multiple of pointer size'));
  if aCapacity <= 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'Capacity must be positive'));

  FBlockSize := aBlockSize;
  FCapacity := aCapacity;
  FAllocatedCount := 0;
  FPeakAllocated := 0;
  FTotalAllocCalls := 0;
  FTotalFreeCalls := 0;

  if aAllocator = nil then
    FAllocator := nextpas.core.mem.allocator.GetRtlAllocator
  else
    FAllocator := aAllocator;

  // Alignment: 默认 max(pointer,16)；必须为 2 的幂
  if aAlignment = 0 then
  begin
    // SizeOf(Pointer) is a compile-time constant; on supported targets it's <= 16,
    // so max(SizeOf(Pointer), 16) is always 16. Keep it branch-free to avoid FPC 6018.
    FAlignment := 16;
  end
  else
    FAlignment := aAlignment;
  if (FAlignment and (FAlignment-1)) <> 0 then
    raise EMemFixedPoolError.Create(aeAlignmentNotSupported,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'Alignment must be power of two (' + IntToStr(FAlignment) + ')'));
  if (FBlockSize mod FAlignment) <> 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'Block size must be a multiple of alignment (' + IntToStr(FBlockSize) + ' mod ' + IntToStr(FAlignment) + ' <> 0)'));

  // 计算总大小并检查溢出（乘法前溢出检查，避免除法）
  if (FBlockSize <> 0) and (FBlockSize > High(SizeUInt) div SizeUInt(FCapacity)) then
    raise EMemFixedPoolError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'Total size overflow (' + IntToStr(FBlockSize) + ' * ' + IntToStr(FCapacity) + ')'));
  FTotalSize := FBlockSize * SizeUInt(FCapacity);

  // 分配连续 Arena（对齐）
  // 如果分配器不提供对齐接口，则 over-allocate 并手动对齐
  FRawAllocSize := FTotalSize + (FAlignment - 1);
  LRaw := FAllocator.GetMem(FRawAllocSize);
  if LRaw = nil then
    raise EOutOfMemory.Create(aeOutOfMemory,
      FormatAllocErrorMsg('TFixedPool', 'Create', 'failed to allocate arena buffer (' +
      IntToStr(Int64(FRawAllocSize)) + ' bytes)'));
  FRawBuffer := LRaw;
  try
    LAddr := PtrUInt(LRaw);
    LMask := FAlignment - 1;
    LAligned := (LAddr + LMask) and not LMask;
    FBuffer := Pointer(LAligned);

    SetLength(FFreeStack, FCapacity);
    SetLength(FIsFree, FCapacity);
    FFreeTop := 0;

    RebuildFreeStack;
  except
    // 异常安全：释放已分配的内存
    FreeMemOf(FAllocator, FRawBuffer, FRawAllocSize);
    FRawBuffer := nil;
    FRawAllocSize := 0;
    raise;
  end;
end;

constructor TFixedPool.Create(const aConfig: TFixedPoolConfig);
begin
  Create(aConfig.BlockSize, aConfig.Capacity, aConfig.Alignment, aConfig.Allocator);
  FZeroOnAlloc := aConfig.ZeroOnAlloc;
  if aConfig.ZeroOnAlloc and (FBuffer <> nil) and (FTotalSize > 0) then
    ZeroMem(FBuffer, FTotalSize);
end;

destructor TFixedPool.Destroy;
var
  LLeak: Integer;
begin
  LLeak := FAllocatedCount;
  try
    {$IFDEF DEBUG}
    if LLeak <> 0 then
      raise EMemFixedPoolError.Create(aeInternalError,
        FormatAllocErrorMsg('TFixedPool', 'Destroy', FixedPoolLeakMessage(LLeak)));
    {$ENDIF}
  finally
    if FRawBuffer <> nil then
      try
        FreeMemOf(FAllocator, FRawBuffer, FRawAllocSize);
      except
      end;
    FBuffer := nil;
    FRawBuffer := nil;
    FRawAllocSize := 0;
    SetLength(FFreeStack, 0);
    SetLength(FIsFree, 0);
    inherited Destroy;
  end;
end;



function TFixedPool.Alloc: Pointer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := nil;
  if not PopFreeIndex(LIdx) then Exit(nil);
  // ✅ M-3: 使用 Assert 替代静默返回，因为这是内部一致性检查
  Assert(FIsFree[LIdx], 'TFixedPool.Alloc: Internal error - free stack corruption');
  FIsFree[LIdx] := False;
  Inc(FAllocatedCount);

  LPtr := Pointer(PByte(FBuffer) + SizeUInt(LIdx) * FBlockSize);
  if FZeroOnAlloc and (FBlockSize > 0) then
    ZeroMem(LPtr, FBlockSize);
  if FAllocatedCount > FPeakAllocated then
    FPeakAllocated := FAllocatedCount;
  Inc(FTotalAllocCalls);
  Result := LPtr;
end;

function TFixedPool.TryAlloc(out aPtr: Pointer): Boolean;
begin
  aPtr := Alloc;
  Result := aPtr <> nil;
end;

function TFixedPool.Owns(aPtr: Pointer): Boolean;
begin
  Result := (aPtr <> nil) and (aPtr >= FBuffer) and (aPtr < Pointer(PByte(FBuffer) + FTotalSize));
end;

function TFixedPool.GetAvailable: Integer;
begin
  Result := FCapacity - FAllocatedCount;
end;

procedure TFixedPool.GetArenaRange(out aBase: Pointer; out aSize: SizeUInt);
begin
  aBase := FBuffer;
  aSize := FTotalSize;
end;


procedure TFixedPool.ReleasePtr(aPtr: Pointer);
var
  LDiff, LIdxU: SizeUInt;
  LIdx: Integer;
begin
  if aPtr = nil then Exit; // Free(nil) = no-op
  if (FBuffer = nil) or (FTotalSize = 0) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Pool is not initialized'));

  // 边界检查：必须在 [FBuffer, FBuffer + FTotalSize) 范围内
  if (aPtr < FBuffer) or (aPtr >= Pointer(PByte(FBuffer) + FTotalSize)) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Pointer does not belong to this pool'));

  // 计算与校验对齐
  LDiff := SizeUInt(PByte(aPtr) - PByte(FBuffer));
  if (FBlockSize = 0) or ((LDiff mod FBlockSize) <> 0) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Pointer is not aligned to block size'));

  LIdxU := LDiff div FBlockSize;
  if LIdxU >= SizeUInt(FCapacity) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Pointer index out of range'));

  LIdx := Integer(LIdxU);
  if FIsFree[LIdx] then
    raise EMemFixedPoolDoubleFree.Create(aeDoubleFree,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'Double free detected'));

  {$IFDEF DEBUG}
  try
    FillMem(Pointer(PByte(FBuffer) + SizeUInt(LIdx) * FBlockSize), FBlockSize, MEM_POISON_FREED);
  except
  end;
  {$ENDIF}
  FIsFree[LIdx] := True;
  Dec(FAllocatedCount);
  Inc(FTotalFreeCalls);
  PushFreeIndex(LIdx);
  {$IFDEF DEBUG}
  if FAllocatedCount < 0 then
    raise EMemFixedPoolError.Create(aeInternalError,
      FormatAllocErrorMsg('TFixedPool', 'Release', 'AllocatedCount underflow'));
  {$ENDIF}
end;

procedure TFixedPool.Reset;
begin
  RebuildFreeStack;
end;

function TFixedPool.Acquire(out aUnit: Pointer): Boolean;
begin
  aUnit := Alloc;
  Result := aUnit <> nil;
end;

function TFixedPool.TryAcquire(out aUnit: Pointer): Boolean;
begin
  aUnit := Alloc;
  Result := aUnit <> nil;
end;

function TFixedPool.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
begin
  Result := DefaultAcquireN(@Alloc, aUnits, aCount);
end;

procedure TFixedPool.Release(aUnit: Pointer);
begin
  ReleasePtr(aUnit);
end;

procedure TFixedPool.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
begin
  DefaultReleaseN(@ReleasePtr, aUnits, aCount);
end;

{$POP}

{ TFixedPoolConcurrent }

constructor TFixedPoolConcurrent.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator);
begin
  inherited Create;
  FLock.Init;
  FInner := TFixedPool.Create(aBlockSize, aCapacity, aAlignment, aAllocator);
end;

constructor TFixedPoolConcurrent.Create(const aConfig: TFixedPoolConfig);
begin
  inherited Create;
  FLock.Init;
  FInner := TFixedPool.Create(aConfig);
end;

destructor TFixedPoolConcurrent.Destroy;
begin
  FLock.Acquire;
  try
    FreeAndNil(FInner);
  finally
    FLock.Release;
  end;
  FLock.Done;
  inherited Destroy;
end;

function TFixedPoolConcurrent.Acquire(out aUnit: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.Acquire(aUnit);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.TryAcquire(out aUnit: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAcquire(aUnit);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
begin
  FLock.Acquire;
  try
    Result := FInner.AcquireN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.Release(aUnit: Pointer);
begin
  FLock.Acquire;
  try
    FInner.Release(aUnit);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
begin
  FLock.Acquire;
  try
    FInner.ReleaseN(aUnits, aCount);
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.Alloc: Pointer;
begin
  FLock.Acquire;
  try
    Result := FInner.Alloc;
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.TryAlloc(out aPtr: Pointer): Boolean;
begin
  FLock.Acquire;
  try
    Result := FInner.TryAlloc(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.ReleasePtr(aPtr: Pointer);
begin
  FLock.Acquire;
  try
    FInner.ReleasePtr(aPtr);
  finally
    FLock.Release;
  end;
end;

procedure TFixedPoolConcurrent.Reset;
begin
  FLock.Acquire;
  try
    FInner.Reset;
  finally
    FLock.Release;
  end;
end;

function TFixedPoolConcurrent.GetBlockSize: SizeUInt;
begin
  Result := FInner.BlockSize;
end;

function TFixedPoolConcurrent.GetCapacity: Integer;
begin
  Result := FInner.Capacity;
end;

function TFixedPoolConcurrent.GetAllocatedCount: Integer;
begin
  Result := FInner.AllocatedCount;
end;

end.
