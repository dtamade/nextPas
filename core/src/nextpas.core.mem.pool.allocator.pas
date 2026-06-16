unit nextpas.core.mem.pool.allocator;

{$I nextpas.core.settings.inc}

{**
 * TPoolAllocator - 固定块池分配器适配器
 *
 * 将 TFixedPool 适配为 IAllocator 接口，用于集合节点分配优化。
 * 对标 Rust bumpalo / typed-arena 的设计理念：
 * - O(1) 分配和释放
 * - 固定块大小，零碎片
 * - 适用于 TreeMap/LinkedHashMap/ForwardList 等节点分配
 *
 * 使用示例:
 *   var Pool: IAllocator;
 *       Map: ITreeMap<Integer, String>;
 *   begin
 *     Pool := MakePoolAllocator(SizeOf(TRedBlackTreeNode<Integer, String>), 10000);
 *     Map := MakeTreeMap<Integer, String>(0, @IntCompare, Pool);
 *   end;
 *}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.allocator,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.fixed;

type
  {**
   * TPoolAllocator
   *
   * @desc 固定块池分配器，实现 IAllocator 接口
   * @note 固定大小分配使用池，超出大小使用后备分配器
   *}
  TPoolAllocator = class(TInterfacedObject, IAllocator)
  private
    type
      TPoolAllocatorOwner = (paoPool, paoFallback);

      TPoolAllocatorAlloc = record
        Ptr: Pointer;
        Size: SizeUInt;
        Alignment: SizeUInt;
        Owner: TPoolAllocatorOwner;
        Aligned: Boolean;
      end;
  private
    FPool: TFixedPool;
    FBlockSize: SizeUInt;
    FFallback: IAllocator;  // 用于非标准大小分配的后备分配器
    FAllocs: array of TPoolAllocatorAlloc;
    function GetAllocatedCount: Integer;
    function GetCapacity: Integer;
    function GetAvailable: Integer;
    function IsPoolRange(aPtr: Pointer): Boolean;
    function IsPoolBlockStart(aPtr: Pointer): Boolean;
    function FindAlloc(aPtr: Pointer): Integer;
    function TryGetAlloc(aPtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
    procedure TrackAlloc(aPtr: Pointer; aSize, aAlignment: SizeUInt; aOwner: TPoolAllocatorOwner; aAligned: Boolean);
    function UntrackAlloc(aPtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
    procedure UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer; aSize, aAlignment: SizeUInt; aAligned: Boolean);
    function AllocFallback(aSize, aAlignment: SizeUInt; aAligned: Boolean): Pointer;
    procedure FreeTrackedFallbackAllocs;
    procedure RaiseUnknownPointer(aPtr: Pointer; const aOperation: string);
  public
    {**
     * Create
     *
     * @param ABlockSize 块大小（自动对齐到 8 字节）
     * @param ACapacity 池容量（块数量）
     * @param AFallback 后备分配器（用于非标准大小分配）
     *}
    constructor Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator = nil);
    destructor Destroy; override;

    // IAllocator
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function MemSize(aPtr: Pointer): SizeUInt;
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
    // 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）
    function GetMemSize(aPtr: Pointer): SizeUInt;
    function TryGetMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
    function TryAllocMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;

    // 统计
    property BlockSize: SizeUInt read FBlockSize;
    property AllocatedCount: Integer read GetAllocatedCount;
    property Capacity: Integer read GetCapacity;
    property Available: Integer read GetAvailable;
  end;

{**
 * MakePoolAllocator
 *
 * @desc 创建池分配器
 * @param ABlockSize 块大小
 * @param ACapacity 池容量
 * @param AFallback 后备分配器
 * @return IAllocator 池分配器接口
 *}
function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator = nil): IAllocator;

implementation

{ TPoolAllocator }

constructor TPoolAllocator.Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator);
var
  LAlignedSize: SizeUInt;
begin
  inherited Create;

  if ABlockSize > (High(SizeUInt) - 7) then
    raise EAllocError.Create(aeInvalidLayout, 'TPoolAllocator.Create: block size overflow');

  // 确保块大小是 8 的倍数（指针对齐）
  LAlignedSize := (ABlockSize + 7) and not SizeUInt(7);
  if LAlignedSize < SizeOf(Pointer) then
    LAlignedSize := SizeOf(Pointer);

  FBlockSize := LAlignedSize;

  if AFallback = nil then
    FFallback := GetRtlAllocator
  else
    FFallback := AFallback;

  FPool := TFixedPool.Create(FBlockSize, ACapacity, 16, FFallback);
end;

destructor TPoolAllocator.Destroy;
begin
  FreeTrackedFallbackAllocs;
  SetLength(FAllocs, 0);
  FreeAndNil(FPool);
  inherited Destroy;
end;

function TPoolAllocator.IsPoolRange(aPtr: Pointer): Boolean;
begin
  Result := FPool.Owns(aPtr);
end;

function TPoolAllocator.IsPoolBlockStart(aPtr: Pointer): Boolean;
var
  LBase: Pointer;
  LSize: SizeUInt;
  LDiff: SizeUInt;
begin
  Result := False;
  if (aPtr = nil) or (FPool = nil) then
    Exit;

  FPool.GetArenaRange(LBase, LSize);
  if (LBase = nil) or (aPtr < LBase) or (aPtr >= Pointer(PByte(LBase) + LSize)) then
    Exit;

  LDiff := SizeUInt(PByte(aPtr) - PByte(LBase));
  Result := (FBlockSize <> 0) and ((LDiff mod FBlockSize) = 0);
end;

function TPoolAllocator.FindAlloc(aPtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FAllocs) do
    if FAllocs[LIndex].Ptr = aPtr then
      Exit(LIndex);
  Result := -1;
end;

function TPoolAllocator.TryGetAlloc(aPtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindAlloc(aPtr);
  Result := LIndex >= 0;
  if Result then
    aAlloc := FAllocs[LIndex]
  else
  begin
    aAlloc.Ptr := nil;
    aAlloc.Size := 0;
    aAlloc.Alignment := 0;
    aAlloc.Owner := paoFallback;
    aAlloc.Aligned := False;
  end;
end;

procedure TPoolAllocator.TrackAlloc(aPtr: Pointer; aSize, aAlignment: SizeUInt;
  aOwner: TPoolAllocatorOwner; aAligned: Boolean);
var
  LIndex: Integer;
begin
  if aPtr = nil then
    Exit;

  LIndex := FindAlloc(aPtr);
  if LIndex < 0 then
  begin
    LIndex := Length(FAllocs);
    SetLength(FAllocs, LIndex + 1);
  end;

  FAllocs[LIndex].Ptr := aPtr;
  FAllocs[LIndex].Size := aSize;
  FAllocs[LIndex].Alignment := aAlignment;
  FAllocs[LIndex].Owner := aOwner;
  FAllocs[LIndex].Aligned := aAligned;
end;

function TPoolAllocator.UntrackAlloc(aPtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  LIndex := FindAlloc(aPtr);
  Result := LIndex >= 0;
  if not Result then
  begin
    aAlloc.Ptr := nil;
    aAlloc.Size := 0;
    aAlloc.Alignment := 0;
    aAlloc.Owner := paoFallback;
    aAlloc.Aligned := False;
    Exit;
  end;

  aAlloc := FAllocs[LIndex];
  LLast := High(FAllocs);
  FAllocs[LIndex] := FAllocs[LLast];
  SetLength(FAllocs, LLast);
end;

procedure TPoolAllocator.UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer; aSize,
  aAlignment: SizeUInt; aAligned: Boolean);
var
  LIndex: Integer;
begin
  LIndex := FindAlloc(aOldPtr);
  if LIndex < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TPoolAllocator: pointer is not tracked');
  FAllocs[LIndex].Ptr := aNewPtr;
  FAllocs[LIndex].Size := aSize;
  FAllocs[LIndex].Alignment := aAlignment;
  FAllocs[LIndex].Owner := paoFallback;
  FAllocs[LIndex].Aligned := aAligned;
end;

function TPoolAllocator.AllocFallback(aSize, aAlignment: SizeUInt; aAligned: Boolean): Pointer;
begin
  if aSize = 0 then
    Exit(nil);

  if aAligned then
    Result := FFallback.AllocAligned(aSize, aAlignment)
  else
    Result := FFallback.GetMem(aSize);

  if Result <> nil then
  begin
    try
      TrackAlloc(Result, aSize, aAlignment, paoFallback, aAligned);
    except
      if aAligned then
        FFallback.FreeAligned(Result)
      else
        FFallback.FreeMem(Result);
      raise;
    end;
  end;
end;

procedure TPoolAllocator.FreeTrackedFallbackAllocs;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FAllocs) do
    if (FAllocs[LIndex].Owner = paoFallback) and (FAllocs[LIndex].Ptr <> nil) then
    begin
      if FAllocs[LIndex].Aligned then
        FFallback.FreeAligned(FAllocs[LIndex].Ptr)
      else
        FFallback.FreeMem(FAllocs[LIndex].Ptr);
    end;
  SetLength(FAllocs, 0);
end;

procedure TPoolAllocator.RaiseUnknownPointer(aPtr: Pointer; const aOperation: string);
begin
  if IsPoolRange(aPtr) and not IsPoolBlockStart(aPtr) then
    raise EAllocError.Create(aeInvalidPointer, 'TPoolAllocator.' + aOperation + ': pointer is not a pool block start');
  raise EAllocError.Create(aeInvalidPointer, 'TPoolAllocator.' + aOperation + ': pointer is not tracked');
end;

function TPoolAllocator.GetAllocatedCount: Integer;
begin
  Result := FPool.AllocatedCount;
end;

function TPoolAllocator.GetCapacity: Integer;
begin
  Result := FPool.Capacity;
end;

function TPoolAllocator.GetAvailable: Integer;
begin
  Result := FPool.Available;
end;

function TPoolAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);

  if aSize <= FBlockSize then
  begin
    // 从池分配
    if FPool.TryAlloc(Result) then
    begin
      try
        TrackAlloc(Result, aSize, 16, paoPool, False);
      except
        FPool.ReleasePtr(Result);
        raise;
      end;
      Exit;
    end;
  end;

  // 池满或大小超出，使用后备分配器
  Result := AllocFallback(aSize, 0, False);
end;

function TPoolAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);

  Result := GetMem(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TPoolAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LAlloc: TPoolAllocatorAlloc;
  LCopySize: SizeUInt;
begin
  if aDst = nil then
    Exit(GetMem(aSize));

  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;

  if not TryGetAlloc(aDst, LAlloc) then
    RaiseUnknownPointer(aDst, 'ReallocMem');

  if LAlloc.Owner = paoPool then
  begin
    // Pool allocations are fixed-size; realloc uses allocate-copy-release.
    Result := GetMem(aSize);
    if Result <> nil then
    begin
      if LAlloc.Size > aSize then
        LCopySize := aSize
      else
        LCopySize := LAlloc.Size;
      if LCopySize > 0 then
        Move(aDst^, Result^, LCopySize);
      FreeMem(aDst);
    end;
    Exit;
  end

  else if LAlloc.Aligned then
  begin
    Result := AllocFallback(aSize, LAlloc.Alignment, True);
    if Result <> nil then
    begin
      if LAlloc.Size > aSize then
        LCopySize := aSize
      else
        LCopySize := LAlloc.Size;
      if LCopySize > 0 then
        Move(aDst^, Result^, LCopySize);
      FreeAligned(aDst);
    end;
  end

  else
  begin
    Result := FFallback.ReallocMem(aDst, aSize);
    if Result <> nil then
      UpdateTrackedAlloc(aDst, Result, aSize, 0, False);
  end;
end;

procedure TPoolAllocator.FreeMem(aDst: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if aDst = nil then
    Exit;

  if not UntrackAlloc(aDst, LAlloc) then
    RaiseUnknownPointer(aDst, 'FreeMem');

  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(aDst)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(aDst)
  else
    FFallback.FreeMem(aDst);
end;

function TPoolAllocator.MemSize(aPtr: Pointer): SizeUInt;
begin
  Result := GetMemSize(aPtr);
end;

function TPoolAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  if (aAlignment = 0) or ((aAlignment and (aAlignment - 1)) <> 0) then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TPoolAllocator.AllocAligned: alignment must be power of two');
  if aAlignment < SizeOf(Pointer) then
    aAlignment := SizeOf(Pointer);

  // 池分配器的块已经是 16 字节对齐的
  // 如果请求的对齐 <= 16，直接使用池分配
  if (aAlignment <= 16) and (aSize <= FBlockSize) then
  begin
    if FPool.TryAlloc(Result) then
    begin
      try
        TrackAlloc(Result, aSize, 16, paoPool, True);
      except
        FPool.ReleasePtr(Result);
        raise;
      end;
      Exit;
    end;
  end;

  // 否则使用后备分配器
  Result := AllocFallback(aSize, aAlignment, True);
end;

procedure TPoolAllocator.FreeAligned(aPtr: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if aPtr = nil then
    Exit;

  if not UntrackAlloc(aPtr, LAlloc) then
    RaiseUnknownPointer(aPtr, 'FreeAligned');

  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(aPtr)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(aPtr)
  else
    FFallback.FreeMem(aPtr);
end;

function TPoolAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;  // TFixedPool 不是线程安全的
  Result.HasMemSize := False;  // IAllocator surface has no mem-size query.
  Result.SupportsAligned := False;  // non-native fallback path remains available.
end;

// 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）

function TPoolAllocator.GetMemSize(aPtr: Pointer): SizeUInt;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if aPtr = nil then
    Exit(0);
  if TryGetAlloc(aPtr, LAlloc) then
    Result := LAlloc.Size
  else
    Result := 0;
end;

function TPoolAllocator.TryGetMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
begin
  aPtr := GetMem(aSize);
  Result := (aPtr <> nil) or (aSize = 0);
end;

function TPoolAllocator.TryAllocMem(aSize: SizeUInt; out aPtr: Pointer): Boolean;
begin
  aPtr := AllocMem(aSize);
  Result := (aPtr <> nil) or (aSize = 0);
end;

{ Factory function }

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator): IAllocator;
begin
  Result := TPoolAllocator.Create(ABlockSize, ACapacity, AFallback);
end;

end.
