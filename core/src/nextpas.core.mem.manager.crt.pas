unit nextpas.core.mem.manager.crt;

{$I nextpas.core.settings.inc}

{
  Optional global memory manager installer for CRT (C runtime malloc/calloc/realloc/free).
  - Manual install/uninstall via InstallCrtMemoryManager/UninstallCrtMemoryManager
  - Guarded by FAFAFA_CORE_CRT_ALLOCATOR (CRT allocator enabled)
  - Not compatible with heaptrc; ensure this unit is used deliberately

  Usage (put early in uses of your program):
    uses nextpas.core.mem.manager.crt, ...;
    begin
      InstallCrtMemoryManager;
      ...
      UninstallCrtMemoryManager;
    end.
}

interface

{$IFDEF FAFAFA_CORE_CRT_ALLOCATOR}
uses
  SysUtils;

procedure InstallCrtMemoryManager;
procedure UninstallCrtMemoryManager;
function IsCrtMemoryManagerInstalled: Boolean;

{$ENDIF} // FAFAFA_CORE_CRT_ALLOCATOR

implementation

{$IFDEF FAFAFA_CORE_CRT_ALLOCATOR}
uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt_allocator,
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
  // unknown for CRT
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
  GCrtManager: TMemoryManager = (
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

procedure InstallCrtMemoryManager;
var
  LGuard: ILockGuard;
begin
  LGuard := GManagerLock.Lock;
  if GInstalled then Exit;
  // Prepare allocator (uses CRT C runtime under the hood)
  GAlloc := GetCrtAllocator;
  System.GetMemoryManager(GOldManager);
  System.SetMemoryManager(GCrtManager);
  GInstalled := True;
end;

procedure UninstallCrtMemoryManager;
var
  LGuard: ILockGuard;
begin
  LGuard := GManagerLock.Lock;
  if not GInstalled then Exit;
  System.SetMemoryManager(GOldManager);
  GInstalled := False;
end;

function IsCrtMemoryManagerInstalled: Boolean;
begin
  Result := GInstalled;
end;

initialization
  GManagerLock := TMutex.Create;

{$ENDIF} // FAFAFA_CORE_CRT_ALLOCATOR

end.
