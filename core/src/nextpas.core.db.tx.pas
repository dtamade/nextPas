unit nextpas.core.db.tx;

{** @desc 泛化事务助手：对任意实现 IDbTxControl 的统一连接提供
       WithTransaction。语义照搬 db.sqlite.tx（两后端一致）：

       - 成功自动 COMMIT；异常自动 ROLLBACK 并重抛原异常。
       - 计数式嵌套：内层 Begin 只加深计数，内层 Commit 只降计数，
         最外层 Commit/Rollback 决定一切；外层回滚时内层已"提交"
         的内容一并撤销。
       - 内层失败只恢复计数、由最外层定夺——回调内捕获内层异常后
         可继续外层事务（savepoint 式部分保留不在统一层承诺）。
         例外：内层已整事务回滚清账时，外层提交会得到明确错误。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  TDbTxProc = reference to procedure;

  { 原子执行 AProc：成功自动提交；异常自动回滚并重抛。嵌套安全。 }
  procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc);

implementation

procedure WithTransaction(const AConn: IDbConnection; const AProc: TDbTxProc);
var
  Tx: IDbTxControl;
  LPrev: Integer;
begin
  if AConn = nil then
    raise EDbError.CreateSimple(dbkSqlite, 'WithTransaction on a nil connection');
  if AProc = nil then
    raise EDbError.CreateSimple(AConn.Kind, 'nil transaction callback');
  if AConn.QueryInterface(IDbTxControl, Tx) <> 0 then
    raise EDbError.CreateSimple(AConn.Kind,
      'backend does not support transaction control');

  LPrev := Tx.TxDepth;
  { BeginTxn 在已有事务上自动加深计数（两后端语义一致）。 }
  Tx.BeginTxn(False);
  try
    AProc();
    Tx.CommitTxn;             { 内层 = 只降计数；最外层 = 真 COMMIT }
  except
    if LPrev = 0 then
    begin
      { 最外层失败：整事务回滚并清账。内层失败可能已提前清账，
        InTransaction 守卫避免重复回滚替换原异常。 }
      if Tx.InTransaction then
        Tx.RollbackTxn;
    end
    else
      Tx.RestoreDepth(LPrev); { 内层"提交"= 恢复外层计数，由外层定夺 }
    raise;
  end;
end;

end.
