unit nextpas.core.sqlite.tx;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.sqlite.tx。
       新代码请使用 nextpas.core.db.* 家族（统一事务入口见
       nextpas.core.db.tx / nextpas.core.db 门面）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.tx;

type
  ESqliteTxError = nextpas.core.db.sqlite.tx.ESqliteTxError;
  TSqliteTxProc  = nextpas.core.db.sqlite.tx.TSqliteTxProc;

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean = False); inline;
procedure CommitTxn(const ADb: TSqliteDb); inline;
procedure RollbackTxn(const ADb: TSqliteDb); inline;
function InTransaction(const ADb: TSqliteDb): Boolean; inline;
function TxDepth(const ADb: TSqliteDb): Integer; inline;
procedure WithTransaction(const ADb: TSqliteDb; const AProc: TSqliteTxProc); inline;

implementation

procedure BeginTxn(const ADb: TSqliteDb; const AImmediate: Boolean);
begin
  nextpas.core.db.sqlite.tx.BeginTxn(ADb, AImmediate);
end;

procedure CommitTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.tx.CommitTxn(ADb);
end;

procedure RollbackTxn(const ADb: TSqliteDb);
begin
  nextpas.core.db.sqlite.tx.RollbackTxn(ADb);
end;

function InTransaction(const ADb: TSqliteDb): Boolean;
begin
  Result := nextpas.core.db.sqlite.tx.InTransaction(ADb);
end;

function TxDepth(const ADb: TSqliteDb): Integer;
begin
  Result := nextpas.core.db.sqlite.tx.TxDepth(ADb);
end;

procedure WithTransaction(const ADb: TSqliteDb; const AProc: TSqliteTxProc);
begin
  nextpas.core.db.sqlite.tx.WithTransaction(ADb, AProc);
end;

end.
