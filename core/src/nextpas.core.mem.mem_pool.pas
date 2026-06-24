{
  nextpas.core.mem.mem_pool - Fixed-size Memory Pool (Facade Alias)

  DEPRECATED: This unit is a compatibility alias.
  For new code, use nextpas.core.mem.pool.fixed directly.
}
unit nextpas.core.mem.mem_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.pool.fixed;

type
  TMemPool = TFixedPool
    deprecated 'Use TFixedPool from nextpas.core.mem.pool.fixed';
  TMemPoolConfig = TFixedPoolConfig
    deprecated 'Use TFixedPoolConfig';

  EMemPoolError = EMemFixedPoolError
    deprecated 'Use EMemFixedPoolError';
  EMemPoolInvalidPointer = EMemFixedPoolInvalidPointer
    deprecated 'Use EMemFixedPoolInvalidPointer';
  EMemPoolDoubleFree = EMemFixedPoolDoubleFree
    deprecated 'Use EMemFixedPoolDoubleFree';

implementation

end.
