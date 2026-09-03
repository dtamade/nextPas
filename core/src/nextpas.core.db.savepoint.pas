unit nextpas.core.db.savepoint;

{** @desc db 家族共享保存点辅助（L2 基础设施，零上向）。
       收敛四后端 Savepoint/RollbackTo/ReleaseTo 的 Validate+拼串
       样板：ValidateDbSavepointName + prefix 单次 Move 零拷贝
       拼串（TBufStringBuilder 单分配单 Move，bytes.ops 单源）。
       层级：L2 仅下向 L0-L1（base/err + bytes.ops/text.builder），
       被 L3 四适配器单向依赖，零循环；新增模块候选，已单源化。
       性能：DbSavepointSqlOf 非 inline per red line 1（TBufStringBuilder AppendStr 索引元素作 untyped 源禁 inline，避免常量传播污染与 I-Cache 膨胀），caller inline 薄转发，单分配零拷贝（BYTES_OPS_SINGLE_SOURCE
       门禁），零临时串。
       稳定性：纯函数无资源，try..finally LB.Done 不丢，fail-closed Validate 先行。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.err;

{ 单次分配单 Move 零拷贝：prefix + name（TBufStringBuilder 路径，bytes.ops 单源） }
function DbSavepointSqlOf(const APrefix, AName: string): string; // not inline per red line 1: TBufStringBuilder 单分配单 Move 零拷贝，AppendStr 索引元素作 untyped 源禁 inline

{ 便捷形态：SAVEPOINT / ROLLBACK TO / RELEASE 前缀（sqlite/pg/mysql 通用） }
function DbSavepointSql(const AName: string): string; inline;
function DbRollbackToSql(const AName: string): string; inline;
function DbReleaseSql(const AName: string): string; inline;

{ DM 方言：ROLLBACK TO SAVEPOINT / RELEASE SAVEPOINT }
function DbRollbackToSavepointSql(const AName: string): string; inline;
function DbReleaseSavepointSql(const AName: string): string; inline;

{ 方言收敛：MySQL/DM 需 SAVEPOINT 关键字，单源助手消除 bulk 四分支重复 }
function DbReleaseSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
function DbRollbackToSqlFor(const ABackend: TDbKind; const AName: string): string; inline;

{ Validate 后拼串（fail-closed，Validate 先行；单分配零拷贝） }
function DbValidatedSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedRollbackToSql(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedReleaseSql(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedRollbackToSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedReleaseSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedReleaseSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
function DbValidatedRollbackToSqlFor(const ABackend: TDbKind; const AName: string): string; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.builder;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.savepoint must reuse bytes.ops'}
{$IFEND}

function DbSavepointSqlOf(const APrefix, AName: string): string;
var
  LB: TBufStringBuilder;
begin
  // perf: TBufStringBuilder 单次分配单 Move 零拷贝（预分配经统一辅助 TBufEstimateForTwo 单源，bytes.ops BuilderCapForTwo 单源 inline 零拷贝，消除分散手写 Length+Length），not inline per red line 1（索引元素作 untyped 源禁 inline）；caller 薄转发保持 inline 零拷贝
  LB.Init(TBufEstimateForTwo(SizeUInt(Length(APrefix)), SizeUInt(Length(AName))));
  try
    LB.AppendStr(APrefix);
    LB.AppendStr(AName);
    Result := LB.ToString;
  finally
    LB.Done;
  end;
end;

function DbSavepointSql(const AName: string): string; inline;
begin
  Result := DbSavepointSqlOf('SAVEPOINT ', AName);
end;

function DbRollbackToSql(const AName: string): string; inline;
begin
  Result := DbSavepointSqlOf('ROLLBACK TO ', AName);
end;

function DbReleaseSql(const AName: string): string; inline;
begin
  Result := DbSavepointSqlOf('RELEASE ', AName);
end;

function DbRollbackToSavepointSql(const AName: string): string; inline;
begin
  Result := DbSavepointSqlOf('ROLLBACK TO SAVEPOINT ', AName);
end;

function DbReleaseSavepointSql(const AName: string): string; inline;
begin
  Result := DbSavepointSqlOf('RELEASE SAVEPOINT ', AName);
end;

function DbValidatedSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbSavepointSql(AName);
end;

function DbValidatedRollbackToSql(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbRollbackToSql(AName);
end;

function DbValidatedReleaseSql(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbReleaseSql(AName);
end;

function DbValidatedRollbackToSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbRollbackToSavepointSql(AName);
end;

function DbValidatedReleaseSavepointSql(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbReleaseSavepointSql(AName);
end;

function DbReleaseSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
begin
  if ABackend in [dbkMysql, dbkDm] then Result := DbReleaseSavepointSql(AName) else Result := DbReleaseSql(AName);
end;

function DbRollbackToSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
begin
  if ABackend in [dbkMysql, dbkDm] then Result := DbRollbackToSavepointSql(AName) else Result := DbRollbackToSql(AName);
end;

function DbValidatedReleaseSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbReleaseSqlFor(ABackend, AName);
end;

function DbValidatedRollbackToSqlFor(const ABackend: TDbKind; const AName: string): string; inline;
begin
  ValidateDbSavepointName(ABackend, AName);
  Result := DbRollbackToSqlFor(ABackend, AName);
end;

end.
