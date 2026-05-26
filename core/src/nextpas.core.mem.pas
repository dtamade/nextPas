unit nextpas.core.mem;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.arena,
  nextpas.core.mem.pool;

type
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TArenaMarker = nextpas.core.mem.base.TArenaMarker;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TArena = nextpas.core.mem.arena.TArena;
  TPool = nextpas.core.mem.pool.TPool;

function DefaultAllocator: IAllocator; inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

end.
