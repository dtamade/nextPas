unit nextpas.core.sqlite;

{** @desc 兼容 shim（2026-08-25 恢复）：旧单元名 → 统一层薄转发。
       G2 曾删除本 shim；应并行项目依赖紧急恢复。仅 re-export
       `nextpas.core.db.sqlite` 现存公开面——v1 TSqlitePool 与
       db.sqlite.migrate 后端专用面已随 G2 退役，不再提供；
       新代码一律 uses nextpas.core.db / nextpas.core.db.sqlite。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite;

type
  ESqliteError = nextpas.core.db.sqlite.ESqliteError;
  TSqliteDb = nextpas.core.db.sqlite.TSqliteDb;
  TSqliteQuery = nextpas.core.db.sqlite.TSqliteQuery;
  ESqliteTxError = nextpas.core.db.sqlite.ESqliteTxError;
  TSqliteTxProc = nextpas.core.db.sqlite.TSqliteTxProc;

const
  SQLITE_OK = nextpas.core.db.sqlite.SQLITE_OK;
  SQLITE_ROW = nextpas.core.db.sqlite.SQLITE_ROW;
  SQLITE_DONE = nextpas.core.db.sqlite.SQLITE_DONE;
  SQLITE_INTEGER = nextpas.core.db.sqlite.SQLITE_INTEGER;
  SQLITE_FLOAT = nextpas.core.db.sqlite.SQLITE_FLOAT;
  SQLITE_TEXT = nextpas.core.db.sqlite.SQLITE_TEXT;
  SQLITE_BLOB = nextpas.core.db.sqlite.SQLITE_BLOB;
  SQLITE_NULL = nextpas.core.db.sqlite.SQLITE_NULL;

function SqliteOpen(const APath: string): TSqliteDb; inline;
procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc); inline;
procedure BeginTxn(const ADb: TSqliteDb;
  const AImmediate: Boolean = False); inline;
procedure CommitTxn(const ADb: TSqliteDb); inline;
procedure RollbackTxn(const ADb: TSqliteDb); inline;
function InTransaction(const ADb: TSqliteDb): Boolean; inline;
function TxDepth(const ADb: TSqliteDb): Integer; inline;

implementation

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := nextpas.core.db.sqlite.SqliteOpen(APath);
end;

procedure WithTransaction(const ADb: TSqliteDb;
  const AProc: TSqliteTxProc);
begin
  nextpas.core.db.sqlite.WithTransaction(ADb, AProc);
end;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
begin
  nextpas.core.db.sqlite.BeginTxn(ADb, AImmediate);
end;

procedure CommitTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.CommitTxn(ADb);
end;

procedure RollbackTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.RollbackTxn(ADb);
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := nextpas.core.db.sqlite.InTransaction(ADb);
end;

function TxDepth(const ADb: TSqliteDb): Integer;
begin
  Result := nextpas.core.db.sqlite.TxDepth(ADb);
end;

end.
