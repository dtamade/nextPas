unit nextpas.core.db.factory.register.dm;

{** @desc DM 独立驱动自注册单元（按需自注册抽离候选）。
       Side-effect import：uses 本单元即在 initialization 单次
       DbRegisterDriver 注入 dm 驱动（TBuiltinDriver 封装 ConnectDm）。
       零聚合：仅硬链接 dm.adapter + factory。编译期单源守卫：bytes.ops；
       性能 inline 零拷贝；稳定性接口引用计数自动归还。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.dm.adapter;



implementation

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

function OpenDmForRegister(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline 薄转发直连 dm.adapter owner，bytes.ops 单源零拷贝，AStmtCacheCapacity advisory via DM LRU, 接口引用计数自动归还
  // stability: interface refcount auto, no manual Free; capacity forwarded to TDbDmConnection LRU
  Result := ConnectDm(ADsn, AOptions, AStmtCacheCapacity);
end;

initialization
  DbRegisterDriver(TBuiltinDriver.Create('dm', dbkDm, @OpenDmForRegister));

finalization

end.
