{
  nextpas.core.mem.mem_pool

  Deprecated compatibility shim forwarding to nextpas.core.mem.compat.
  For new code, prefer nextpas.core.mem.pool.fixed directly.
}
unit nextpas.core.mem.mem_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.compat;

type
  TMemPool = nextpas.core.mem.compat.TMemPool deprecated 'Use nextpas.core.mem.compat.TMemPool instead';
  TMemPoolConfig = nextpas.core.mem.compat.TMemPoolConfig deprecated 'Use nextpas.core.mem.compat.TMemPoolConfig instead';
  EMemPoolError = nextpas.core.mem.compat.EMemPoolError deprecated 'Use nextpas.core.mem.compat.EMemPoolError instead';
  EMemPoolInvalidPointer = nextpas.core.mem.compat.EMemPoolInvalidPointer deprecated 'Use nextpas.core.mem.compat.EMemPoolInvalidPointer instead';
  EMemPoolDoubleFree = nextpas.core.mem.compat.EMemPoolDoubleFree deprecated 'Use nextpas.core.mem.compat.EMemPoolDoubleFree instead';

{$WARNING 'nextpas.core.mem.mem_pool is deprecated: use nextpas.core.mem.compat'}

implementation

end.
