unit nextpas.core.db.factory.register.redis;

{** @desc Redis 独立驱动自注册单元（按需自注册抽离候选）。
       Side-effect import：uses 本单元即在 initialization 单次
       DbRegisterDriver 注入 redis 驱动（ConnectRedis 需 TDbRedisConnectOptions，
       此处以 TDbConnectOptions 桥接，经 redis.addr 单源解析；BytesFromText
       复用 bytes.ops.StringToBytes 单 Move 零拷贝）。零聚合：仅硬链接 redis.adapter + factory。
       编译期单源守卫：bytes.ops；性能 inline 零拷贝；稳定性接口引用计数自动归还。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.redis.adapter;

const
  FACTORY_REGISTER_REDIS_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: factory.register.redis must reuse bytes.ops'}
{$IFEND}

implementation

uses
  nextpas.core.db.base;

function OpenRedisForRegister(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline 薄转发直连 redis.adapter owner（addr 解析经 redis.addr 单源，BytesFromText bytes.ops 单 Move 零拷贝，AStmtCacheCapacity advisory honest no-op Redis无语句缓存）, 接口引用计数自动归还
  // stability: interface refcount auto, no manual Free; capacity ignored per Redis honest contract (SupportsStmtCacheControl=False) but advisory consistent
  Result := ConnectRedis(ADsn, '', 0, AOptions);
end;

initialization
  DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis, @OpenRedisForRegister));

finalization

end.
