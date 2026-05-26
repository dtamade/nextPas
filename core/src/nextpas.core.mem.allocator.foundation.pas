{
# nextpas.core.mem.allocator.foundation

Low-level allocator convenience facade.

This unit re-exports the allocator contract together with the small concrete
backends that remain convenient for the mem domain, but it is no longer the
strict L0 source-of-truth boundary.
}

unit nextpas.core.mem.allocator.foundation;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.rtl_allocator,
  nextpas.core.mem.allocator.callback_allocator;

type
  IAllocator = nextpas.core.mem.allocator.base.IAllocator;
  TAllocator = nextpas.core.mem.allocator.base.TAllocator;

  TGetMemCallback = nextpas.core.mem.allocator.callback_allocator.TGetMemCallback;
  TAllocMemCallback = nextpas.core.mem.allocator.callback_allocator.TAllocMemCallback;
  TReallocMemCallback = nextpas.core.mem.allocator.callback_allocator.TReallocMemCallback;
  TFreeMemCallback = nextpas.core.mem.allocator.callback_allocator.TFreeMemCallback;

  TRtlAllocator = nextpas.core.mem.allocator.rtl_allocator.TRtlAllocator;
  TCallbackAllocator = nextpas.core.mem.allocator.callback_allocator.TCallbackAllocator;

function GetRtlAllocator: IAllocator;
function CreateCallbackAllocator(aGetMem: TGetMemCallback;
                                 aAllocMem: TAllocMemCallback;
                                 aReallocMem: TReallocMemCallback;
                                 aFreeMem: TFreeMemCallback): TCallbackAllocator;

implementation

function GetRtlAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl_allocator.GetRtlAllocator;
end;

function CreateCallbackAllocator(aGetMem: TGetMemCallback;
  aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback): TCallbackAllocator;
begin
  Result := nextpas.core.mem.allocator.callback_allocator.CreateCallbackAllocator(aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

end.
