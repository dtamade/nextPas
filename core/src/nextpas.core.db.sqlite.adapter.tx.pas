unit nextpas.core.db.sqlite.adapter.tx;

{** @desc SQLite 事务簿记分治（L3 实现子模块）。
       封装 Begin/Commit/Rollback/InTransaction/TxDepth 的深度计数
       与 autocommit 守卫（收敛至 db.tx owner 单源，零经 db.sqlite.tx
       全局簿记直调；计数语义对齐 pg/mysql 家族，L3→L2 严格下向）。
       层级：L3 适配子模块（严格下向 L2 sqlite.base/conn/ffi + L1
       sync/bytes.ops，单向被 adapter 依赖，无环）。
       性能：FLock 护簿记 inline 薄转发，autocommit 守卫零分配，
       bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE 门禁。
       稳定性：Exec 在锁外（避全局锁持 SQL），失败不增计数，
       FLock:=nil 不丢，RLLBACK 失败吞掉保 FDepth 清零。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.sqlite.conn,
  nextpas.core.sync;

type
  TSqliteTx = class
  private
    FDb: TSqliteDb;
    FLock: INativeMutex;
    FDepth: Integer;
  public
    constructor Create(ADb: TSqliteDb);
    destructor Destroy; override;
    procedure BeginTxn(const AImmediate: Boolean);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean; inline;
    function TxDepth: Integer; inline;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.base,
  nextpas.core.db.sqlite.ffi,
  nextpas.core.db.sqlite.adapter.observe;


constructor TSqliteTx.Create(ADb: TSqliteDb);
begin
  inherited Create;
  FDb := ADb;
  FLock := nextpas.core.sync.Mutex;
  FDepth := 0;
end;

destructor TSqliteTx.Destroy;
begin
  FLock := nil;
  inherited Destroy;
end;

procedure TSqliteTx.BeginTxn(const AImmediate: Boolean);
begin
  // perf: inline 薄转发自持计数（零经 db.sqlite.tx 全局簿记直调；L3→L2 严格下向，
  // 收敛至 db.tx owner 单源；autocommit 守卫 inline 零额外分配，bytes.ops 单源）
  // stability: FLock 护簿记，Exec 在锁外（避全局锁持 SQL），失败不增计数，析构 FLock:=nil 不丢
  FLock.Acquire;
  try
    if FDepth > 0 then
    begin
      Inc(FDepth);
      Exit;
    end;
    if sqlite3_get_autocommit(FDb.Handle) = 0 then
      raise EDbError.CreateSimple(dbkSqlite,
        'a transaction is already open on this connection outside the tx helper; ' +
        'route all transaction control through BeginTxn/WithTransaction');
  finally
    FLock.Release;
  end;
  try
    if AImmediate then
      FDb.Exec('BEGIN IMMEDIATE')
    else
      FDb.Exec('BEGIN');
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
  FLock.Acquire;
  try
    Inc(FDepth);
  finally
    FLock.Release;
  end;
end;

procedure TSqliteTx.CommitTxn;
begin
  // perf: inline 薄转发计数（对齐 pg/mysql 家族，L3 自持，零全局簿记；bytes.ops 单源）
  // stability: 失败保留计数以便调用方 Rollback 收拾；FDepth 读写均持 FLock，析构不丢
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkSqlite,
        'CommitTxn without a matching BeginTxn on this connection');
    if FDepth > 1 then
    begin
      Dec(FDepth);
      Exit;
    end;
    if sqlite3_get_autocommit(FDb.Handle) <> 0 then
      raise EDbError.CreateSimple(dbkSqlite,
        'transaction was closed outside the tx helper; commit aborted');
  finally
    FLock.Release;
  end;
  try
    FDb.Exec('COMMIT');
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
  FLock.Acquire;
  try
    if FDepth > 0 then
      FDepth := 0;
  finally
    FLock.Release;
  end;
end;

procedure TSqliteTx.RollbackTxn;
begin
  // perf: inline 薄转发（任意深度回滚整个事务并清计数，对齐 pg V2-S2；bytes.ops 单源）
  // stability: ROLLBACK 失败吞掉（服务端可能已中止），FDepth 始终清零，FDb 释放不丢
  FLock.Acquire;
  try
    if FDepth = 0 then
      raise EDbError.CreateSimple(dbkSqlite,
        'RollbackTxn without a matching BeginTxn on this connection');
    if sqlite3_get_autocommit(FDb.Handle) <> 0 then
    begin
      FDepth := 0;
      Exit;
    end;
  finally
    FLock.Release;
  end;
  try
    FDb.Exec('ROLLBACK');
  except
    // 吞掉：原事务已不可恢复，保留原异常由调用方重抛（WithTransaction 语义）
  end;
  FLock.Acquire;
  try
    FDepth := 0;
  finally
    FLock.Release;
  end;
end;

function TSqliteTx.InTransaction: Boolean; inline;
begin
  // perf: inline 零拷贝读 FDepth（FLock 轻量，单源 bytes.ops 门禁已守卫）
  FLock.Acquire;
  try
    Result := FDepth > 0;
  finally
    FLock.Release;
  end;
end;

function TSqliteTx.TxDepth: Integer; inline;
begin
  // perf: inline 零拷贝读 FDepth（FLock 护簿记，对齐 pg/mysql 家族单源）
  FLock.Acquire;
  try
    Result := FDepth;
  finally
    FLock.Release;
  end;
end;

end.
