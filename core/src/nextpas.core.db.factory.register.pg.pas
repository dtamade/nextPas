unit nextpas.core.db.factory.register.pg;

{** @desc PG 独立驱动自注册单元（按需自注册抽离候选）。
       Side-effect import：uses 本单元即在 initialization 单次
       DbRegisterDriver 注入 postgres 驱动（TBuiltinDriver 封装
       ConnectPostgres），等价 Go `import _ "driver/pg"`。
       零聚合：仅硬链接 nextpas.core.db.pg.adapter + factory。
       编译期单源守卫：bytes.ops BYTES_OPS_SINGLE_SOURCE；性能 inline
       薄转发/零拷贝；稳定性接口引用计数自动归还；业务以 CONTRACT §2.14 为准。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.pg.adapter;



implementation

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

function OpenPgForRegister(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline 薄转发直连 pg.adapter owner，bytes.ops 单源零拷贝，AStmtCacheCapacity advisory via pg LRU (server prepared), 接口引用计数自动归还
  // stability: interface refcount auto, no manual Free; capacity forwarded to TPgConn/TPgConnection
  Result := ConnectPostgres(ADsn, AOptions, AStmtCacheCapacity);
end;

initialization
  DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres, @OpenPgForRegister));

finalization

end.
