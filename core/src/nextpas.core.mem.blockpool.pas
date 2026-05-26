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

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.blockpool;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

const
  {** IBlockPool 接口 GUID *}
  GUID_IBLOCKPOOL = '{B8F4E0A2-3C5D-4F9B-AE60-7D8C9B0F1234}';

  {** IBlockPoolBatch 接口 GUID *}
  GUID_IBLOCKPOOLBATCH = '{8E8C21F5-0F8B-4A85-AF16-0E10B3C0A1B2}';

  {** IArena 接口 GUID *}
  GUID_IARENA = '{C905F1B3-4D6E-5A0C-BF78-8E9D0C102345}';

  {** 默认对齐 *}
  DEFAULT_ALIGNMENT = 16;

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
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer; // returns acquired count
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
  end;

  {**
   * TArenaMarker
   *
   * @desc Arena 位置标记
   *}
  TArenaMarker = type SizeUInt;

  {**
   * IArena
   *
   * @desc 线性分配器接口
   *       Arena/bump allocator interface
   *}
  IArena = interface
    [GUID_IARENA]
    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    function SaveMark: TArenaMarker;
    procedure RestoreToMark(aMark: TArenaMarker);
    procedure Reset;
    function TotalSize: SizeUInt;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
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
    FTotalSize: SizeUInt;        // 总大小（字节）= BlockSize * Capacity
    FFreeHead: Pointer;          // 空闲链表头（intrusive free-list）
    FFreeBits: array of QWord;   // 释放位图：1=free, 0=allocated
    FAllocCount: SizeUInt;       // 已分配数量
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
    constructor Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    { 核心 API - 全部 inline }
    function Acquire: Pointer; inline;
    function TryAcquire(out aPtr: Pointer): Boolean; inline;
    procedure Release(aPtr: Pointer); inline;
    procedure Reset; inline;

    { 快速 API - 无检查版本 }
    function AcquireUnchecked: Pointer; inline;
    procedure ReleaseUnchecked(aPtr: Pointer); inline;

    { IBlockPool }
    function BlockSize: SizeUInt; inline;
    function Capacity: SizeUInt; inline;
    function Available: SizeUInt; inline;
    function InUse: SizeUInt; inline;

    { IBlockPoolBatch }
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    { 辅助 }
    function Owns(aPtr: Pointer): Boolean; inline;
    procedure GetRange(out aBase: Pointer; out aSize: SizeUInt); inline;

    { 统计 }
    property PeakAlloc: SizeUInt read FPeakAlloc;
    property TotalAllocs: QWord read FTotalAllocs;
    property TotalFrees: QWord read FTotalFrees;
    property Alignment: SizeUInt read FAlignment;
  end;

  {**
   * TArena
   *
   * @desc 高性能线性分配器
   *       High-performance arena/bump allocator
   *
   * @design
   *   - O(1) 分配（bump pointer）
   *   - 支持批量释放（SaveMark/RestoreToMark）
   *   - 所有热路径 inline
   *
   * @performance
   *   - Alloc: ~2ns (inline, 单次指针加法)
   *   - AllocFast: ~1ns (无检查版本)
   *   - Reset: O(1)
   *}
  TArena = class(TInterfacedObject, IArena)
  private
    FRawMemory: Pointer;          // 原始分配指针（释放用）
    FMemory: PByte;              // 内存起始
    FCurrent: PByte;             // 当前位置
    FEnd: PByte;                 // 内存结束
    FTotalSize: SizeUInt;        // 总大小
    FAlignment: SizeUInt;        // Arena 基址对齐
    // 统计
    FPeakUsed: SizeUInt;         // 峰值使用
    FTotalAllocs: QWord;         // 总分配次数
  public
    constructor Create(aTotalSize: SizeUInt);
    destructor Destroy; override;

    { 核心 API - 全部 inline }
    function Alloc(const aLayout: TMemLayout): TAllocResult; inline;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult; inline;
    function SaveMark: TArenaMarker; inline;
    procedure RestoreToMark(aMark: TArenaMarker); inline;
    procedure Reset; inline;

    { 快速 API - 无检查版本，极致性能 }
    function AllocFast(aSize: SizeUInt): Pointer; inline;
    function AllocAlignedFast(aSize, aAlign: SizeUInt): Pointer; inline;

    { IArena }
    function TotalSize: SizeUInt; inline;
    function UsedSize: SizeUInt; inline;
    function RemainingSize: SizeUInt; inline;

    { 统计 }
    property PeakUsed: SizeUInt read FPeakUsed;
    property TotalAllocCount: QWord read FTotalAllocs;
  end;

  { 向后兼容的基类（已废弃，仅用于接口兼容） }
  TBlockPoolBase = class(TInterfacedObject, IBlockPool)
  protected
    FBlockSize: SizeUInt;
    FCapacity: SizeUInt;
  public
    constructor Create(aBlockSize, aCapacity: SizeUInt); virtual;
    function Acquire: Pointer; virtual; abstract;
    function TryAcquire(out aPtr: Pointer): Boolean; virtual; abstract;
    procedure Release(aPtr: Pointer); virtual; abstract;
    procedure Reset; virtual; abstract;
    function BlockSize: SizeUInt; virtual;
    function Capacity: SizeUInt; virtual;
    function Available: SizeUInt; virtual; abstract;
    function InUse: SizeUInt; virtual;
  end;

  TArenaBase = class(TInterfacedObject, IArena)
  protected
    FTotalSize: SizeUInt;
  public
    constructor Create(aTotalSize: SizeUInt); virtual;
    function Alloc(const aLayout: TMemLayout): TAllocResult; virtual; abstract;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult; virtual;
    function SaveMark: TArenaMarker; virtual; abstract;
    procedure RestoreToMark(aMark: TArenaMarker); virtual; abstract;
    procedure Reset; virtual; abstract;
    function TotalSize: SizeUInt; virtual;
    function UsedSize: SizeUInt; virtual; abstract;
    function RemainingSize: SizeUInt; virtual;
  end;

implementation

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
    FillChar(FFreeBits[0], SizeUInt(LBitLen) * SizeOf(QWord), $FF);

  if (FBuffer = nil) or (FCapacity = 0) then
    Exit;

  // 建立 intrusive free-list：block0 -> block1 -> ... -> nil
  LPtr := PByte(FBuffer);
  FFreeHead := LPtr;
  for I := 0 to FCapacity - 2 do
  begin
    PPointer(LPtr)^ := Pointer(LPtr + FBlockSize);
    Inc(LPtr, FBlockSize);
  end;
  PPointer(LPtr)^ := nil;
end;

constructor TBlockPool.Create(aBlockSize, aCapacity: SizeUInt; aAlignment: SizeUInt);
var
  LActualBlockSize: SizeUInt;
  LTotalSize: SizeUInt;
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
  LAlign: SizeUInt;
  LShift: SizeUInt;
  LTmp: SizeUInt;
begin
  inherited Create;

  // 参数验证
  if aBlockSize = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPool: block size must be > 0');
  if aCapacity = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPool: capacity must be > 0');
  if aCapacity > SizeUInt(High(SizeInt)) then
    raise EAllocError.Create(aeInvalidLayout, 'TBlockPool: capacity too large');

  LAlign := aAlignment;
  if LAlign = 0 then
    LAlign := DEFAULT_ALIGNMENT
  else
  begin
    if (LAlign and (LAlign - 1)) <> 0 then
      raise EAllocError.Create(aeAlignmentNotSupported, 'TBlockPool: alignment must be power of 2');
    if LAlign < MEM_DEFAULT_ALIGN then
      LAlign := MEM_DEFAULT_ALIGN;
  end;

  // 块大小必须至少为对齐大小
  if aBlockSize < LAlign then
    LActualBlockSize := LAlign
  else
  begin
    LMask := LAlign - 1;
    if aBlockSize > (High(SizeUInt) - LMask) then
      raise EAllocError.Create(aeInvalidLayout, 'TBlockPool: block size overflow');
    LActualBlockSize := (aBlockSize + LMask) and not LMask;
  end;

  FBlockSize := LActualBlockSize;
  // 预计算 power-of-two 快路径（Release/Acquire 可用 shift/mask 代替 div/mod）
  if IsPowerOfTwo(FBlockSize) then
  begin
    FBlockMask := FBlockSize - 1;
    LShift := 0;
    LTmp := FBlockSize;
    while LTmp > 1 do
    begin
      Inc(LShift);
      LTmp := LTmp shr 1;
    end;
    FBlockShift := LShift;
  end
  else
  begin
    FBlockMask := 0;
    FBlockShift := 0;
  end;

  FCapacity := aCapacity;
  FAlignment := LAlign;
  FAllocCount := 0;
  FPeakAlloc := 0;
  FTotalAllocs := 0;
  FTotalFrees := 0;

  // 计算总大小并检查溢出
  LTotalSize := LActualBlockSize * aCapacity;
  if (LActualBlockSize <> 0) and ((LTotalSize div LActualBlockSize) <> aCapacity) then
    raise EAllocError.Create(aeOutOfMemory, 'TBlockPool: total size overflow');
  FTotalSize := LTotalSize;

  // 分配内存（over-allocate 用于对齐）
  // 额外字节数最大为 (Alignment - 1)，保证对齐后仍有 TotalSize 可用空间
  LAllocSize := LTotalSize + (FAlignment - 1);
  if LAllocSize < LTotalSize then
    raise EAllocError.Create(aeOutOfMemory, 'TBlockPool: allocation size overflow');
  GetMem(LRaw, LAllocSize);
  if LRaw = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TBlockPool: failed to allocate memory');

  FRawBuffer := LRaw;

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
    FreeMem(FRawBuffer);
  FBuffer := nil;
  FRawBuffer := nil;
  FFreeHead := nil;
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
  Result := LPtr;
end;

function TBlockPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  aPtr := Acquire;
  Result := aPtr <> nil;
end;

function TBlockPool.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then Exit(0);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    LPtr := Acquire;
    if LPtr = nil then
      Break;
    aPtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TBlockPool.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  if aCount <= 0 then Exit;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    Release(aPtrs[LIdx]);
  end;
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
    raise EAllocError.Create(aeInvalidPointer, 'TBlockPool.Release: pointer not owned');

  // 计算索引
  LDiff := PtrUInt(aPtr) - PtrUInt(FBuffer);
  if FBlockMask <> 0 then
  begin
    if (LDiff and PtrUInt(FBlockMask)) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, 'TBlockPool.Release: misaligned pointer');
    LIdx := SizeUInt(LDiff shr FBlockShift);
  end
  else
  begin
    if (LDiff mod FBlockSize) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, 'TBlockPool.Release: misaligned pointer');
    LIdx := SizeUInt(LDiff div FBlockSize);
  end;

  // 双重释放检测
  if IsFreeBitSet(LIdx) then
    raise EAllocError.Create(aeDoubleFree, 'TBlockPool.Release: double free detected');

  {$IFDEF FAF_MEM_DEBUG}
  // 污化已释放内存，提升 UAF 暴露率
  FillChar((PByte(FBuffer) + LIdx * FBlockSize)^, FBlockSize, $A5);
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

{ ============================================================================ }
{ TArena }
{ ============================================================================ }

constructor TArena.Create(aTotalSize: SizeUInt);
var
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
begin
  inherited Create;

  if aTotalSize = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TArena: size must be > 0');

  FTotalSize := aTotalSize;
  FAlignment := DEFAULT_ALIGNMENT;
  FPeakUsed := 0;
  FTotalAllocs := 0;

  // 分配并对齐 Arena 基址，保证至少有 TotalSize 可用空间
  LAllocSize := aTotalSize + (FAlignment - 1);
  if LAllocSize < aTotalSize then
    raise EAllocError.Create(aeOutOfMemory, 'TArena: allocation size overflow');

  GetMem(LRaw, LAllocSize);
  if LRaw = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TArena: failed to allocate memory');

  FRawMemory := LRaw;
  LAddr := PtrUInt(LRaw);
  LMask := FAlignment - 1;
  LAligned := (LAddr + LMask) and not LMask;
  FMemory := PByte(LAligned);

  FCurrent := FMemory;
  FEnd := FMemory + aTotalSize;
end;

destructor TArena.Destroy;
begin
  if FRawMemory <> nil then
    FreeMem(FRawMemory);
  FRawMemory := nil;
  FMemory := nil;
  FCurrent := nil;
  FEnd := nil;
  inherited Destroy;
end;

function TArena.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LAlign: SizeUInt;
  LMask: SizeUInt;
  LCurU: PtrUInt;
  LAlignedU: PtrUInt;
  LAlignedOffset: SizeUInt;
  LNewUsed: SizeUInt;
  LPtr: PByte;
begin
  // 快速路径：零大小
  if aLayout.Size = 0 then
  begin
    Result := TAllocResult.Ok(nil);
    Exit;
  end;

  if not aLayout.IsValid then
    Exit(TAllocResult.Err(aeInvalidLayout));

  LAlign := aLayout.Align;
  if LAlign = 0 then
    Exit(TAllocResult.Err(aeInvalidLayout));

  // 对齐当前指针（按绝对地址对齐，支持任意 power-of-two 对齐）
  if LAlign <= 1 then
    LPtr := FCurrent
  else
  begin
    LMask := LAlign - 1;
    LCurU := PtrUInt(FCurrent);
    if PtrUInt(LMask) > (High(PtrUInt) - LCurU) then
      Exit(TAllocResult.Err(aeInvalidLayout));
    LAlignedU := (LCurU + PtrUInt(LMask)) and not PtrUInt(LMask);
    LPtr := PByte(LAlignedU);
  end;

  LAlignedOffset := SizeUInt(PtrUInt(LPtr) - PtrUInt(FMemory));

  // 边界检查
  if (LAlignedOffset > FTotalSize) or (aLayout.Size > (FTotalSize - LAlignedOffset)) then
  begin
    Result := TAllocResult.Err(aeOutOfMemory);
    Exit;
  end;

  LNewUsed := LAlignedOffset + aLayout.Size;
  FCurrent := FMemory + LNewUsed;
  Inc(FTotalAllocs);

  // 更新峰值
  if LNewUsed > FPeakUsed then
    FPeakUsed := LNewUsed;

  Result := TAllocResult.Ok(LPtr);
end;

function TArena.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

function TArena.AllocFast(aSize: SizeUInt): Pointer;
var
  LUsed: SizeUInt;
begin
  if aSize = 0 then
    Exit(nil);
  Result := FCurrent;
  {$IFDEF DEBUG}
  Assert((PtrUInt(FEnd) - PtrUInt(FCurrent)) >= aSize, 'TArena.AllocFast: out of memory');
  {$ENDIF}
  Inc(FCurrent, aSize);
  Inc(FTotalAllocs);
  LUsed := SizeUInt(PtrUInt(FCurrent) - PtrUInt(FMemory));
  if LUsed > FPeakUsed then
    FPeakUsed := LUsed;
end;

function TArena.AllocAlignedFast(aSize, aAlign: SizeUInt): Pointer;
var
  LMask: SizeUInt;
  LUsed: SizeUInt;
begin
  if aSize = 0 then
    Exit(nil);
  if aAlign = 0 then
    aAlign := MEM_DEFAULT_ALIGN;
  if not IsPowerOfTwo(aAlign) then
    aAlign := NextPowerOfTwo(aAlign);

  LMask := aAlign - 1;
  {$IFDEF DEBUG}
  Assert(LMask <= (High(PtrUInt) - PtrUInt(FCurrent)), 'TArena.AllocAlignedFast: pointer overflow');
  {$ENDIF}
  FCurrent := PByte((PtrUInt(FCurrent) + LMask) and not LMask);
  Result := FCurrent;
  {$IFDEF DEBUG}
  Assert((PtrUInt(FEnd) - PtrUInt(FCurrent)) >= aSize, 'TArena.AllocAlignedFast: out of memory');
  {$ENDIF}
  Inc(FCurrent, aSize);
  Inc(FTotalAllocs);
  LUsed := SizeUInt(PtrUInt(FCurrent) - PtrUInt(FMemory));
  if LUsed > FPeakUsed then
    FPeakUsed := LUsed;
end;

function TArena.SaveMark: TArenaMarker;
begin
  Result := TArenaMarker(PtrUInt(FCurrent) - PtrUInt(FMemory));
end;

procedure TArena.RestoreToMark(aMark: TArenaMarker);
var
  LTarget: PByte;
begin
  if SizeUInt(aMark) > FTotalSize then
    raise EAllocError.Create(aeInvalidLayout, 'TArena.RestoreToMark: marker out of range');
  LTarget := FMemory + SizeUInt(aMark);

  FCurrent := LTarget;
end;

procedure TArena.Reset;
begin
  FCurrent := FMemory;
end;

function TArena.TotalSize: SizeUInt;
begin
  Result := FTotalSize;
end;

function TArena.UsedSize: SizeUInt;
begin
  Result := PtrUInt(FCurrent) - PtrUInt(FMemory);
end;

function TArena.RemainingSize: SizeUInt;
begin
  Result := PtrUInt(FEnd) - PtrUInt(FCurrent);
end;

{ ============================================================================ }
{ TBlockPoolBase (向后兼容) }
{ ============================================================================ }

constructor TBlockPoolBase.Create(aBlockSize, aCapacity: SizeUInt);
begin
  inherited Create;
  FBlockSize := aBlockSize;
  FCapacity := aCapacity;
end;

function TBlockPoolBase.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TBlockPoolBase.Capacity: SizeUInt;
begin
  Result := FCapacity;
end;

function TBlockPoolBase.InUse: SizeUInt;
begin
  Result := FCapacity - Available;
end;

{ ============================================================================ }
{ TArenaBase (向后兼容) }
{ ============================================================================ }

constructor TArenaBase.Create(aTotalSize: SizeUInt);
begin
  inherited Create;
  FTotalSize := aTotalSize;
end;

function TArenaBase.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

function TArenaBase.TotalSize: SizeUInt;
begin
  Result := FTotalSize;
end;

function TArenaBase.RemainingSize: SizeUInt;
begin
  Result := FTotalSize - UsedSize;
end;

{$POP}

end.
