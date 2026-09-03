unit nextpas.core.db.sqlite.adapter.factory;

{** @desc SQLite 连接工厂分治（L3 实现子模块）。
       封装 TSqliteDb 创建 + busy_timeout 单次 PRAGMA + C5 调优
       受控面（ApplySqlitePragmas），供 adapter 门面薄转发。
       层级：L3 适配子模块（严格下向 L2 sqlite.conn/base + L1
       text.builder/bytes.ops，单向被 adapter 依赖，无环）。
       性能：TBufStringBuilder 单次分配单 Move 零拷贝（预估 32 字节，
       AppendInt 单次格式化零临时串），inline 薄转发，
       BYTES_OPS_SINGLE_SOURCE 门禁。
       稳定性：try..finally LB.Done 归还，Db.Free 不丢，错误经
       RaiseSqliteAsDb 统一转 EDbError 单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

function NewSqliteDb(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas): TSqliteDb;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.builder,
  nextpas.core.db.sqlite.adapter.observe,
  nextpas.core.db.sqlite.adapter.pragmas;


function NewSqliteDb(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas): TSqliteDb;
var
  Db: TSqliteDb;
  LB: TBufStringBuilder;
begin
  // perf: TBufStringBuilder 单次分配单 Move 零拷贝（AppendInt 零临时 via IntToBuffer direct tail，经统一辅助 BuilderCapWithMin/BuilderCapForTwo 单源，bytes.ops 单源 inline/零拷贝，消除分散手写 32），bytes.ops 单源 inline/零拷贝；stability: try..finally LB.Done/Db.Free 不丢，校验 fail-closed
  try
    Db := TSqliteDb.Create(APath);
    if AOptions.BusyTimeoutMs > 0 then
    begin
      LB.Init(BuilderCapWithMin(BuilderCapForTwo(SizeUInt(Length('PRAGMA busy_timeout = ')), 12)));
      try
        LB.AppendStr('PRAGMA busy_timeout = ');
        LB.AppendInt(AOptions.BusyTimeoutMs);
        Db.Exec(LB.ToString);
      finally
        LB.Done;
      end;
    end;
    ApplySqlitePragmas(Db, APath, APragmas);
    Result := Db;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

end.
