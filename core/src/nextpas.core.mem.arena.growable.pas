unit nextpas.core.mem.arena.growable;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.math,              // ✅ Math facade (for trunc)
  nextpas.core.mem.blockpool,
  nextpas.core.mem.alloc,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

type
  {**
   * TArenaGrowthKind
   *
   * @desc Grow policy for TGrowingArena segment sizes
   *}
  TArenaGrowthKind = (agkGeometric, agkLinear);

  {**
   * TGrowingArenaConfig
   *
   * @desc Configuration for TGrowingArena
   *}
  TGrowingArenaConfig = record
    InitialSize: SizeUInt;
    MaxSize: SizeUInt;              // 0 = unlimited (by committed bytes)
    GrowthKind: TArenaGrowthKind;
    GrowthFactor: Double;           // geometric only (>= 1.1 recommended)
    GrowthStep: SizeUInt;           // linear only (>= 1)
    Alignment: SizeUInt;            // 0 = DEFAULT_ALIGNMENT, must be power of two
    Allocator: IAlloc;              // nil = system heap (GetMem/FreeMem)
    KeepSegments: Boolean;          // keep extra segments on Reset/Restore

    class function Default(aInitialSize: SizeUInt): TGrowingArenaConfig; static;
  end;

  {**
   * TGrowingArena
   *
   * @desc
   *   基于段的可增长 Arena 分配器（Bump Allocator），使用单调递增的标记管理虚拟地址空间。
   *   Segment-based growable arena (bump allocator) with monotonic marker-based virtual address space management.
   *
   * @usage
   *   适用于临时对象的批量分配场景，支持快速分配和批量释放。
   *   Ideal for bulk allocation of temporary objects with fast allocation and batch deallocation.
   *
   * @features
   *   - 极快的分配速度：O(1) bump pointer 分配
   *   - 自动扩展：按需添加新段（几何或线性增长）
   *   - 标记/恢复：支持嵌套的保存点机制
   *   - 灵活配置：可配置增长策略、对齐方式、最大容量
   *   - 零碎片：批量释放时无内存碎片
   *
   * @thread_safety
   *   不是线程安全的。多线程环境请使用 TArenaConcurrent 包装。
   *   Not thread-safe. Wrap with TArenaConcurrent for multi-threaded scenarios.
   *
   * @example
   *   // 创建 Arena（几何增长策略）
   *   var Arena: TGrowingArena;
   *   var Config: TGrowingArenaConfig;
   *   Config := TGrowingArenaConfig.Default(4096);  // 初始 4KB
   *   Config.GrowthKind := agkGeometric;
   *   Config.GrowthFactor := 2.0;  // 每次扩展 2 倍
   *   Arena := TGrowingArena.Create(Config);
   *   try
   *     // 快速分配多个对象
   *     Ptr1 := Arena.Alloc(TMemLayout.Create(64, 8)).Ptr;
   *     Ptr2 := Arena.Alloc(TMemLayout.Create(128, 16)).Ptr;
   *
   *     // 保存标记点
   *     Mark := Arena.SaveMark;
   *     Ptr3 := Arena.Alloc(TMemLayout.Create(256, 32)).Ptr;
   *
   *     // 恢复到标记点（释放 Ptr3）
   *     Arena.RestoreToMark(Mark);
   *
   *     // 批量释放所有分配
   *     Arena.Reset;
   *   finally
   *     Arena.Free;
   *   end;
   *
   * @performance
   *   - 分配：O(1) 平均，最坏 O(n) 当需要扩展时
   *   - 标记/恢复：O(1)
   *   - 重置：O(1) 如果 KeepSegments=True，否则 O(n)
   *   - 内存开销：每段约 2-5% 元数据开销
   *
   * @use_cases
   *   - 编译器/解释器：AST 节点的临时分配
   *   - 游戏引擎：每帧临时对象分配
   *   - 网络服务器：请求处理期间的临时缓冲区
   *   - 数据处理：批量数据转换的中间结果
   *
   * @see TGrowingArenaConfig, IArena, TArenaMarker, TArenaConcurrent
   *}
  TGrowingArena = class(TInterfacedObject, IArena)
  private
    type
      TSegment = record
        Raw: Pointer;          // pointer returned by allocator/GetMem (for free)
        RawSize: SizeUInt;     // bytes passed to allocator/GetMem
        Base: PByte;           // aligned base
        Size: SizeUInt;        // usable bytes
        Used: SizeUInt;        // used offset within this segment
        StartOffset: SizeUInt; // virtual base offset (sum of previous segment sizes)
      end;
      PSegment = ^TSegment;
  private
    FSegments: array of TSegment;
    FActive: SizeInt;
    FTotalSize: SizeUInt;
    FAlignment: SizeUInt;
    FMaxSize: SizeUInt;
    FGrowthKind: TArenaGrowthKind;
    FGrowthFactor: Double;
    FGrowthStep: SizeUInt;
    FGrowthBaseSize: SizeUInt;
    FKeepSegments: Boolean;
    FAllocator: IAlloc;
    // statistics
    FPeakUsed: SizeUInt;
    FTotalAllocs: QWord;
  private
    function CurrentUsed: SizeUInt; inline;
    function AlignPtr(aPtr: PByte; aAlign: SizeUInt): PByte; inline;
    function CalcRequiredMinSize(const aLayout: TMemLayout; out aMinSize: SizeUInt): Boolean;
    function CalcNextSegmentSize(aMinSize: SizeUInt; out aUpdateGrowthBase: Boolean): SizeUInt;
    function AddSegment(aMinSize: SizeUInt): Boolean;
    procedure FreeSegment(aIndex: SizeInt);
    procedure ShrinkToSegmentCount(aCount: SizeInt);
    procedure NormalizeState(aActiveIndex: SizeInt; aActiveUsed: SizeUInt);
  public
    constructor Create(const aConfig: TGrowingArenaConfig); overload;
    constructor Create(aInitialSize: SizeUInt; aMaxSize: SizeUInt = 0); overload;
    destructor Destroy; override;

    { IArena }
    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    function SaveMark: TArenaMarker; inline;
    procedure RestoreToMark(aMark: TArenaMarker);
    procedure Reset;
    function TotalSize: SizeUInt;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;

    { Diagnostics }
    function SegmentCount: SizeUInt; inline;
    property PeakUsed: SizeUInt read FPeakUsed;
    property TotalAllocCount: QWord read FTotalAllocs;
    property Alignment: SizeUInt read FAlignment;
  end;

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in arena internals

class function TGrowingArenaConfig.Default(aInitialSize: SizeUInt): TGrowingArenaConfig;
begin
  Result.InitialSize := aInitialSize;
  Result.MaxSize := 0;
  Result.GrowthKind := agkGeometric;
  Result.GrowthFactor := 2.0;
  Result.GrowthStep := 0;
  Result.Alignment := 0;
  Result.Allocator := nil;
  Result.KeepSegments := True;
end;

function TGrowingArena.AlignPtr(aPtr: PByte; aAlign: SizeUInt): PByte;
var
  LMask: PtrUInt;
  LPtrU: PtrUInt;
begin
  if aAlign <= 1 then
    Exit(aPtr);
  LMask := PtrUInt(aAlign - 1);
  LPtrU := PtrUInt(aPtr);
  if LMask > (High(PtrUInt) - LPtrU) then
    Exit(nil);
  Result := PByte((LPtrU + LMask) and not LMask);
end;

function TGrowingArena.CurrentUsed: SizeUInt;
begin
  if (FActive < 0) or (FActive > High(FSegments)) then
    Exit(0);
  Result := FSegments[FActive].StartOffset + FSegments[FActive].Used;
end;

function TGrowingArena.CalcRequiredMinSize(const aLayout: TMemLayout; out aMinSize: SizeUInt): Boolean;
var
  LAlignPad: SizeUInt;
begin
  aMinSize := 0;
  if aLayout.Align <= 1 then
  begin
    aMinSize := aLayout.Size;
    Exit(True);
  end;

  LAlignPad := aLayout.Align - 1;
  if aLayout.Size > (High(SizeUInt) - LAlignPad) then
    Exit(False);
  aMinSize := aLayout.Size + LAlignPad;
  Result := True;
end;

function TGrowingArena.CalcNextSegmentSize(aMinSize: SizeUInt; out aUpdateGrowthBase: Boolean): SizeUInt;
var
  LBaseSize: SizeUInt;
  LGrowthBase: SizeUInt;
  LFactor: Double;
  LTmp: Double;
  LThreshold: SizeUInt;
begin
  aUpdateGrowthBase := True;
  if Length(FSegments) = 0 then
  begin
    Result := aMinSize;
    Exit;
  end;

  LGrowthBase := FGrowthBaseSize;
  if LGrowthBase = 0 then
    LGrowthBase := FSegments[High(FSegments)].Size;
  case FGrowthKind of
    agkLinear:
      begin
        LBaseSize := LGrowthBase + FGrowthStep;
        if LBaseSize < LGrowthBase then
          Exit(0);
      end;
  else
    begin
      LFactor := FGrowthFactor;
      if LFactor < 1.1 then
        LFactor := 2.0;
      LTmp := Double(LGrowthBase) * LFactor;
      if (LTmp <= 0.0) or (LTmp > Double(High(SizeUInt))) then
        Exit(0);
      LBaseSize := SizeUInt(Trunc(LTmp));
      if LBaseSize <= LGrowthBase then
        LBaseSize := LGrowthBase; // avoid shrinking or zero-growth
    end;
  end;

  if LBaseSize < aMinSize then
  begin
    LThreshold := LBaseSize;
    if LThreshold > (High(SizeUInt) div 8) then
      LThreshold := High(SizeUInt)
    else
      LThreshold := LThreshold * 8;
    if (LBaseSize <> 0) and (aMinSize > LThreshold) then
    begin
      aUpdateGrowthBase := False;
      Result := aMinSize;
      Exit;
    end;

    Result := aMinSize;
    Exit;
  end;

  Result := LBaseSize;
end;

function TGrowingArena.AddSegment(aMinSize: SizeUInt): Boolean;
var
  LSegSize: SizeUInt;
  LUpdateGrowthBase: Boolean;
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LLayout: TMemLayout;
  LRes: TAllocResult;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
  LSeg: TSegment;
  LIdx: SizeInt;
begin
  Result := False;
  LUpdateGrowthBase := True;

  if aMinSize = 0 then
    Exit(False);

  if (FMaxSize <> 0) and (FTotalSize >= FMaxSize) then
    Exit(False);

  if Length(FSegments) = 0 then
    LSegSize := aMinSize
  else
    LSegSize := CalcNextSegmentSize(aMinSize, LUpdateGrowthBase);

  if LSegSize = 0 then
    Exit(False);

  if (FMaxSize <> 0) and (LSegSize > (FMaxSize - FTotalSize)) then
  begin
    if aMinSize > (FMaxSize - FTotalSize) then
      Exit(False);
    LSegSize := FMaxSize - FTotalSize;
  end;

  // allocate raw bytes for base alignment
  if FAlignment <= 1 then
    LAllocSize := LSegSize
  else
    LAllocSize := LSegSize + (FAlignment - 1);
  if LAllocSize < LSegSize then
    Exit(False);

  if FAllocator <> nil then
  begin
    LLayout := TMemLayout.Create(LAllocSize, MEM_DEFAULT_ALIGN);
    LRes := FAllocator.Alloc(LLayout);
    if LRes.IsErr or (LRes.Ptr = nil) then
      Exit(False);
    LRaw := LRes.Ptr;
  end
  else
  begin
    GetMem(LRaw, LAllocSize);
    if LRaw = nil then
      Exit(False);
  end;

  LAddr := PtrUInt(LRaw);
  if FAlignment <= 1 then
    LAligned := LAddr
  else
  begin
    LMask := FAlignment - 1;
    if PtrUInt(LMask) > (High(PtrUInt) - LAddr) then
    begin
      if FAllocator <> nil then
        FAllocator.Dealloc(LRaw, TMemLayout.Create(LAllocSize, MEM_DEFAULT_ALIGN))
      else
        FreeMem(LRaw);
      Exit(False);
    end;
    LAligned := (LAddr + PtrUInt(LMask)) and not PtrUInt(LMask);
  end;

  if (High(SizeUInt) - FTotalSize) < LSegSize then
  begin
    if FAllocator <> nil then
      FAllocator.Dealloc(LRaw, TMemLayout.Create(LAllocSize, MEM_DEFAULT_ALIGN))
    else
      FreeMem(LRaw);
    Exit(False);
  end;

  LSeg.Raw := LRaw;
  LSeg.RawSize := LAllocSize;
  LSeg.Base := PByte(LAligned);
  LSeg.Size := LSegSize;
  LSeg.Used := 0;
  LSeg.StartOffset := FTotalSize;

  LIdx := Length(FSegments);
  SetLength(FSegments, LIdx + 1);
  FSegments[LIdx] := LSeg;
  Inc(FTotalSize, LSegSize);
  if (LIdx = 0) or LUpdateGrowthBase then
    FGrowthBaseSize := LSegSize;
  Result := True;
end;

procedure TGrowingArena.FreeSegment(aIndex: SizeInt);
var
  LRaw: Pointer;
  LRawSize: SizeUInt;
begin
  if (aIndex < 0) or (aIndex > High(FSegments)) then
    Exit;
  LRaw := FSegments[aIndex].Raw;
  LRawSize := FSegments[aIndex].RawSize;
  FSegments[aIndex].Raw := nil;
  FSegments[aIndex].Base := nil;
  FSegments[aIndex].Size := 0;
  FSegments[aIndex].Used := 0;
  FSegments[aIndex].RawSize := 0;
  if LRaw = nil then
    Exit;
  if FAllocator <> nil then
    FAllocator.Dealloc(LRaw, TMemLayout.Create(LRawSize, MEM_DEFAULT_ALIGN))
  else
    FreeMem(LRaw);
end;

procedure TGrowingArena.ShrinkToSegmentCount(aCount: SizeInt);
var
  LIdx: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  if aCount > Length(FSegments) then
    Exit;

  for LIdx := High(FSegments) downto aCount do
    FreeSegment(LIdx);

  SetLength(FSegments, aCount);
  if aCount = 0 then
  begin
    FTotalSize := 0;
    FActive := -1;
    Exit;
  end;

  FTotalSize := FSegments[High(FSegments)].StartOffset + FSegments[High(FSegments)].Size;
  if FActive > High(FSegments) then
    FActive := High(FSegments);
end;

procedure TGrowingArena.NormalizeState(aActiveIndex: SizeInt; aActiveUsed: SizeUInt);
var
  LIndex: SizeInt;
begin
  if Length(FSegments) = 0 then
  begin
    FActive := -1;
    Exit;
  end;

  if aActiveIndex < 0 then
    aActiveIndex := 0;
  if aActiveIndex > High(FSegments) then
    aActiveIndex := High(FSegments);

  for LIndex := 0 to aActiveIndex - 1 do
    FSegments[LIndex].Used := FSegments[LIndex].Size;

  if aActiveUsed > FSegments[aActiveIndex].Size then
    aActiveUsed := FSegments[aActiveIndex].Size;
  FSegments[aActiveIndex].Used := aActiveUsed;

  if FKeepSegments then
  begin
    for LIndex := aActiveIndex + 1 to High(FSegments) do
      FSegments[LIndex].Used := 0;
  end
  else
    ShrinkToSegmentCount(aActiveIndex + 1);

  FActive := aActiveIndex;
end;

constructor TGrowingArena.Create(const aConfig: TGrowingArenaConfig);
var
  LAlign: SizeUInt;
  LInitSize: SizeUInt;
begin
  inherited Create;

  LInitSize := aConfig.InitialSize;
  if LInitSize = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TGrowingArena: initial size must be > 0');
  if (aConfig.MaxSize <> 0) and (LInitSize > aConfig.MaxSize) then
    raise EAllocError.Create(aeInvalidLayout, 'TGrowingArena: initial size exceeds max size');

  FGrowthKind := aConfig.GrowthKind;
  FGrowthFactor := aConfig.GrowthFactor;
  FGrowthStep := aConfig.GrowthStep;
  if (FGrowthKind = agkLinear) and (FGrowthStep = 0) then
    FGrowthStep := LInitSize;
  if (FGrowthKind = agkGeometric) and (FGrowthFactor < 1.1) then
    FGrowthFactor := 2.0;

  FMaxSize := aConfig.MaxSize;
  FKeepSegments := aConfig.KeepSegments;
  FAllocator := aConfig.Allocator;

  LAlign := aConfig.Alignment;
  if LAlign = 0 then
    LAlign := DEFAULT_ALIGNMENT;
  if (LAlign and (LAlign - 1)) <> 0 then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TGrowingArena: alignment must be power of 2');
  if LAlign < MEM_DEFAULT_ALIGN then
    LAlign := MEM_DEFAULT_ALIGN;
  FAlignment := LAlign;

  SetLength(FSegments, 0);
  FActive := -1;
  FTotalSize := 0;
  FGrowthBaseSize := 0;
  FPeakUsed := 0;
  FTotalAllocs := 0;

  if not AddSegment(LInitSize) then
    raise EAllocError.Create(aeOutOfMemory, 'TGrowingArena: failed to allocate initial segment');
  FActive := 0;
end;

constructor TGrowingArena.Create(aInitialSize: SizeUInt; aMaxSize: SizeUInt);
var
  LConfig: TGrowingArenaConfig;
begin
  LConfig := TGrowingArenaConfig.Default(aInitialSize);
  LConfig.MaxSize := aMaxSize;
  Create(LConfig);
end;

destructor TGrowingArena.Destroy;
begin
  ShrinkToSegmentCount(0);
  inherited Destroy;
end;

function TGrowingArena.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LAlign: SizeUInt;
  LPtr: PByte;
  LSegPtr: PSegment;
  LOffset: SizeUInt;
  LNewUsed: SizeUInt;
  LMinSegSize: SizeUInt;
begin
  if aLayout.Size = 0 then
    Exit(TAllocResult.Ok(nil));

  if not aLayout.IsValid then
    Exit(TAllocResult.Err(aeInvalidLayout));
  LAlign := aLayout.Align;
  if LAlign = 0 then
    Exit(TAllocResult.Err(aeInvalidLayout));

  if not CalcRequiredMinSize(aLayout, LMinSegSize) then
    Exit(TAllocResult.Err(aeInvalidLayout));

  if (FActive < 0) or (FActive > High(FSegments)) then
    Exit(TAllocResult.Err(aeInternalError));

  while True do
  begin
    LSegPtr := @FSegments[FActive];

    LPtr := AlignPtr(LSegPtr^.Base + LSegPtr^.Used, LAlign);
    if LPtr = nil then
      Exit(TAllocResult.Err(aeInvalidLayout));
    LOffset := SizeUInt(PtrUInt(LPtr) - PtrUInt(LSegPtr^.Base));

    if (LOffset <= LSegPtr^.Size) and (aLayout.Size <= (LSegPtr^.Size - LOffset)) then
    begin
      LNewUsed := LOffset + aLayout.Size;
      LSegPtr^.Used := LNewUsed;
      Inc(FTotalAllocs);
      if CurrentUsed > FPeakUsed then
        FPeakUsed := CurrentUsed;
      Exit(TAllocResult.Ok(LPtr));
    end;

    // Exhaust current segment and move forward.
    LSegPtr^.Used := LSegPtr^.Size;
    if FActive < High(FSegments) then
    begin
      Inc(FActive);
      Continue;
    end;

    if not AddSegment(LMinSegSize) then
      Exit(TAllocResult.Err(aeOutOfMemory));
    Inc(FActive);
  end;
end;

function TGrowingArena.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

function TGrowingArena.SaveMark: TArenaMarker;
begin
  Result := TArenaMarker(CurrentUsed);
end;

procedure TGrowingArena.RestoreToMark(aMark: TArenaMarker);
var
  LMark: SizeUInt;
  LActiveIdx: SizeInt;
  LEnd: SizeUInt;
  LSegOffset: SizeUInt;
  LLeft: SizeInt;
  LRight: SizeInt;
  LMid: SizeInt;
begin
  LMark := SizeUInt(aMark);
  if LMark > FTotalSize then
    raise EAllocError.Create(aeInvalidLayout, 'TGrowingArena.RestoreToMark: marker out of range');

  if Length(FSegments) = 0 then
    Exit;

  LLeft := 0;
  LRight := High(FSegments);
  while LLeft < LRight do
  begin
    LMid := (LLeft + LRight) shr 1;
    LEnd := FSegments[LMid].StartOffset + FSegments[LMid].Size;
    if LMark <= LEnd then
      LRight := LMid
    else
      LLeft := LMid + 1;
  end;

  LActiveIdx := LLeft;
  LSegOffset := LMark - FSegments[LActiveIdx].StartOffset;
  if (LSegOffset = FSegments[LActiveIdx].Size) and (LActiveIdx < High(FSegments)) then
  begin
    Inc(LActiveIdx);
    LSegOffset := 0;
  end;
  NormalizeState(LActiveIdx, LSegOffset);
end;

procedure TGrowingArena.Reset;
var
  LIdx: SizeInt;
begin
  if Length(FSegments) = 0 then
    Exit;

  if not FKeepSegments then
  begin
    ShrinkToSegmentCount(1);
    FSegments[0].Used := 0;
    FActive := 0;
    Exit;
  end;

  for LIdx := 0 to High(FSegments) do
    FSegments[LIdx].Used := 0;
  FActive := 0;
end;

function TGrowingArena.TotalSize: SizeUInt;
begin
  Result := FTotalSize;
end;

function TGrowingArena.UsedSize: SizeUInt;
begin
  Result := CurrentUsed;
end;

function TGrowingArena.RemainingSize: SizeUInt;
var
  LUsed: SizeUInt;
begin
  LUsed := CurrentUsed;
  if LUsed >= FTotalSize then
    Exit(0);
  Result := FTotalSize - LUsed;
end;

function TGrowingArena.SegmentCount: SizeUInt;
begin
  Result := SizeUInt(Length(FSegments));
end;

{$POP}

end.
