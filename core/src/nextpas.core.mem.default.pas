unit nextpas.core.mem.default;
{**
 * Default dual-track (STDLIB-QUALITY-PLAN §4.2 D1)
 *
 *   DefaultHeap      — hot path: TGrowingAllocator singleton (direct calls)
 *   DefaultAllocator — IAllocator plug-in surface (currently RTL)
 *
 * Framework hot paths must use DefaultHeap / process GetMem wrappers, not
 * IAllocator virtual dispatch. IAllocator remains for composers, diagnostics,
 * and external injection.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.growing;

{** IAllocator plug-in default (RTL backend). Not the process hot-path heap. }
function DefaultAllocator: IAllocator;

{** Process hot-path heap: Growing singleton (concrete type, no interface). }
function DefaultHeap: TGrowingAllocator; inline;

{** Alias of DefaultHeap for discoverability. }
function DefaultGrowingAllocator: TGrowingAllocator; inline;

implementation

uses
  nextpas.core.mem.allocator.foundation;

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.foundation.GetRtlAllocator;
end;

function DefaultHeap: TGrowingAllocator;
begin
  Result := nextpas.core.mem.allocator.growing.DefaultGrowingAllocator;
end;

function DefaultGrowingAllocator: TGrowingAllocator;
begin
  Result := DefaultHeap;
end;

end.
