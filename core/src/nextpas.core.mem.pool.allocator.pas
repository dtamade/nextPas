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
 *     Pool := CreatePoolAllocator(SizeOf(TRedBlackTreeNode<Integer, String>), 10000);
 *     Map := MakeTreeMap<Integer, String>(0, @IntCompare, Pool);
 *   end;
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.allocator,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.utils,
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
    { Open-addressing hash map: PtrUInt → TPoolAllocatorAlloc }
    FMap: array of TPoolAllocatorAlloc;
    FMapCapacity: SizeUInt;   { always power-of-two, or 0 }
    FMapCount: SizeUInt;      { live entries }
    FMapTombstones: SizeUInt;
    function MapGet(APtr: Pointer; out AAlloc: TPoolAllocatorAlloc): Boolean;
    function MapInsertOrReplace(APtr: Pointer; const AAlloc: TPoolAllocatorAlloc): Boolean;
    function MapDelete(APtr: Pointer; out AAlloc: TPoolAllocatorAlloc): Boolean;
    procedure MapGrow;
    function MapProbe(APtr: Pointer): SizeUInt;
    function GetAllocatedCount: Integer;
    function GetCapacity: Integer;
    function GetAvailable: Integer;
    function IsPoolRange(APtr: Pointer): Boolean;
    function IsPoolBlockStart(APtr: Pointer): Boolean;
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
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function MemSize(APtr: Pointer): SizeUInt; inline;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer; inline;
    procedure FreeAligned(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    // 扩展方法（非 IAllocator 接口，仅 TPoolAllocator 提供）
    function GetMemSize(APtr: Pointer): SizeUInt; inline;
    function TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;
    function TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;

    // 统计
    property BlockSize: SizeUInt read FBlockSize;
    property AllocatedCount: Integer read GetAllocatedCount;
    property Capacity: Integer read GetCapacity;
    property Available: Integer read GetAvailable;
  end;

{**
 * CreatePoolAllocator
 *
 * @desc 创建池分配器
 * @param ABlockSize 块大小
 * @param ACapacity 池容量
 * @param AFallback 后备分配器
 * @return IAllocator 池分配器接口
 *}
function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: IAllocator = nil): IAllocator;

implementation

const
  MAP_TOMBSTONE_PTR = Pointer(PtrUInt(1));

{ TPoolAllocator — hash map internals }

function TPoolAllocator.MapProbe(APtr: Pointer): SizeUInt;
begin
  Result := MulHash64(PtrUInt(APtr)) and (FMapCapacity - 1);
end;

function TPoolAllocator.MapGet(APtr: Pointer; out AAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIdx: SizeUInt;
  LSlotPtr: Pointer;
begin
  Result := False;
  if FMapCapacity = 0 then
    Exit;
  LIdx := MapProbe(APtr);
  while True do
  begin
    LSlotPtr := FMap[LIdx].Ptr;
    if LSlotPtr = nil then
      Exit;
    if LSlotPtr = APtr then
    begin
      AAlloc := FMap[LIdx];
      Exit(True);
    end;
    LIdx := (LIdx + 1) and (FMapCapacity - 1);
  end;
end;

function TPoolAllocator.MapInsertOrReplace(APtr: Pointer;
  const AAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIdx: SizeUInt;
  LTombIdx: SizeUInt;
  LSlotPtr: Pointer;
begin
  if (3 * (FMapCount + FMapTombstones + 1)) >= (2 * FMapCapacity) then
    MapGrow;
  Result := False;
  LIdx := MapProbe(APtr);
  LTombIdx := High(SizeUInt);
  while True do
  begin
    LSlotPtr := FMap[LIdx].Ptr;
    if LSlotPtr = nil then
    begin
      if LTombIdx <> High(SizeUInt) then
        LIdx := LTombIdx;
      FMap[LIdx] := AAlloc;
      Inc(FMapCount);
      if LTombIdx <> High(SizeUInt) then
        Dec(FMapTombstones);
      Exit;
    end;
    if LSlotPtr = MAP_TOMBSTONE_PTR then
    begin
      if LTombIdx = High(SizeUInt) then
        LTombIdx := LIdx;
    end
    else if LSlotPtr = APtr then
    begin
      FMap[LIdx] := AAlloc;
      Exit(True);
    end;
    LIdx := (LIdx + 1) and (FMapCapacity - 1);
  end;
end;

function TPoolAllocator.MapDelete(APtr: Pointer;
  out AAlloc: TPoolAllocatorAlloc): Boolean;
var
  LIdx: SizeUInt;
begin
  Result := False;
  if FMapCapacity = 0 then
    Exit;
  LIdx := MapProbe(APtr);
  while True do
  begin
    if FMap[LIdx].Ptr = nil then
      Exit;
    if (FMap[LIdx].Ptr <> MAP_TOMBSTONE_PTR) and (FMap[LIdx].Ptr = APtr) then
    begin
      AAlloc := FMap[LIdx];
      FMap[LIdx].Ptr := MAP_TOMBSTONE_PTR;
      FMap[LIdx].Size := 0;
      Dec(FMapCount);
      Inc(FMapTombstones);
      Exit(True);
    end;
    LIdx := (LIdx + 1) and (FMapCapacity - 1);
  end;
end;

procedure TPoolAllocator.MapGrow;
var
  LOldMap: array of TPoolAllocatorAlloc;
  LOldCap: SizeUInt;
  I: SizeUInt;
  LAlloc: TPoolAllocatorAlloc;
begin
  LOldMap := FMap;
  LOldCap := FMapCapacity;
  if FMapCapacity = 0 then
    FMapCapacity := 64
  else
    FMapCapacity := FMapCapacity shl 1;
  SetLength(FMap, FMapCapacity);
  FMapCount := 0;
  FMapTombstones := 0;
  if LOldCap > 0 then
    for I := 0 to LOldCap - 1 do
      if (LOldMap[I].Ptr <> nil) and (LOldMap[I].Ptr <> MAP_TOMBSTONE_PTR) then
      begin
        LAlloc := LOldMap[I];
        MapInsertOrReplace(LAlloc.Ptr, LAlloc);
      end;
end;

{ TPoolAllocator — lifecycle }

constructor TPoolAllocator.Create(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator);
var
  LAlignedSize: SizeUInt;
begin
  inherited Create;

  if ABlockSize > (High(SizeUInt) - 7) then
    raise EAllocError.Create(aeInvalidLayout,
      'TPoolAllocator.Create: block size overflow (' + IntToStr(ABlockSize) + ')');

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
  FMap := nil;
  FMapCapacity := 0;
  FMapCount := 0;
  FMapTombstones := 0;
end;

destructor TPoolAllocator.Destroy;
begin
  FreeTrackedFallbackAllocs;
  FMap := nil;
  FreeAndNil(FPool);
  inherited Destroy;
end;

{ TPoolAllocator — helpers }

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

procedure TPoolAllocator.TrackAlloc(APtr: Pointer; ASize, AAlignment: SizeUInt;
  aOwner: TPoolAllocatorOwner; aAligned: Boolean);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit;
  LAlloc.Ptr := APtr;
  LAlloc.Size := ASize;
  LAlloc.Alignment := AAlignment;
  LAlloc.Owner := aOwner;
  LAlloc.Aligned := aAligned;
  MapInsertOrReplace(APtr, LAlloc);
end;

function TPoolAllocator.UntrackAlloc(APtr: Pointer;
  out aAlloc: TPoolAllocatorAlloc): Boolean;
begin
  Result := MapDelete(APtr, aAlloc);
end;

procedure TPoolAllocator.UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer;
  ASize, AAlignment: SizeUInt; aAligned: Boolean);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if not MapDelete(aOldPtr, LAlloc) then
    raise EAllocError.Create(aeInvalidPointer, 'TPoolAllocator: pointer is not tracked');
  LAlloc.Ptr := aNewPtr;
  LAlloc.Size := ASize;
  LAlloc.Alignment := AAlignment;
  LAlloc.Owner := paoFallback;
  LAlloc.Aligned := aAligned;
  MapInsertOrReplace(aNewPtr, LAlloc);
end;

function TPoolAllocator.AllocFallback(ASize, AAlignment: SizeUInt;
  aAligned: Boolean): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
begin
  if ASize = 0 then
    Exit(nil);

  if aAligned then
  begin
    if AAlignment < SizeOf(Pointer) then
      AAlignment := SizeOf(Pointer);
    LAlignMask := AAlignment - 1;
    LRaw := FFallback.GetMem(ASize + LAlignMask + SizeOf(Pointer));
    if LRaw = nil then
      Exit(nil);
    Result := AlignUpUnChecked(LRaw + SizeOf(Pointer), AAlignment);
    PPointer(PByte(Result) - SizeOf(Pointer))^ := LRaw;
  end
  else
    Result := FFallback.GetMem(ASize);

  if Result <> nil then
  begin
    try
      TrackAlloc(Result, ASize, AAlignment, paoFallback, aAligned);
    except
      if aAligned then
        FFallback.FreeMem(PPointer(PByte(Result) - SizeOf(Pointer))^)
      else
        FFallback.FreeMem(Result);
      raise;
    end;
  end;
end;

procedure TPoolAllocator.FreeTrackedFallbackAllocs;
var
  I: SizeUInt;
begin
  if FMapCapacity > 0 then
    for I := 0 to FMapCapacity - 1 do
      if (FMap[I].Ptr <> nil) and (FMap[I].Ptr <> MAP_TOMBSTONE_PTR) and
         (FMap[I].Owner = paoFallback) then
      begin
        if FMap[I].Aligned then
          FFallback.FreeMem(PPointer(PByte(FMap[I].Ptr) - SizeOf(Pointer))^)
        else
          FFallback.FreeMem(FMap[I].Ptr);
      end;
  FMap := nil;
  FMapCapacity := 0;
  FMapCount := 0;
  FMapTombstones := 0;
end;

procedure TPoolAllocator.RaiseUnknownPointer(APtr: Pointer;
  const aOperation: string);
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

{ TPoolAllocator — IAllocator }

function TPoolAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);

  if ASize <= FBlockSize then
  begin
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

  Result := AllocFallback(ASize, 0, False);
end;

function TPoolAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);

  Result := GetMem(ASize);
  if Result <> nil then
    ZeroMem(Result, ASize);
end;

function TPoolAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LAlloc: TPoolAllocatorAlloc;
  LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));

  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  if not MapGet(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'ReallocMem');

  if LAlloc.Owner = paoPool then
  begin
    Result := GetMem(ASize);
    if Result <> nil then
    begin
      if LAlloc.Size > ASize then
        LCopySize := ASize
      else
        LCopySize := LAlloc.Size;
      if LCopySize > 0 then
        CopyMem(Result, APtr, LCopySize);
      FreeMem(APtr);
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
        CopyMem(Result, APtr, LCopySize);
      FreeAligned(APtr);
    end;
  end

  else
  begin
    Result := FFallback.ReallocMem(APtr, ASize);
    if Result <> nil then
      UpdateTrackedAlloc(APtr, Result, ASize, 0, False);
  end;
end;

procedure TPoolAllocator.FreeMem(APtr: Pointer); inline;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit;

  if not UntrackAlloc(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'FreeMem');

  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(APtr)
  else if LAlloc.Aligned then
    FFallback.FreeMem(PPointer(PByte(APtr) - SizeOf(Pointer))^)
  else
    FFallback.FreeMem(APtr);
end;

function TPoolAllocator.MemSize(APtr: Pointer): SizeUInt; inline;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit(0);
  if MapGet(APtr, LAlloc) then
    Result := LAlloc.Size
  else
    Result := 0;
end;

function TPoolAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  if (AAlignment = 0) or ((AAlignment and (AAlignment - 1)) <> 0) then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TPoolAllocator.AllocAligned: alignment must be power of two');
  if AAlignment < SizeOf(Pointer) then
    AAlignment := SizeOf(Pointer);

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

  Result := AllocFallback(ASize, AAlignment, True);
end;

procedure TPoolAllocator.FreeAligned(APtr: Pointer); inline;
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
    FFallback.FreeMem(PPointer(PByte(APtr) - SizeOf(Pointer))^)
  else
    FFallback.FreeMem(APtr);
end;

function TPoolAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

function TPoolAllocator.GetMemSize(APtr: Pointer): SizeUInt; inline;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then
    Exit(0);
  if MapGet(APtr, LAlloc) then
    Result := LAlloc.Size
  else
    Result := 0;
end;

function TPoolAllocator.TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;
begin
  APtr := GetMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

function TPoolAllocator.TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;
begin
  APtr := AllocMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

{ Factory function }

function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator): IAllocator;
begin
  Result := TPoolAllocator.Create(ABlockSize, ACapacity, AFallback);
end;

end.
