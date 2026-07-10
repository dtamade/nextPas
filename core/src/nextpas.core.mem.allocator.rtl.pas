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
  nextpas.core.platform.sync;

var
  _RTLAllocatorObj: TInterfacedObject = nil;
  _RTLAllocatorIntf: IAllocator = nil;
  GRtlAllocLock: TPlatformMutex;

function TRtlAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.GetMem(ASize);
end;

function TRtlAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.AllocMem(ASize);
end;

function TRtlAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
  begin
    System.FreeMem(APtr);
    Exit(nil);
  end;
  Result := System.ReallocMem(APtr, ASize);
end;

procedure TRtlAllocator.FreeMem(APtr: Pointer); inline;
begin
  System.FreeMem(APtr);
end;

function TRtlAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
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
