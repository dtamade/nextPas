unit nextpas.core.db.factory.register.mysql;

{** @desc MySQL 独立驱动自注册单元（按需自注册抽离候选）。
       Side-effect import：uses 本单元即在 initialization 单次
       DbRegisterDriver 注入 mysql 驱动（TBuiltinDriver 封装
       ConnectMysql）。零聚合：仅硬链接 mysql.adapter + factory。
       编译期单源守卫：bytes.ops；性能 inline 零拷贝；稳定性接口引用计数自动归还。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.mysql.adapter;

const
  FACTORY_REGISTER_MYSQL_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: factory.register.mysql must reuse bytes.ops'}
{$IFEND}

implementation

uses
  nextpas.core.db.base;

function OpenMysqlForRegister(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline 薄转发直连 mysql.adapter owner，bytes.ops 单源零拷贝，AStmtCacheCapacity advisory (honest no-op, SupportsStmtCacheControl=False), 接口引用计数自动归还
  // stability: interface refcount auto, no manual Free; capacity ignored per backend honest contract but advisory consistent
  Result := ConnectMysql(ADsn, AOptions, AStmtCacheCapacity);
end;

initialization
  DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql, @OpenMysqlForRegister));

finalization

end.
