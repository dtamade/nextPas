unit nextpas.core.mem.pool.allocator;

{$I nextpas.core.settings.inc}

{**
 * TPoolAllocator - 固定块池分配器适配器
 *
 * 将 TFixedPool 适配为 TAllocator 子类，用于集合节点分配优化。
 * 固定大小分配使用池，超出大小使用后备分配器。
 *
 * 使用示例:
 *   var Pool: TAllocator;
 *   begin
 *     Pool := MakePoolAllocator(SizeOf(TNode), 10000);
 *   end;
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.fixed;

type
  TPoolAllocator = class(TAllocator)
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
    FFallback: TAllocator;
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
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    constructor Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: TAllocator = nil);
    destructor Destroy; override;

    procedure FreeMem(APtr: Pointer; ASize: SizeUInt); override;
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; override;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer; override;
    procedure FreeAligned(APtr: Pointer); override;
    function Traits: TAllocatorTraits; override;

    function GetMemSize(APtr: Pointer): SizeUInt;
    function TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
    function TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean;

    property BlockSize: SizeUInt read FBlockSize;
    property AllocatedCount: Integer read GetAllocatedCount;
    property Capacity: Integer read GetCapacity;
    property Available: Integer read GetAvailable;
  end;

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: TAllocator = nil): TAllocator;

implementation

uses
  nextpas.core.mem.allocator.rtl;

{ TPoolAllocator }

constructor TPoolAllocator.Create(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: TAllocator);
var
  LAlignedSize: SizeUInt;
begin
  inherited Create;
  if ABlockSize > (High(SizeUInt) - 7) then
    raise EAllocError.Create(aeInvalidLayout, 'TPoolAllocator.Create: block size overflow');
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
  if (APtr = nil) or (FPool = nil) then Exit;
  FPool.GetArenaRange(LBase, LSize);
  if (LBase = nil) or (APtr < LBase) or (APtr >= Pointer(PByte(LBase) + LSize)) then Exit;
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
  else begin
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
  if APtr = nil then Exit;
  LIndex := FindAlloc(APtr);
  if LIndex < 0 then begin
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
  LIndex, LLast: Integer;
begin
  LIndex := FindAlloc(APtr);
  Result := LIndex >= 0;
  if not Result then begin
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

procedure TPoolAllocator.UpdateTrackedAlloc(aOldPtr, aNewPtr: Pointer;
  ASize, AAlignment: SizeUInt; aAligned: Boolean);
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
  if ASize = 0 then Exit(nil);
  if aAligned then
    Result := FFallback.AllocAligned(ASize, AAlignment)
  else
    Result := FFallback.GetMem(ASize);
  if Result <> nil then begin
    try
      TrackAlloc(Result, ASize, AAlignment, paoFallback, aAligned);
    except
      if aAligned then
        FFallback.FreeAligned(Result)
      else
        FFallback.FreeMem(Result, ASize);
      raise;
    end;
  end;
end;

procedure TPoolAllocator.FreeTrackedFallbackAllocs;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FAllocs) do
    if (FAllocs[LIndex].Owner = paoFallback) and (FAllocs[LIndex].Ptr <> nil) then begin
      if FAllocs[LIndex].Aligned then
        FFallback.FreeAligned(FAllocs[LIndex].Ptr)
      else
        FFallback.FreeMem(FAllocs[LIndex].Ptr, FAllocs[LIndex].Size);
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

{ --- Do* template methods (Phase 0-1 compat) --- }

function TPoolAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if ASize <= FBlockSize then begin
    if FPool.TryAlloc(Result) then begin
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

function TPoolAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    ZeroMem(Result, ASize);
end;

function TPoolAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LAlloc: TPoolAllocatorAlloc;
  LCopySize: SizeUInt;
begin
  if ADst = nil then Exit(DoGetMem(ASize));
  if ASize = 0 then begin
    DoFreeMem(ADst);
    Exit(nil);
  end;
  if not TryGetAlloc(ADst, LAlloc) then
    RaiseUnknownPointer(ADst, 'ReallocMem');
  if LAlloc.Owner = paoPool then begin
    Result := DoGetMem(ASize);
    if Result <> nil then begin
      LCopySize := LAlloc.Size;
      if LCopySize > ASize then LCopySize := ASize;
      if LCopySize > 0 then CopyMem(Result, ADst, LCopySize);
      DoFreeMem(ADst);
    end;
  end else if LAlloc.Aligned then begin
    Result := AllocFallback(ASize, LAlloc.Alignment, True);
    if Result <> nil then begin
      LCopySize := LAlloc.Size;
      if LCopySize > ASize then LCopySize := ASize;
      if LCopySize > 0 then CopyMem(Result, ADst, LCopySize);
      FFallback.FreeAligned(ADst);
    end;
  end else begin
    Result := FFallback.ReallocMem(ADst, LAlloc.Size, ASize);
    if Result <> nil then
      UpdateTrackedAlloc(ADst, Result, ASize, 0, False);
  end;
end;

procedure TPoolAllocator.DoFreeMem(ADst: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if ADst = nil then Exit;
  if not UntrackAlloc(ADst, LAlloc) then
    RaiseUnknownPointer(ADst, 'FreeMem');
  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(ADst)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(ADst)
  else
    FFallback.FreeMem(ADst, LAlloc.Size);
end;

{ --- New public signatures (Phase 1) --- }

procedure TPoolAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then Exit;
  if not UntrackAlloc(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'FreeMem');
  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(APtr)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(APtr)
  else
    FFallback.FreeMem(APtr, LAlloc.Size);
end;

function TPoolAllocator.ReallocMem(APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer;
var
  LAlloc: TPoolAllocatorAlloc;
  LCopySize: SizeUInt;
begin
  if APtr = nil then Exit(DoGetMem(ANewSize));
  if ANewSize = 0 then begin
    FreeMem(APtr, AOldSize);
    Exit(nil);
  end;
  if not TryGetAlloc(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'ReallocMem');
  if LAlloc.Owner = paoPool then begin
    Result := DoGetMem(ANewSize);
    if Result <> nil then begin
      LCopySize := LAlloc.Size;
      if LCopySize > ANewSize then LCopySize := ANewSize;
      if LCopySize > 0 then CopyMem(Result, APtr, LCopySize);
      FreeMem(APtr, LAlloc.Size);
    end;
  end else if LAlloc.Aligned then begin
    Result := AllocFallback(ANewSize, LAlloc.Alignment, True);
    if Result <> nil then begin
      LCopySize := LAlloc.Size;
      if LCopySize > ANewSize then LCopySize := ANewSize;
      if LCopySize > 0 then CopyMem(Result, APtr, LCopySize);
      FFallback.FreeAligned(APtr);
    end;
  end else begin
    Result := FFallback.ReallocMem(APtr, LAlloc.Size, ANewSize);
    if Result <> nil then
      UpdateTrackedAlloc(APtr, Result, ANewSize, 0, False);
  end;
end;

function TPoolAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

function TPoolAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  if (AAlignment = 0) or ((AAlignment and (AAlignment - 1)) <> 0) then
    raise EAllocError.Create(aeAlignmentNotSupported, 'TPoolAllocator.AllocAligned: alignment must be power of two');
  if AAlignment < SizeOf(Pointer) then
    AAlignment := SizeOf(Pointer);
  if (AAlignment <= 16) and (ASize <= FBlockSize) then begin
    if FPool.TryAlloc(Result) then begin
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

procedure TPoolAllocator.FreeAligned(APtr: Pointer);
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then Exit;
  if not UntrackAlloc(APtr, LAlloc) then
    RaiseUnknownPointer(APtr, 'FreeAligned');
  if LAlloc.Owner = paoPool then
    FPool.ReleasePtr(APtr)
  else if LAlloc.Aligned then
    FFallback.FreeAligned(APtr)
  else
    FFallback.FreeMem(APtr, LAlloc.Size);
end;

function TPoolAllocator.GetMemSize(APtr: Pointer): SizeUInt;
var
  LAlloc: TPoolAllocatorAlloc;
begin
  if APtr = nil then Exit(0);
  if TryGetAlloc(APtr, LAlloc) then
    Result := LAlloc.Size
  else
    Result := 0;
end;

function TPoolAllocator.TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := DoGetMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

function TPoolAllocator.TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := DoAllocMem(ASize);
  Result := (APtr <> nil) or (ASize = 0);
end;

{ Factory function }

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer; AFallback: TAllocator): TAllocator;
begin
  Result := TPoolAllocator.Create(ABlockSize, ACapacity, AFallback);
end;

end.
