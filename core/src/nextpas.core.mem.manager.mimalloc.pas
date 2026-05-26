unit nextpas.core.mem.manager.mimalloc;

{$I nextpas.core.settings.inc}

{
  Optional global memory manager installer for mimalloc.
  - Manual install/uninstall via InstallMimallocMemoryManager/UninstallMimallocMemoryManager
  - Guarded by FAFAFA_CORE_MIMALLOC_ALLOCATOR
  - Not compatible with heaptrc (do not use together)

  Usage (must be as early as possible):
    uses nextpas.core.mem.manager.mimalloc, ...;
    begin
      InstallMimallocMemoryManager;
      ...
      UninstallMimallocMemoryManager;
    end.
}

interface

{$IFDEF FAFAFA_CORE_MIMALLOC_ALLOCATOR}
uses
  SysUtils,
  nextpas.core.mem.allocator.mimalloc,
  nextpas.core.mem.allocator.base;

procedure InstallMimallocMemoryManager;
procedure UninstallMimallocMemoryManager;
function IsMimallocMemoryManagerInstalled: Boolean;

{$ENDIF} // FAFAFA_CORE_MIMALLOC_ALLOCATOR

implementation

{$IFDEF FAFAFA_CORE_MIMALLOC_ALLOCATOR}


var
  GOldManager: TMemoryManager;
  GInstalled : Boolean = False;
  GAlloc     : nextpas.core.mem.allocator.base.IAllocator;

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
  // ignore Size as allowed by FPC semantics
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
  GMimallocManager: TMemoryManager = (
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

procedure InstallMimallocMemoryManager;
begin
  if GInstalled then Exit;
  // prepare allocator
  GAlloc := GetMimallocAllocator;
  System.GetMemoryManager(GOldManager);
  System.SetMemoryManager(GMimallocManager);
  GInstalled := True;
end;

procedure UninstallMimallocMemoryManager;
begin
  if not GInstalled then Exit;
  System.SetMemoryManager(GOldManager);
  GInstalled := False;
end;

function IsMimallocMemoryManagerInstalled: Boolean;
begin
  Result := GInstalled;
end;

{$ENDIF} // FAFAFA_CORE_MIMALLOC_ALLOCATOR

end.
