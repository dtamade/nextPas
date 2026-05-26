unit nextpas.core.mem.manager.rtl;

{$I nextpas.core.settings.inc}

{
  Optional global memory manager installer for RTL (default System memory manager).
  - Manual install/uninstall via InstallRtlMemoryManager/UninstallRtlMemoryManager
  - Always available

  Usage (put early in uses of your program):
    uses nextpas.core.mem.manager.rtl, ...;
    begin
      InstallRtlMemoryManager;
      ...
      UninstallRtlMemoryManager;
    end.
}

interface

uses
  SysUtils;

procedure InstallRtlMemoryManager;
procedure UninstallRtlMemoryManager;
function IsRtlMemoryManagerInstalled: Boolean;

implementation

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.rtl_allocator,
  nextpas.core.sync;

var
  GOldManager: TMemoryManager;
  GInstalled : Boolean = False;
  GAlloc     : nextpas.core.mem.allocator.base.IAllocator;
  GManagerLock: ILock;

function MM_GetMem(Size: SizeUInt): Pointer;
begin
  if Size = 0 then Exit(nil);
  Result := GAlloc.GetMem(Size);
end;

function MM_AllocMem(Size: SizeUInt): Pointer;
begin
  if Size = 0 then Exit(nil);
  Result := GAlloc.AllocMem(Size);
end;

function MM_ReAllocMem(var P: Pointer; Size: SizeUInt): Pointer;
begin
  Result := GAlloc.ReallocMem(P, Size);
end;

function MM_FreeMem(P: Pointer): SizeUInt;
begin
  if P <> nil then
    GAlloc.FreeMem(P);
  Result := 0;
end;

function MM_FreeMemSize(P: Pointer; Size: SizeUInt): SizeUInt;
begin
  Result := MM_FreeMem(P);
end;

function MM_MemSize(P: Pointer): SizeUInt;
begin
  // unknown
  Result := 0;
end;

procedure MM_InitThread; begin end;
procedure MM_DoneThread; begin end;
procedure MM_RelocateHeap; begin end;

function MM_GetHeapStatus: THeapStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function MM_GetFPCHeapStatus: TFPCHeapStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

const
  GRtlManager: TMemoryManager = (
    NeedLock      : False;
    GetMem        : @MM_GetMem;
    FreeMem       : @MM_FreeMem;
    FreeMemSize   : @MM_FreeMemSize;
    AllocMem      : @MM_AllocMem;
    ReAllocMem    : @MM_ReAllocMem;
    MemSize       : @MM_MemSize;
    InitThread    : @MM_InitThread;
    DoneThread    : @MM_DoneThread;
    RelocateHeap  : @MM_RelocateHeap;
    GetHeapStatus : @MM_GetHeapStatus;
    GetFPCHeapStatus : @MM_GetFPCHeapStatus
  );

procedure InstallRtlMemoryManager;
var
  LGuard: ILockGuard;
begin
  LGuard := GManagerLock.Lock;
  if GInstalled then Exit;
  // Prepare allocator (wrapping System mem functions)
  GAlloc := GetRtlAllocator;
  System.GetMemoryManager(GOldManager);
  System.SetMemoryManager(GRtlManager);
  GInstalled := True;
end;

procedure UninstallRtlMemoryManager;
var
  LGuard: ILockGuard;
begin
  LGuard := GManagerLock.Lock;
  if not GInstalled then Exit;
  System.SetMemoryManager(GOldManager);
  GInstalled := False;
end;

function IsRtlMemoryManagerInstalled: Boolean;
begin
  Result := GInstalled;
end;

initialization
  GManagerLock := TMutex.Create;

end.
