unit nextpas.core.mem.mimalloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.mimalloc.ffi;

type
  {**
   * @desc mimalloc 高性能分配器，实现 IAllocator
   * @note 线程安全（mimalloc 内部处理）
   *}
  TMimallocAllocator = class(TAllocator)
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits; override;
  end;

function MimallocAllocator: IAllocator;

implementation

var
  GMimallocAllocator: IAllocator = nil;

function MimallocAllocator: IAllocator;
begin
  if GMimallocAllocator = nil then
    GMimallocAllocator := TMimallocAllocator.Create;
  Result := GMimallocAllocator;
end;

function TMimallocAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := mi_malloc(aSize);
end;

function TMimallocAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := mi_calloc(1, aSize);
end;

function TMimallocAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := mi_realloc(aDst, aSize);
end;

procedure TMimallocAllocator.DoFreeMem(aDst: Pointer);
begin
  mi_free(aDst);
end;

function TMimallocAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  if aSize = 0 then
    Exit(nil);
  Result := mi_malloc_aligned(aSize, aAlignment);
end;

procedure TMimallocAllocator.FreeAligned(aPtr: Pointer);
begin
  if aPtr = nil then Exit;
  mi_free(aPtr);
end;

function TMimallocAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := True;
  Result.HasMemSize := True;
  Result.SupportsAligned := True;
end;

end.
