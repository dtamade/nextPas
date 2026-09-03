unit nextpas.core.db.factory.register.sqlite;

{** @desc SQLite 显式驱动注册单元（零 initialization 侧效，对齐 factory.builtin 理想）。
       显式注入：uses 本单元后调用 RegisterSqliteDriver 单次
       DbRegisterDriver 注入 sqlite 驱动（TBuiltinDriver 封装
       ConnectSqlite），消除 initialization 隐式加载顺序耦合，等价
       Go `Register` 显式形态而非 `import _` 隐式。
       零聚合：仅硬链接 nextpas.core.db.sqlite.adapter + factory，
       不引入其余五后端；裁剪边界 = 按需 uses 本单元后显式注册，或
       直连 nextpas.core.db.sqlite.adapter 的 ConnectSqlite 自行封装。
       编译期单源守卫：bytes.ops BYTES_OPS_SINGLE_SOURCE 哨兵；
       性能 inline 薄转发/零拷贝（ConnectSqlite 单 Move，经 bytes.ops 单源）；
       稳定性接口引用计数自动归还，重复注册 fail-closed 不丢资源；
       业务以 CONTRACT §2.14 为准，缺能力先反哺 adapter/bytes.ops owner。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.sqlite.adapter;

const
  FACTORY_REGISTER_SQLITE_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: factory.register.sqlite must reuse bytes.ops'}
{$IFEND}

procedure RegisterSqliteDriver;

implementation

uses
  nextpas.core.db.base;

function OpenSqliteForRegister(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline 薄转发直连 sqlite.adapter owner，bytes.ops 单源零拷贝，AStmtCacheCapacity advisory via adapter LRU (single Move zero-copy), 接口引用计数自动归还
  // stability: interface refcount auto, no manual Free; capacity forwarded to TDbSqliteConnection LRU
  Result := ConnectSqlite(ADsn, AOptions, AStmtCacheCapacity);
end;

procedure RegisterSqliteDriver;
begin
  // stability: DbRegisterDriver 接口引用计数托管，重复注册 fail-closed 抛 EDbError，不丢资源
  DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite, @OpenSqliteForRegister));
end;

end.
