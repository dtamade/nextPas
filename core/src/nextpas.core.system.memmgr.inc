{**
 * @desc Memory manager interface for the nextPas system kernel.
 *
 * Defines TMemoryManager, TMemoryManagerEx records and
 * GetMemoryManager/SetMemoryManager functions.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are provided by FPC System.
 *}

type
  { Memory manager callback types }
  TGetMem = function(Size: SizeInt): Pointer;
  TFreeMem = function(P: Pointer): SizeInt;
  TFreeMemSize = function(P: Pointer; Size: SizeInt): SizeInt;
  TAllocMem = function(Size: SizeInt): Pointer;
  TReAllocMem = function(P: Pointer; Size: SizeInt): Pointer;
  TMemSize = function(P: Pointer): SizeInt;
  TGetHeapStatus = function: THeapStatus;
  TGetFPCHeapStatus = function: TFPCHeapStatus;

  { Memory manager record }
  TMemoryManager = record
    NeedLock: Boolean;
    GetMem: TGetMem;
    FreeMem: TFreeMem;
    FreeMemSize: TFreeMemSize;
    AllocMem: TAllocMem;
    ReAllocMem: TReAllocMem;
    MemSize: TMemSize;
    InitThread: procedure;
    DoneThread: procedure;
    RelocateHeap: procedure;
    GetHeapStatus: TGetHeapStatus;
    GetFPCHeapStatus: TGetFPCHeapStatus;
  end;
  PMemoryManager = ^TMemoryManager;

  { Extended memory manager record }
  TMemoryManagerEx = record
    Version: LongInt;
    NeedLock: Boolean;
    GetMem: TGetMem;
    FreeMem: TFreeMem;
    FreeMemSize: TFreeMemSize;
    AllocMem: TAllocMem;
    ReAllocMem: TReAllocMem;
    MemSize: TMemSize;
    InitThread: procedure;
    DoneThread: procedure;
    RelocateHeap: procedure;
    GetHeapStatus: TGetHeapStatus;
    GetFPCHeapStatus: TGetFPCHeapStatus;
  end;
  PMemoryManagerEx = ^TMemoryManagerEx;

  { Heap status records }
  THeapStatus = record
    TotalAddrSpace: SizeUInt;
    TotalUncommitted: SizeUInt;
    TotalCommitted: SizeUInt;
    TotalAllocated: SizeUInt;
    TotalFree: SizeUInt;
    FreeSmall: SizeUInt;
    FreeBig: SizeUInt;
    Unused: SizeUInt;
    MaxUsed: SizeUInt;
    MaxFreeSize: SizeUInt;
  end;

  TFPCHeapStatus = record
    CurrHeapSize: SizeUInt;
    CurrHeapFree: SizeUInt;
    CurrHeapUsed: SizeUInt;
    MaxHeapSize: SizeUInt;
    MaxHeapUsed: SizeUInt;
  end;

{ Memory manager functions }
procedure GetMemoryManager(var AMemMgr: TMemoryManager);
procedure SetMemoryManager(const AMemMgr: TMemoryManager);
function IsMemoryManagerSet: Boolean;

implementation

var
  { Internal memory manager instance }
  InternalMemoryManager: TMemoryManager;
  MemoryManagerSet: Boolean = False;

procedure GetMemoryManager(var AMemMgr: TMemoryManager);
begin
  AMemMgr := InternalMemoryManager;
end;

procedure SetMemoryManager(const AMemMgr: TMemoryManager);
begin
  InternalMemoryManager := AMemMgr;
  MemoryManagerSet := True;
end;

function IsMemoryManagerSet: Boolean;
begin
  Result := MemoryManagerSet;
end;
