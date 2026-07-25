unit nextpas.core.mem.allocator.rtl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.mem.intf;

type
  {**
   * TRtlAllocator
   * @desc 使用标准 Pascal RTL 内存管理器实现的 IAllocator 具体类
   *}
  TRtlAllocator = class(TInterfacedObject, IAllocator)
  public
    function  GetMem(ASize: SizeUInt): Pointer; inline;
    function  AllocMem(ASize: SizeUInt): Pointer; inline;
    function  ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function  Traits: TAllocatorTraits; inline;
  end;

function GetRtlAllocator: IAllocator;
function TryGetRtlAllocator(out A: IAllocator): Boolean;
function ResolveAllocator(const AAllocator: IAllocator): IAllocator;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.system.heap;

var
  _RTLAllocatorObj: TInterfacedObject = nil;
  _RTLAllocatorIntf: IAllocator = nil;
  { 0 = unpublished; 1 = ready. Acquire-load / release-store for portable DCL. }
  _RTLAllocatorReady: Int32 = 0;
  GRtlAllocLock: TPlatformMutex;

function TRtlAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := NpSystemGetMem(ASize);
end;

function TRtlAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := NpSystemAllocMem(ASize);
end;

function TRtlAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
  begin
    NpSystemFreeMem(APtr);
    Exit(nil);
  end;
  Result := NpSystemReallocMem(APtr, ASize);
end;

procedure TRtlAllocator.FreeMem(APtr: Pointer); inline;
begin
  NpSystemFreeMem(APtr);
end;

function TRtlAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
  Result.SupportsRealloc := True;
end;

function GetRtlAllocator: IAllocator;
begin
  { Portable double-checked locking: acquire-load of ready flag, then read
    interface. Publisher writes interface then release-stores ready=1 under mutex. }
  if AtomicLoad32(_RTLAllocatorReady, moAcquire) <> 0 then
    Exit(_RTLAllocatorIntf);

  platform_mutex_lock(GRtlAllocLock);
  try
    if AtomicLoad32(_RTLAllocatorReady, moAcquire) = 0 then
    begin
      _RTLAllocatorObj := TRtlAllocator.Create;
      _RTLAllocatorIntf := _RTLAllocatorObj as IAllocator;
      AtomicStore32(_RTLAllocatorReady, 1, moRelease);
    end;
  finally
    platform_mutex_unlock(GRtlAllocLock);
  end;
  Result := _RTLAllocatorIntf;
end;

function TryGetRtlAllocator(out A: IAllocator): Boolean;
begin
  try
    A := GetRtlAllocator;
    Result := True;
  except
    A := nil;
    Result := False;
  end;
end;

function ResolveAllocator(const AAllocator: IAllocator): IAllocator;
begin
  { S5: nil means process default heap (Growing IAllocator), not RTL.
    Explicit RTL remains available via GetRtlAllocator. }
  if AAllocator <> nil then
    Result := AAllocator
  else
    Result := nextpas.core.mem.allocator.growing_ia.GetGrowingIAllocator;
end;

finalization
  _RTLAllocatorIntf := nil; // release anchor; object will be freed by interface refcount
  _RTLAllocatorObj := nil;

end.
