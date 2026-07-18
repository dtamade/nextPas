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
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.allocator.callback;

type
  IAllocator = nextpas.core.mem.allocator.base.IAllocator;
  TMemAllocator = nextpas.core.mem.allocator.base.TMemAllocator;

  TGetMemCallback = nextpas.core.mem.allocator.callback.TGetMemCallback;
  TAllocMemCallback = nextpas.core.mem.allocator.callback.TAllocMemCallback;
  TReallocMemCallback = nextpas.core.mem.allocator.callback.TReallocMemCallback;
  TFreeMemCallback = nextpas.core.mem.allocator.callback.TFreeMemCallback;

  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  TGrowingIAllocator = nextpas.core.mem.allocator.growing_ia.TGrowingIAllocator;
  TCallbackAllocator = nextpas.core.mem.allocator.callback.TCallbackAllocator;

function GetRtlAllocator: IAllocator;
{** Process IAllocator default root (same heap as DefaultHeap). S5. }
function GetGrowingIAllocator: IAllocator;
function ResolveAllocator(const AAllocator: IAllocator): IAllocator;
function ResolveProcessAllocator(const AAllocator: IAllocator): IAllocator;
function CreateCallbackAllocator(aGetMem: TGetMemCallback;
                                 aAllocMem: TAllocMemCallback;
                                 aReallocMem: TReallocMemCallback;
                                 aFreeMem: TFreeMemCallback): TCallbackAllocator;

implementation

function GetRtlAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl.GetRtlAllocator;
end;

function GetGrowingIAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.growing_ia.GetGrowingIAllocator;
end;

function ResolveAllocator(const AAllocator: IAllocator): IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl.ResolveAllocator(AAllocator);
end;

function ResolveProcessAllocator(const AAllocator: IAllocator): IAllocator;
begin
  Result := nextpas.core.mem.allocator.growing_ia.ResolveProcessAllocator(AAllocator);
end;

function CreateCallbackAllocator(aGetMem: TGetMemCallback;
  aAllocMem: TAllocMemCallback; aReallocMem: TReallocMemCallback; aFreeMem: TFreeMemCallback): TCallbackAllocator;
begin
  Result := nextpas.core.mem.allocator.callback.CreateCallbackAllocator(aGetMem, aAllocMem, aReallocMem, aFreeMem);
end;

end.
