unit nextpas.core.db.tx.template;

{** @desc L2 事务模板（统一 savepoint 混合模型单源）。
       收口 nextpas.core.db.tx RunTransaction 与 nextpas.core.db.bulk BulkFlushCore
       的同构 savepoint→chunk→release / Begin→chunk→Commit 模板（L2 infra，零上向）。
       性能：inline 薄转发、bytes.ops 单源、单分配零拷贝经 db.savepoint 单源（TBufStringBuilder 零拷贝），零额外堆分配；
       稳定性：try..except 嵌套吞 release/rollback 异常不覆盖原异常，资源经接口引用计数/栈对象不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base;

type
  TDbTemplateExecProc = procedure(const ASql: string) of object;
  TDbTemplateBeginProc = procedure(const AImmediate: Boolean) of object;
  TDbTemplateVoidProc = procedure of object;
  TDbTemplateStepProc = procedure of object;

{ 统一模板：savepoint 分支（ASupportsSavepoints=True 时 SAVEPOINT/COMMIT 分支，False 直跑）与外层事务分支。
  语义与 db.tx RunTransaction savepoint 混合模型同构（成功 RELEASE 并入父事务，失败 ROLLBACK TO+RELEASE，清理异常吞并 raise 原异常），
  外层非事务时 BeginTxn(False)→Step→Commit 失败回滚。方言分支经 db.savepoint 单源（DbReleaseSqlFor/DbRollbackToSqlFor inline 薄转发，bytes.ops 单源）。 }
procedure DbTemplateRunWithSavepointFallback(
  const AInTxn, ASupportsSavepoints: Boolean;
  const ASavepointName: string;
  const ABackend: TDbKind;
  const AExec: TDbTemplateExecProc;
  const ABeginTxn: TDbTemplateBeginProc;
  const ACommitTxn, ARollbackTxn: TDbTemplateVoidProc;
  const AStep: TDbTemplateStepProc);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.savepoint;



procedure DbTemplateRunWithSavepointFallback(
  const AInTxn, ASupportsSavepoints: Boolean;
  const ASavepointName: string;
  const ABackend: TDbKind;
  const AExec: TDbTemplateExecProc;
  const ABeginTxn: TDbTemplateBeginProc;
  const ACommitTxn, ARollbackTxn: TDbTemplateVoidProc;
  const AStep: TDbTemplateStepProc);
begin
  if AInTxn then
  begin
    if ASupportsSavepoints then
    begin
      AExec(DbSavepointSql(ASavepointName));
      try
        AStep();
        try AExec(DbReleaseSqlFor(ABackend, ASavepointName)); except end;
      except
        try AExec(DbRollbackToSqlFor(ABackend, ASavepointName)); except end;
        try AExec(DbReleaseSqlFor(ABackend, ASavepointName)); except end;
        raise;
      end;
    end
    else
      AStep();
  end
  else
  begin
    ABeginTxn(False);
    try
      AStep();
      ACommitTxn();
    except
      try ARollbackTxn(); except end;
      raise;
    end;
  end;
end;

end.
