unit nextpas.core.mem.pool.fixed;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.pool.base,    // IPool (decoupled from facade)
  nextpas.core.mem.allocator,    // IAllocator + GetRtlAllocator
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
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAllocator: IAllocator = nil); overload;
    constructor Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator = nil); overload;
    constructor Create(const aConfig: TFixedPoolConfig); overload;
    destructor Destroy; override;
  public
    // 固定块 API
    function Alloc: Pointer; inline;
    function TryAlloc(out aPtr: Pointer): Boolean; inline;
    procedure ReleasePtr(aPtr: Pointer); inline;
    procedure Reset; inline;
    procedure GetArenaRange(out aBase: Pointer; out aSize: SizeUInt); inline;

    // IPool（统一对外最小接口）
    function Acquire(out aUnit: Pointer): Boolean; inline;
    function TryAcquire(out aUnit: Pointer): Boolean; inline; // alias
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(aUnit: Pointer); inline;
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);

    // 辅助：判断指针是否属于本池（不检查对齐与双重释放，仅范围）
    function Owns(aPtr: Pointer): Boolean; inline;

    // 只读属性
    property BlockSize: SizeUInt read FBlockSize;
    property Capacity: Integer read FCapacity;
    property AllocatedCount: Integer read FAllocatedCount;
    property Alignment: SizeUInt read FAlignment;
    property Available: Integer read GetAvailable;
    property PeakAllocated: Integer read FPeakAllocated;
    property TotalAllocCalls: QWord read FTotalAllocCalls;
    property TotalFreeCalls: QWord read FTotalFreeCalls;
  end;

implementation

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

constructor TFixedPool.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAllocator: IAllocator);
begin
  Create(aBlockSize, aCapacity, 0{use default}, aAllocator);
end;

constructor TFixedPool.Create(aBlockSize: SizeUInt; aCapacity: Integer; aAlignment: SizeUInt; aAllocator: IAllocator);
var
  LOverflowCheck: SizeUInt;
  LRaw: Pointer;
  LMask: SizeUInt;
  LAddr, LAligned: PtrUInt;
begin
  inherited Create;
  if aBlockSize = 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout, 'Block size cannot be zero');
  if (SizeOf(Pointer) <> 0) and ((aBlockSize mod SizeOf(Pointer)) <> 0) then
    raise EMemFixedPoolError.Create(aeInvalidLayout, 'Block size must be a multiple of pointer size');
  if aCapacity <= 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout, 'Capacity must be positive');

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
    raise EMemFixedPoolError.Create(aeAlignmentNotSupported, 'Alignment must be power of two');
  if (FBlockSize mod FAlignment) <> 0 then
    raise EMemFixedPoolError.Create(aeInvalidLayout, 'Block size must be a multiple of alignment');

  // 计算总大小并检查溢出
  FTotalSize := FBlockSize * SizeUInt(FCapacity);
  if (FBlockSize <> 0) then
  begin
    LOverflowCheck := FTotalSize div FBlockSize;
    if LOverflowCheck <> SizeUInt(FCapacity) then
      raise EMemFixedPoolError.Create(aeOutOfMemory, 'Total size overflow');
  end;

  // 分配连续 Arena（对齐）
  // 如果分配器不提供对齐接口，则 over-allocate 并手动对齐
  LRaw := FAllocator.GetMem(FTotalSize + (FAlignment - 1));
  if LRaw = nil then
    raise EMemFixedPoolError.Create(aeOutOfMemory, 'Failed to allocate arena buffer');
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
    FAllocator.FreeMem(FRawBuffer);
    FRawBuffer := nil;
    raise;
  end;
end;

constructor TFixedPool.Create(const aConfig: TFixedPoolConfig);
begin
  Create(aConfig.BlockSize, aConfig.Capacity, aConfig.Alignment, aConfig.Allocator);
  FZeroOnAlloc := aConfig.ZeroOnAlloc;
  if aConfig.ZeroOnAlloc and (FBuffer <> nil) and (FTotalSize > 0) then
    FillChar(FBuffer^, FTotalSize, 0);
end;

destructor TFixedPool.Destroy;
begin
  {$IFDEF FAF_MEM_DEBUG}
  if FAllocatedCount <> 0 then
    raise EMemFixedPoolError.Create(aeInternalError, Format('Memory leak: %d blocks not freed', [FAllocatedCount]));
  {$ENDIF}
  // ✅ C-3: 移除死代码分支，FRawBuffer 总是被赋值
  if FRawBuffer <> nil then
    FAllocator.FreeMem(FRawBuffer);
  FBuffer := nil;
  FRawBuffer := nil;
  SetLength(FFreeStack, 0);
  SetLength(FIsFree, 0);
  inherited Destroy;
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
    FillChar(LPtr^, FBlockSize, 0);
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
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pool is not initialized');

  // 边界检查：必须在 [FBuffer, FBuffer + FTotalSize) 范围内
  if (aPtr < FBuffer) or (aPtr >= Pointer(PByte(FBuffer) + FTotalSize)) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer does not belong to this pool');

  // 计算与校验对齐
  LDiff := SizeUInt(PByte(aPtr) - PByte(FBuffer));
  if (FBlockSize = 0) or ((LDiff mod FBlockSize) <> 0) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer is not aligned to block size');

  LIdxU := LDiff div FBlockSize;
  if LIdxU >= SizeUInt(FCapacity) then
    raise EMemFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer index out of range');

  LIdx := Integer(LIdxU);
  if FIsFree[LIdx] then
    raise EMemFixedPoolDoubleFree.Create(aeDoubleFree, 'Double free detected');

  {$IFDEF FAF_MEM_DEBUG}
  // 污化已释放内存，提升 UAF 暴露率
  FillChar(PByte(FBuffer)[SizeUInt(LIdx)*FBlockSize], FBlockSize, $A5);
  {$ENDIF}
  FIsFree[LIdx] := True;
  Dec(FAllocatedCount);
  Inc(FTotalFreeCalls);
  PushFreeIndex(LIdx);
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
var
  LIndex: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  for LIndex := 0 to aCount-1 do
  begin
    LPtr := Alloc;
    if LPtr = nil then Exit;
    aUnits[LIndex] := LPtr;
    Inc(Result);
  end;
end;

procedure TFixedPool.Release(aUnit: Pointer);
begin
  ReleasePtr(aUnit);
end;

procedure TFixedPool.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to aCount-1 do
    ReleasePtr(aUnits[LIndex]);
end;

{$POP}

end.
