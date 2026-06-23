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
    function IsPoolRange(APtr: Pointer): Boolean;
    function IsPoolBlockStart(APtr: Pointer): Boolean;
    function FindAlloc(APtr: Pointer): Integer;
    function TryGetAlloc(APtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
    procedure TrackAlloc(APtr: Pointer; ASize, AAlignment: SizeUInt; aOwner: TPoolAllocatorOwner; aAligned: Boolean);
    function UntrackAlloc(APtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
    procedure UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer; ASize, AAlignment: SizeUInt; aAligned: Boolean);
    function AllocFallback(ASize, AAlignment: SizeUInt; aAligned: Boolean): Pointer;
    procedure FreeTrackedFallbackAllocs;
    procedure RaiseUnknownPointer(APtr: Pointer; const aOperation: string);
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
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function Traits: TAllocatorTraits;
    // 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）
    function GetMemSize(APtr: Pointer): SizeUInt;
    function TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
    function TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean;

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

function TPoolAllocator.IsPoolRange(APtr: Pointer): Boolean;
begin
  Result := FPool.Owns(APtr);
end;

function TPoolAllocator.IsPoolBlockStart(APtr: Pointer): Boolean;
var
  LBase: Pointer;
  LSize: SizeUInt;
  LDiff: SizeUInt;
begin
  Result := False;
  if (APtr = nil) or (FPool = nil) then
    Exit;

  FPool.GetArenaRange(LBase, LSize);
  if (LBase = nil) or (APtr < LBase) or (APtr >= Pointer(PByte(LBase) + LSize)) then
    Exit;

  LDiff := SizeUInt(PByte(APtr) - PByte(LBase));
  Result := (FBlockSize <> 0) and ((LDiff mod FBlockSize) = 0);
end;

function TPoolAllocator.FindAlloc(APtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FAllocs) do
    if FAllocs[LIndex].Ptr = APtr then
      Exit(LIndex);
  Result := -1;
end;

function TPoolAllocator.TryGetAlloc(APtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindAlloc(APtr);
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

procedure TPoolAllocator.TrackAlloc(APtr: Pointer; ASize, AAlignment: SizeUInt;
  aOwner: TPoolAllocatorOwner; aAligned: Boolean);
var
  LIndex: Integer;
begin
  if APtr = nil then
    Exit;

  LIndex := FindAlloc(APtr);
  if LIndex < 0 then
  begin
    LIndex := Length(FAllocs);
    SetLength(FAllocs, LIndex + 1);
  end;

  FAllocs[LIndex].Ptr := APtr;
  FAllocs[LIndex].Size := ASize;
  FAllocs[LIndex].Alignment := AAlignment;
  FAllocs[LIndex].Owner := aOwner;
  FAllocs[LIndex].Aligned := aAligned;
end;

function TPoolAllocator.UntrackAlloc(APtr: Pointer; out aAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  LIndex := FindAlloc(APtr);
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

procedure TPoolAllocator.UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer; ASize,
  AAlignment: SizeUInt; aAligned: Boolean);
var
  LIndex: Integer;
begin
  LIndex := FindAlloc(aOldPtr);
  if LIndex < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TPoolAllocator: pointer is not tracked');
  FAllocs[LIndex].Ptr := aNewPtr;
  FAllocs[LIndex].Size := ASize;
  FAllocs[LIndex].Alignment := AAlignment;
  FAllocs[LIndex].Owner := paoFallback;
  FAllocs[LIndex].Aligned := aAligned;
end;

function TPoolAllocator.AllocFallback(ASize, AAlignment: SizeUInt; aAligned: Boolean): Pointer;
begin
  if ASize = 0 then
    Exit(nil);

  if aAligned then
    Result := FFallback.AllocAligned(ASize, AAlignment)
  else
    Result := FFallback.GetMem(ASize);

  if Result <> nil then
  begin
    try
      TrackAlloc(Result, ASize, AAlignment, paoFallback, aAligned);
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

procedure TPoolAllocator.RaiseUnknownPointer(APtr: Pointer; const aOperation: string);
begin
  if IsPoolRange(APtr) and not IsPoolBlockStart(APtr) then
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

function TPoolAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);

  if ASize <= FBlockSize then
  begin
    // 从池分配
    if FPool.TryAlloc(Result) then
    begin
      try
        TrackAlloc(Result, ASize, 16, paoPool, False);
      except
        FPool.ReleasePtr(Result);
        raise;
      end;
      Exit;
    end;
  end;

  // 池满或大小超出，使用后备分配器
  Result := AllocFallback(ASize, 0, False);
end;

function TPoolAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);

  Result := GetMem(ASize);
  if Result <> nil then
    ZeroMem(Result, ASize);
end;

function TPoolAllocator.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LAlloc: TPoolAllocatorAlloc;
  LCopySize: SizeUInt;
begin
  if ADst = nil then
    Exit(GetMem(ASize));

  if ASize = 0 then
  begin
    FreeMem(ADst);
    Exit(nil);
  end;

  if not TryGetAlloc(ADst, LAlloc) then
    RaiseUnknownPointer(ADst, 'ReallocMem');

  if LAlloc.Owner = paoPool then
  begin
    // Pool allocations are fixed-size; realloc uses allocate-copy-release.
    Result := GetMem(ASize);
    if Result <> nil then
    begin
      if LAlloc.Size > ASize then
        LCopySize := ASize
      else
        LCopySize := LAlloc.Size;
      if LCopySize > 0 then
        CopyMem(Result, ADst, LCopySize);
      FreeMem(ADst);
    end;
    Exit;
  end

  else if LAlloc.Aligned then
  begin
    Result := AllocFallback(ASize, LAlloc.Alignment, True);
    if Result <> nil then
    begin
      if LAlloc.Size > ASize then
        LCopySize := ASize
      else
        LCopySize := LAlloc.Size;
      if LCopySize > 0 then
        CopyMem(Result, ADst, LCopySize);
      FreeAligned(ADst);
    end;
  end

  else
  begin
    Result := FFallback.ReallocMem(ADst, ASize);
    if Result <> nil then
      UpdateTrackedAlloc(ADst, Result, ASize, 0, False);
  end;
end;

procedure TPoolAllocator.FreeMem(ADst: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if ADst = nil then
    Exit;

  if not UntrackAlloc(ADst, LAlloc) then
    RaiseUnknownPointer(ADst, 'FreeMem');

  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(ADst)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(ADst)
  else
    FFallback.FreeMem(ADst);
end;

function TPoolAllocator.MemSize(APtr: Pointer): SizeUInt;
begin
  Result := GetMemSize(APtr);
end;

function TPoolAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  if (AAlignment = 0) or ((AAlignment and (AAlignment - 1)) <> 0) then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TPoolAllocator.AllocAligned: alignment must be power of two');
  if AAlignment < SizeOf(Pointer) then
    AAlignment := SizeOf(Pointer);

  // 池分配器的块已经是 16 字节对齐的
  // 如果请求的对齐 <= 16，直接使用池分配
  if (AAlignment <= 16) and (ASize <= FBlockSize) then
  begin
    if FPool.TryAlloc(Result) then
    begin
      try
        TrackAlloc(Result, ASize, 16, paoPool, True);
      except
        FPool.ReleasePtr(Result);
        raise;
      end;
      Exit;
    end;
  end;

  // 否则使用后备分配器
  Result := AllocFallback(ASize, AAlignment, True);
end;

procedure TPoolAllocator.FreeAligned(APtr: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit;

  if not UntrackAlloc(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'FreeAligned');

  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(APtr)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(APtr)
  else
    FFallback.FreeMem(APtr);
end;

function TPoolAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;  // TFixedPool 不是线程安全的
  Result.HasMemSize := False;  // IAllocator surface has no mem-size query.
  Result.SupportsAligned := False;  // non-native fallback path remains available.
end;

// 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）

function TPoolAllocator.GetMemSize(APtr: Pointer): SizeUInt;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit(0);
  if TryGetAlloc(APtr, LAlloc) then
    Result := LAlloc.Size
  else
    Result := 0;
end;

function TPoolAllocator.TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := GetMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

function TPoolAllocator.TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := AllocMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

{ Factory function }

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator): IAllocator;
begin
  Result := TPoolAllocator.Create(ABlockSize, ACapacity, AFallback);
end;

end.
