{
  nextpas.core.mem.mem_pool - Fixed-size Memory Pool (Facade Alias)

  This unit provides TMemPool as an alias for TFixedPool for facade compatibility.
  For new code, prefer using nextpas.core.mem.pool.fixed directly.
}
unit nextpas.core.mem.mem_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.pool.fixed;

type
  // 门面兼容别名 - 新代码建议直接使用 TFixedPool
  TMemPool = TFixedPool;
  TMemPoolConfig = TFixedPoolConfig;

  // 异常类型别名
  EMemPoolError = EMemFixedPoolError;
  EMemPoolInvalidPointer = EMemFixedPoolInvalidPointer;
  EMemPoolDoubleFree = EMemFixedPoolDoubleFree;

implementation

end.
