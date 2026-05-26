unit nextpas.core.mem.mimalloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.mimalloc.ffi;

type
  {**
   * @desc mimalloc 高性能分配器，实现 IAllocator
   * @note 线程安全（mimalloc 内部处理）
   *}
  TMimallocAllocator = class(TInterfacedObject, IAllocator)
  public
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
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

{ TMimallocAllocator }

function TMimallocAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := mi_malloc(ASize);
end;

function TMimallocAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := mi_realloc(APtr, ANewSize);
end;

procedure TMimallocAllocator.Deallocate(const APtr: Pointer);
begin
  mi_free(APtr);
end;

end.
