unit nextpas.core.http.mem;
{**
 * @desc HTTP request-scoped memory helpers backed by nextpas.core.mem.
 *
 * Uses fine-grained mem units only (not the mem facade) to avoid polluting
 * the HTTP unit graph with mem re-exports / overload collisions.
 *
 * Handlers allocate short-lived scratch from a request arena, then drop the
 * arena at request end. Do not FreeMem arena blocks.
 *
 * Long-lived server state: HttpProcessHeap / HttpProcessAllocator.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.allocator.growing;

type
  { Re-export for HTTP facade signatures (avoid forcing consumers onto mem facade). }
  IArena = nextpas.core.mem.arena.intf.IArena;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TGrowingAllocator = nextpas.core.mem.allocator.growing.TGrowingAllocator;

const
  {** Default capacity for per-request LocalArena (256 KiB). }
  HTTP_DEFAULT_REQUEST_ARENA = 256 * 1024;

{** Per-request IArena (TLocalArena). Caller drops interface at request end. }
function HttpCreateRequestArena(ACapacity: SizeUInt = 0): IArena;

{** Per-request IAllocator over LocalArena (FreeMem is no-op; drop at request end). }
function HttpCreateRequestAllocator(ACapacity: SizeUInt = 0): IAllocator;

{** Process hot-path heap alias for long-lived HTTP server state. }
function HttpProcessHeap: TGrowingAllocator; inline;

{** Process IAllocator plug-in surface (collections / inject / DEBUG). }
function HttpProcessAllocator: IAllocator; inline;

{** Process DefaultHeap one-line snapshot for ops/debug endpoints (not hot). }
function HttpFormatProcessMemStats: string;

implementation

uses
  nextpas.core.mem.arena.local,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.default;

function HttpCreateRequestArena(ACapacity: SizeUInt): IArena;
begin
  if ACapacity = 0 then
    ACapacity := HTTP_DEFAULT_REQUEST_ARENA;
  Result := TLocalArena.Create(ACapacity);
end;

function HttpCreateRequestAllocator(ACapacity: SizeUInt): IAllocator;
begin
  if ACapacity = 0 then
    ACapacity := HTTP_DEFAULT_REQUEST_ARENA;
  Result := TLocalArenaAllocator.Create(ACapacity);
end;

function HttpProcessHeap: TGrowingAllocator;
begin
  Result := DefaultHeap;
end;

function HttpProcessAllocator: IAllocator;
begin
  Result := DefaultAllocator;
end;

function HttpFormatProcessMemStats: string;
begin
  Result := FormatMemStats;
end;

end.
