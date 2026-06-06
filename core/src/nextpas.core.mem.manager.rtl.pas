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

procedure InstallRtlMemoryManager;
procedure UninstallRtlMemoryManager;
function IsRtlMemoryManagerInstalled: Boolean;

implementation

uses
  nextpas.core.mem.mutex;

var
  GOldManager: TMemoryManager;
  GInstalled : Boolean = False;
  GManagerLock: TMemMutex;

function MM_GetMem(Size: SizeUInt): Pointer;
begin
  if Size = 0 then Exit(nil);
  Result := GOldManager.GetMem(Size);
end;

function MM_AllocMem(Size: SizeUInt): Pointer;
begin
  if Size = 0 then Exit(nil);
  if Assigned(GOldManager.AllocMem) then
    Result := GOldManager.AllocMem(Size)
  else
  begin
    Result := GOldManager.GetMem(Size);
    if Result <> nil then
      FillChar(Result^, Size, 0);
  end;
end;

function MM_ReAllocMem(var P: Pointer; Size: SizeUInt): Pointer;
begin
  Result := GOldManager.ReAllocMem(P, Size);
end;

function MM_FreeMem(P: Pointer): SizeUInt;
begin
  if P <> nil then
    Result := GOldManager.FreeMem(P)
  else
    Result := 0;
end;

function MM_FreeMemSize(P: Pointer; Size: SizeUInt): SizeUInt;
begin
  if P = nil then
    Exit(0);
  if Assigned(GOldManager.FreeMemSize) then
    Result := GOldManager.FreeMemSize(P, Size)
  else
    Result := GOldManager.FreeMem(P);
end;

function MM_MemSize(P: Pointer): SizeUInt;
begin
  if (P = nil) or (not Assigned(GOldManager.MemSize)) then
    Exit(0);
  Result := GOldManager.MemSize(P);
end;

procedure MM_InitThread; begin end;
procedure MM_DoneThread; begin end;
procedure MM_RelocateHeap; begin end;

function MM_GetHeapStatus: THeapStatus;
begin
  if Assigned(GOldManager.GetHeapStatus) then
    Result := GOldManager.GetHeapStatus()
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function MM_GetFPCHeapStatus: TFPCHeapStatus;
begin
  if Assigned(GOldManager.GetFPCHeapStatus) then
    Result := GOldManager.GetFPCHeapStatus()
  else
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
begin
  GManagerLock.Acquire;
  try
    if GInstalled then
      Exit;
    System.GetMemoryManager(GOldManager);
    System.SetMemoryManager(GRtlManager);
    GInstalled := True;
  finally
    GManagerLock.Release;
  end;
end;

procedure UninstallRtlMemoryManager;
begin
  GManagerLock.Acquire;
  try
    if not GInstalled then
      Exit;
    System.SetMemoryManager(GOldManager);
    GInstalled := False;
  finally
    GManagerLock.Release;
  end;
end;

function IsRtlMemoryManagerInstalled: Boolean;
begin
  Result := GInstalled;
end;

initialization
  GManagerLock.Init;

finalization
  GManagerLock.Done;

end.
