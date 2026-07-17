unit nextpas.core.mem.allocator.growing_ia;
{**
 * IAllocator adapter over DefaultHeap (TGrowingAllocator process singleton).
 *
 * Purpose (S5):
 *   Collections and other IAllocator injectors call DefaultAllocator with
 *   FreeMem(ptr) / ReallocMem(ptr, size). They cannot call Growing native
 *   FreeMem(ptr, size) without a rewrite. This adapter makes the *plugin*
 *   default allocate from the same heap as DefaultHeap / process GetMem.
 *
 * Dual-track preserved:
 *   - DefaultHeap / GetMem  — direct Growing (no interface) = true hot path
 *   - DefaultAllocator      — this adapter ± NEXTPAS_MEM_DEBUG wraps
 *
 * Does NOT replace GetRtlAllocator (bootstrap / explicit RTL still available).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf;

type
  {** Thin IAllocator front for DefaultHeap. Singleton via GetGrowingIAllocator. }
  TGrowingIAllocator = class(TInterfacedObject, IAllocator)
  public
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
  end;

{** Process IAllocator default root (same heap as DefaultHeap). }
function GetGrowingIAllocator: IAllocator;

{** nil → GetGrowingIAllocator; else identity. Prefer over ResolveAllocator(RTL). }
function ResolveProcessAllocator(const AAllocator: IAllocator): IAllocator;

implementation

uses
  nextpas.core.platform.sync,
  nextpas.core.mem.allocator.growing;

var
  GObj: TInterfacedObject = nil;
  GIntf: IAllocator = nil;
  GLock: TPlatformMutex;

function Heap: TGrowingAllocator; inline;
begin
  Result := DefaultGrowingAllocator;
end;

function TGrowingIAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  Result := Heap.GetMem(ASize);
end;

function TGrowingIAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := Heap.AllocMem(ASize);
end;

function TGrowingIAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  { Prefer process-shaped single-size form; Growing scans or routes internally. }
  Result := Heap.ReallocMem(APtr, ASize);
end;

procedure TGrowingIAllocator.FreeMem(APtr: Pointer);
begin
  Heap.FreeMem(APtr);
end;

function TGrowingIAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
  Result.SupportsRealloc := True;
end;

function GetGrowingIAllocator: IAllocator;
begin
  if GObj = nil then
  begin
    platform_mutex_lock(GLock);
    try
      if GObj = nil then
      begin
        GObj := TGrowingIAllocator.Create;
        GIntf := GObj as IAllocator;
      end;
    finally
      platform_mutex_unlock(GLock);
    end;
  end;
  Result := GIntf;
end;

function ResolveProcessAllocator(const AAllocator: IAllocator): IAllocator;
begin
  if AAllocator <> nil then
    Result := AAllocator
  else
    Result := GetGrowingIAllocator;
end;

finalization
  GIntf := nil;
  GObj := nil;

end.
