{
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

# nextpas.core.mem.blockpool - 高性能内存池
## Abstract 摘要

High-performance memory pool implementations.
高性能内存池实现。

## Design 设计

- O(1) 分配/释放（空闲栈）
- 所有热路径 inline
- 双重释放检测
- 缓存友好的内存布局

## Declaration 声明

Author:    nextpas.core
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.blockpool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.pool.base,
  nextpas.core.base.utils,

  nextpas.core.mem.error;

const
  {** IBlockPool 接口 GUID *}
  GUID_IBLOCKPOOL = '{B8F4E0A2-3C5D-4F9B-AE60-7D8C9B0F1234}';

  {** IBlockPoolBatch 接口 GUID *}
  GUID_IBLOCKPOOLBATCH = '{8E8C21F5-0F8B-4A85-AF16-0E10B3C0A1B2}';

type
  {**
   * IBlockPool
   *
   * @desc 固定大小块池接口
   *       Fixed-size block pool interface
   *}
  IBlockPool = interface
    [GUID_IBLOCKPOOL]
    function Acquire: Pointer;
    function TryAcquire(out aPtr: Pointer): Boolean;
    procedure Release(aPtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;
  end;

  {**
   * IBlockPoolBatch
   *
   * @desc 批量分配/释放扩展接口（可选）
   *}
  IBlockPoolBatch = interface(IBlockPool)
    [GUID_IBLOCKPOOLBATCH]
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer; // returns acquired count
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);
  end;

  {**
   * TBlockPool
   *
   * @desc 高性能固定块池
   *       High-performance fixed block pool
   *
   * @design
   *   - O(1) 分配/释放（空闲栈）
   *   - 双重释放检测
   *   - 所有热路径 inline
   *   - 统计信息支持
   *
   * @performance
   *   - Acquire: ~3ns (inline, 无分支预测失败)
   *   - Release: ~5ns (含双重释放检测)
   *   - Reset: O(n) 但只在需要时调用
   *}
  TBlockPool = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    FBlockSize: SizeUInt;        // 块大小
    FBlockShift: SizeUInt;       // log2(BlockSize) if power-of-two, else 0
    FBlockMask: SizeUInt;        // BlockSize - 1 if power-of-two, else 0
    FCapacity: SizeUInt;         // 容量
    FAlignment: SizeUInt;        // 对齐
    FBuffer: Pointer;            // 对齐后的缓冲区
    FRawBuffer: Pointer;         // 原始缓冲区（用于释放）
    FRawAllocSize: SizeUInt;     // GetMem 实际字节数（含对齐 over-alloc）
    FTotalSize: SizeUInt;        // 总大小（字节）= BlockSize * Capacity
    FFreeHead: Pointer;          // 空闲链表头（intrusive free-list）
    FFreeBits: array of QWord;   // 释放位图：1=free, 0=allocated
    FAllocCount: SizeUInt;       // 已分配数量
    FAllocator: IAllocator;      // 可选：自定义分配器（nil = 使用系统 GetMem）
    // 统计
    FPeakAlloc: SizeUInt;        // 峰值分配
    FTotalAllocs: QWord;         // 总分配次数
    FTotalFrees: QWord;          // 总释放次数
  private
    function IsFreeBitSet(aIdx: SizeUInt): Boolean; inline;
    procedure SetFreeBit(aIdx: SizeUInt); inline;
    procedure ClearFreeBit(aIdx: SizeUInt); inline;
    procedure PushFree(aPtr: Pointer); inline;
    function PopFree: Pointer; inline;
    procedure RebuildFreeList;
  public
    {**
     * @desc 创建固定块池，预分配整块内存并初始化空闲链表
     *
     * @params
     *   aBlockSize   每个块的最小字节数（会向上对齐到 aAlignment）
     *   aCapacity    块数量
     *   aAlignment   对齐要求，默认 DEFAULT_ALIGNMENT
     *
     * @note aBlockSize 必须 > 0，aCapacity 必须 > 0
     *       2 的幂次块大小启用 shift/mask 快路径
     *}
    constructor Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt = DEFAULT_ALIGNMENT;
      aAllocator: IAllocator = nil);

    {** @desc 释放底层缓冲区，销毁池实例 *}
    destructor Destroy; override;

    { 核心 API - 全部 inline }

    {**
     * @desc 从池中获取一个块，池耗尽时返回 nil
     * @return 已分配的块指针，或 nil
     *}
    function Acquire: Pointer; inline;

    {**
     * @desc 尝试获取一个块，池耗尽时返回 False
     *
     * @params
     *   aPtr  输出参数，获取到的块指针
     *
     * @return 是否成功获取
     *}
    function TryAcquire(out aPtr: Pointer): Boolean; inline;

    {**
     * @desc 归还一个块到池中，含范围检查和双重释放检测
     *
     * @params
     *   aPtr  要归还的块指针，传 nil 则静默忽略
     *
     * @note 指针不属于本池或已释放时抛出 EAllocError
     *}
    procedure Release(aPtr: Pointer); inline;

    {** @desc 重置池，将所有块恢复为空闲状态 *}
    procedure Reset; inline;

    { 快速 API - 无检查版本 }

    {**
     * @desc 获取一个块（无 nil 检查），池耗尽时行为未定义
     * @return 已分配的块指针
     * @note DEBUG 模式下池耗尽会触发 Assert
     *}
    function AcquireUnchecked: Pointer; inline;

    {**
     * @desc 归还一个块（无范围/对齐检查）
     *
     * @params
     *   aPtr  要归还的块指针
     *
     * @note DEBUG 模式下有断言保护，Release 模式无检查
     *}
    procedure ReleaseUnchecked(aPtr: Pointer); inline;

    { IBlockPool }

    {** @return 每个块的实际字节大小（已对齐） *}
    function BlockSize: SizeUInt; inline;
    {** @return 池中块的总数量 *}
    function Capacity: SizeUInt; inline;
    {** @return 当前可用（空闲）块数量 *}
    function Available: SizeUInt; inline;
    {** @return 当前已分配（在用）块数量 *}
    function InUse: SizeUInt; inline;

    { IBlockPoolBatch }

    {**
     * @desc 批量获取多个块
     *
     * @params
     *   APtrs   输出数组，接收获取到的块指针
     *   ACount  期望获取的数量
     *
     * @return 实际获取的数量（可能少于 ACount）
     *}
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;

    {**
     * @desc 批量归还多个块
     *
     * @params
     *   APtrs   要归还的块指针数组
     *   ACount  数组中有效指针的数量
     *}
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);

    { 辅助 }

    {**
     * @desc 判断指针是否属于本池的内存范围
     * @return True 表示指针在池的缓冲区内
     *}
    function Owns(aPtr: Pointer): Boolean; inline;

    {**
     * @desc 获取池底层缓冲区的基地址和总大小
     *
     * @params
     *   aBase  输出缓冲区基地址
     *   aSize  输出缓冲区总字节大小
     *}
    procedure GetRange(out aBase: Pointer; out aSize: SizeUInt); inline;

    { 统计 }
    {** @return 历史峰值同时分配的块数量 *}
    property PeakAlloc: SizeUInt read FPeakAlloc;
    {** @return 累计分配（Acquire）总次数 *}
    property TotalAllocs: QWord read FTotalAllocs;
    {** @return 累计释放（Release）总次数 *}
    property TotalFrees: QWord read FTotalFrees;
    {** @return 池的实际对齐字节数 *}
    property Alignment: SizeUInt read FAlignment;
  end;


implementation

uses
  nextpas.core.mem;

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in pool internals

{ ============================================================================ }
{ TBlockPool }
{ ============================================================================ }

function TBlockPool.IsFreeBitSet(aIdx: SizeUInt): Boolean;
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aIdx shr 6;
  LMask := QWord(1) shl (aIdx and 63);
  Result := (FFreeBits[LWordIndex] and LMask) <> 0;
end;

procedure TBlockPool.SetFreeBit(aIdx: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aIdx shr 6;
  LMask := QWord(1) shl (aIdx and 63);
  FFreeBits[LWordIndex] := FFreeBits[LWordIndex] or LMask;
end;

procedure TBlockPool.ClearFreeBit(aIdx: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aIdx shr 6;
  LMask := QWord(1) shl (aIdx and 63);
  FFreeBits[LWordIndex] := FFreeBits[LWordIndex] and (not LMask);
end;

procedure TBlockPool.PushFree(aPtr: Pointer);
begin
  PPointer(aPtr)^ := FFreeHead;
  FFreeHead := aPtr;
end;

function TBlockPool.PopFree: Pointer;
begin
  Result := FFreeHead;
  if Result = nil then
    Exit(nil);
  FFreeHead := PPointer(Result)^;
end;

procedure TBlockPool.RebuildFreeList;
var
  I: SizeUInt;
  LPtr: PByte;
  LBitLen: SizeInt;
begin
  FAllocCount := 0;
  FFreeHead := nil;

  LBitLen := Length(FFreeBits);
  if LBitLen > 0 then
    FillMem(@FFreeBits[0], SizeUInt(LBitLen) * SizeOf(QWord), $FF);

  if (FBuffer = nil) or (FCapacity = 0) then
    Exit;

  // 建立 intrusive free-list：block0 -> block1 -> ... -> nil
  LPtr := PByte(FBuffer);
  FFreeHead := LPtr;
  if FCapacity > 1 then
    for I := 0 to FCapacity - 2 do
    begin
      PPointer(LPtr)^ := Pointer(LPtr + FBlockSize);
      Inc(LPtr, FBlockSize);
    end;
  PPointer(LPtr)^ := nil;
end;

constructor TBlockPool.Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt;
  aAllocator: IAllocator);
var
  LActualBlockSize: SizeUInt;
  LTotalSize: SizeUInt;
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
  LAlign: SizeUInt;
begin
  inherited Create;

  // 参数验证
  if aBlockSize = 0 then
    raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'block size must be > 0'));
  if aCapacity = 0 then
    raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'capacity must be > 0'));
  if aCapacity > SizeUInt(High(SizeInt)) then
    raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'capacity too large (' + IntToStr(aCapacity) + ')'));

  LAlign := SanitizeConfigAlignment(aAlignment);

  // 块大小必须至少为对齐大小
  if aBlockSize < LAlign then
    LActualBlockSize := LAlign
  else
  begin
    LMask := LAlign - 1;
    if aBlockSize > (High(SizeUInt) - LMask) then
      raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'block size overflow (' + IntToStr(aBlockSize) + ')'));
    LActualBlockSize := (aBlockSize + LMask) and not LMask;
  end;

  FBlockSize := LActualBlockSize;
  // 预计算 power-of-two 快路径（Release/Acquire 可用 shift/mask 代替 div/mod）
  if IsPowerOfTwo(FBlockSize) then
  begin
    FBlockMask := FBlockSize - 1;
    FBlockShift := Log2UInt(FBlockSize);
  end
  else
  begin
    FBlockMask := 0;
    FBlockShift := 0;
  end;

  FCapacity := aCapacity;
  FAlignment := LAlign;
  FAllocator := aAllocator;
  FAllocCount := 0;
  FPeakAlloc := 0;
  FTotalAllocs := 0;
  FTotalFrees := 0;

  // 计算总大小并检查溢出
  LTotalSize := LActualBlockSize * aCapacity;
  if (LActualBlockSize <> 0) and ((LTotalSize div LActualBlockSize) <> aCapacity) then
    raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'total size overflow (' + IntToStr(LActualBlockSize) + ' * ' + IntToStr(aCapacity) + ')'));
  FTotalSize := LTotalSize;

  // 分配内存（over-allocate 用于对齐）
  // 额外字节数最大为 (Alignment - 1)，保证对齐后仍有 TotalSize 可用空间
  LAllocSize := LTotalSize + (FAlignment - 1);
  if LAllocSize < LTotalSize then
    raise EOutOfMemory.Create(aeOutOfMemory,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'allocation size overflow (total=' + IntToStr(Int64(LTotalSize)) + ', align=' + IntToStr(Int64(FAlignment)) + ')'));
  if FAllocator <> nil then
    LRaw := FAllocator.GetMem(LAllocSize)
  else
    LRaw := GetMem(LAllocSize); { process GetMem after uses nextpas.core.mem }
  if LRaw = nil then
    raise EOutOfMemory.Create(aeOutOfMemory,
      FormatAllocErrorMsg('TBlockPool', 'Create', 'failed to allocate memory (requested ' + IntToStr(Int64(LAllocSize)) + ' bytes)'));

  FRawBuffer := LRaw;
  FRawAllocSize := LAllocSize;

  // 对齐
  LAddr := PtrUInt(LRaw);
  LMask := FAlignment - 1;
  LAligned := (LAddr + LMask) and not LMask;
  FBuffer := Pointer(LAligned);

  // 初始化 free-list + 释放位图
  SetLength(FFreeBits, SizeInt((aCapacity + 63) shr 6));
  FFreeHead := nil;
  RebuildFreeList;
end;

destructor TBlockPool.Destroy;
begin
  if FRawBuffer <> nil then
  begin
    if FAllocator <> nil then
      FreeMemOf(FAllocator, FRawBuffer, FRawAllocSize)
    else
      FreeMem(FRawBuffer, FRawAllocSize);
  end;
  FBuffer := nil;
  FRawBuffer := nil;
  FRawAllocSize := 0;
  FFreeHead := nil;
  FAllocator := nil;
  SetLength(FFreeBits, 0);
  inherited Destroy;
end;

function TBlockPool.Acquire: Pointer;
var
  LPtr: Pointer;
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  LPtr := PopFree;
  if LPtr = nil then
    Exit(nil);

  LDiff := PtrUInt(LPtr) - PtrUInt(FBuffer);
  if FBlockMask <> 0 then
    LIdx := SizeUInt(LDiff shr FBlockShift)
  else
    LIdx := SizeUInt(LDiff div FBlockSize);
  {$IFDEF DEBUG}
  Assert(IsFreeBitSet(LIdx), 'TBlockPool.Acquire: internal corruption');
  {$ENDIF}
  ClearFreeBit(LIdx);
  Inc(FAllocCount);
  Inc(FTotalAllocs);

  if FAllocCount > FPeakAlloc then
    FPeakAlloc := FAllocCount;

  Result := LPtr;
end;

function TBlockPool.AcquireUnchecked: Pointer;
var
  LPtr: Pointer;
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  {$IFDEF DEBUG}
  Assert(FFreeHead <> nil, 'TBlockPool.AcquireUnchecked: pool exhausted');
  {$ENDIF}
  LPtr := FFreeHead;
  FFreeHead := PPointer(LPtr)^;

  LDiff := PtrUInt(LPtr) - PtrUInt(FBuffer);
  if FBlockMask <> 0 then
    LIdx := SizeUInt(LDiff shr FBlockShift)
  else
    LIdx := SizeUInt(LDiff div FBlockSize);
  {$IFDEF DEBUG}
  Assert(IsFreeBitSet(LIdx), 'TBlockPool.AcquireUnchecked: internal corruption');
  {$ENDIF}
  ClearFreeBit(LIdx);
  Inc(FAllocCount);
  Inc(FTotalAllocs);
  if FAllocCount > FPeakAlloc then
    FPeakAlloc := FAllocCount;
  Result := LPtr;
end;

function TBlockPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  aPtr := Acquire;
  Result := aPtr <> nil;
end;

function TBlockPool.AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
begin
  Result := DefaultAcquireN(@Acquire, APtrs, ACount);
end;

procedure TBlockPool.ReleaseN(const APtrs: array of Pointer; ACount: Integer);
begin
  DefaultReleaseN(@Release, APtrs, ACount);
end;

procedure TBlockPool.Release(aPtr: Pointer);
var
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  if aPtr = nil then
    Exit;

  // 范围检查
  if not Owns(aPtr) then
    raise EAllocError.Create(aeInvalidPointer, FormatAllocErrorMsg('TBlockPool', 'Release', 'pointer not owned'));

  // 计算索引
  LDiff := PtrUInt(aPtr) - PtrUInt(FBuffer);
  if FBlockMask <> 0 then
  begin
    if (LDiff and PtrUInt(FBlockMask)) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, FormatAllocErrorMsg('TBlockPool', 'Release', 'misaligned pointer'));
    LIdx := SizeUInt(LDiff shr FBlockShift);
  end
  else
  begin
    if (LDiff mod FBlockSize) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, FormatAllocErrorMsg('TBlockPool', 'Release', 'misaligned pointer'));
    LIdx := SizeUInt(LDiff div FBlockSize);
  end;

  // 双重释放检测
  if IsFreeBitSet(LIdx) then
    raise EAllocError.Create(aeDoubleFree, FormatAllocErrorMsg('TBlockPool', 'Release', 'double free detected'));

  {$IFDEF DEBUG}
  // Poison freed memory to expose use-after-free
  FillMem((PByte(FBuffer) + LIdx * FBlockSize), FBlockSize, MEM_POISON_FREED);
  {$ENDIF}

  SetFreeBit(LIdx);
  {$IFDEF DEBUG}
  Assert(FAllocCount > 0, 'TBlockPool.Release: internal corruption (alloc count underflow)');
  {$ENDIF}
  Dec(FAllocCount);
  Inc(FTotalFrees);
  PushFree(aPtr);
end;

procedure TBlockPool.ReleaseUnchecked(aPtr: Pointer);
var
  LIdx: SizeUInt;
  LDiff: PtrUInt;
begin
  {$IFDEF DEBUG}
  Assert(Owns(aPtr), 'TBlockPool.ReleaseUnchecked: pointer not owned');
  {$ENDIF}
  LDiff := PtrUInt(aPtr) - PtrUInt(FBuffer);
  if FBlockMask <> 0 then
    LIdx := SizeUInt(LDiff shr FBlockShift)
  else
    LIdx := SizeUInt(LDiff div FBlockSize);
  {$IFDEF DEBUG}
  Assert(not IsFreeBitSet(LIdx), 'TBlockPool.ReleaseUnchecked: double free');
  Assert(FAllocCount > 0, 'TBlockPool.ReleaseUnchecked: alloc count underflow');
  {$ENDIF}
  SetFreeBit(LIdx);
  Dec(FAllocCount);
  PushFree(aPtr);
end;

procedure TBlockPool.Reset;
begin
  RebuildFreeList;
end;

function TBlockPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TBlockPool.Capacity: SizeUInt;
begin
  Result := FCapacity;
end;

function TBlockPool.Available: SizeUInt;
begin
  Result := FCapacity - FAllocCount;
end;

function TBlockPool.InUse: SizeUInt;
begin
  Result := FAllocCount;
end;

function TBlockPool.Owns(aPtr: Pointer): Boolean;
var
  LPtrU: PtrUInt;
  LBaseU: PtrUInt;
begin
  if (aPtr = nil) or (FBuffer = nil) or (FTotalSize = 0) then
    Exit(False);
  LPtrU := PtrUInt(aPtr);
  LBaseU := PtrUInt(FBuffer);
  if LPtrU < LBaseU then
    Exit(False);
  Result := (LPtrU - LBaseU) < PtrUInt(FTotalSize);
end;

procedure TBlockPool.GetRange(out aBase: Pointer; out aSize: SizeUInt);
begin
  aBase := FBuffer;
  aSize := FTotalSize;
end;

{$POP}

end.
