unit nextpas.core.mem.allocator.rtl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.mem.allocator.base;

type
  {**
   * TRtlAllocator
   * @desc 使用标准 Pascal RTL 内存管理器实现的 IAllocator 具体类
   *}
  TRtlAllocator = class(TAllocator)
  protected
    function  DoGetMem(ASize: SizeUInt): Pointer; override;
    function  DoAllocMem(ASize: SizeUInt): Pointer; override;
    function  DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    function  Traits: TAllocatorTraits; override;
  end;

function GetRtlAllocator: IAllocator;
function TryGetRtlAllocator(out A: IAllocator): Boolean;
function ResolveAllocator(const AAllocator: IAllocator): IAllocator;

implementation

uses
  nextpas.core.platform.sync;

var
  _RTLAllocatorObj: TAllocator = nil;
  _RTLAllocatorIntf: IAllocator = nil;
  GRtlAllocLock: TPlatformMutex;

function TRtlAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := System.GetMem(ASize);
end;

function TRtlAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := System.AllocMem(ASize);
end;

function TRtlAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := System.ReallocMem(ADst, ASize);
end;

procedure TRtlAllocator.DoFreeMem(ADst: Pointer);
begin
  System.FreeMem(ADst);
end;

function TRtlAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  // RTL Allocator semantics:
  // - AllocMem zero-initializes; GetMem does not guarantee zero
  // - No native aligned API exposed via this allocator (use aligned module/bridge)
  // - No MemSize/usable_size available
  Result.ZeroInitialized := True;
end;

function GetRtlAllocator: IAllocator;
begin
  { Double-check locking. Safe on x86 (TSO: stores visible in program order).
    On ARM/AArch64 the outer nil check may read a stale pointer; this module
    targets x86-64 Linux where the pattern is correct.

    GRtlAllocLock is a TPlatformMutex — zero-initialized (valid pthread_mutex_t
    default), no explicit Init needed. This avoids TMemMutex's lazy-init state
    machine which would fail if called before the mutex's unit initialization. }
  if _RTLAllocatorObj = nil then
  begin
    platform_mutex_lock(GRtlAllocLock);
    try
      if _RTLAllocatorObj = nil then
      begin
        _RTLAllocatorObj := TRtlAllocator.Create;
        _RTLAllocatorIntf := _RTLAllocatorObj as IAllocator; // anchor lifetime via interface
      end;
    finally
      platform_mutex_unlock(GRtlAllocLock);
    end;
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
  if AAllocator <> nil then
    Result := AAllocator
  else
    Result := GetRtlAllocator;
end;

finalization
  _RTLAllocatorIntf := nil; // release anchor; object will be freed by interface refcount
  _RTLAllocatorObj := nil;

end.
