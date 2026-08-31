program test_db_v2;

{ v2 设计演示门禁：同一套消费方代码跑两个后端。
  1) 错误归一：unique/PK/FK/Check 违例在 sqlite 与 pg 上得到相同的
     Category=decConstraint 与对应 ConstraintKind——消费方一个
     case 分支跨后端成立（D2 的直接证明）。
  2) 能力探测：IDbSavepointControl 经 QueryInterface 获取（D1）。
  3) savepoint 部分回滚：内层失败只撤销内层写入，外层干净继续。

  sqlite 段总是执行；pg 段需要本地 PostgreSQL（Makefile ensure-db）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db,
  nextpas.core.db.err;

var
  T: TTestSuite;

{ ==== 共享断言：两后端逐字复用（设计主张本体） ==== }

procedure ExpectConstraint(const AConn: IDbConnection; const ASql: string;
  const AExpected: TDbConstraintKind; const ALabel: string);
var
  Caught: Boolean;
begin
  Caught := False;
  try
    AConn.Exec(ASql);
  except
    on E: EDbError do
    begin
      Caught := True;
      Check(E.Category = decConstraint, ALabel + ': category = decConstraint');
      Check(E.Constraint = AExpected,
        ALabel + ': constraint kind = ' + IntToStr(Ord(AExpected)));
    end;
  end;
  Check(Caught, ALabel + ': violation raised as EDbError');
end;

procedure RunConstraintSuite(const AConn: IDbConnection; const APrefix: string);
begin
  { UNIQUE }
  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_u');
  AConn.Exec('CREATE TABLE ' + APrefix + '_u (code TEXT UNIQUE)');
  AConn.Exec('INSERT INTO ' + APrefix + '_u VALUES (''a'')');
  ExpectConstraint(AConn, 'INSERT INTO ' + APrefix + '_u VALUES (''a'')',
    dckUnique, APrefix + '/unique');

  { PRIMARY KEY——Category 两后端一致（decConstraint）；细分按各自
    原生分类：sqlite 有独立 PK 子码(1555)，pg 把主键冲突折叠进
    23505(unique_violation)。db.err 不猜测、如实映射。 }
  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_p');
  AConn.Exec('CREATE TABLE ' + APrefix + '_p (id INTEGER PRIMARY KEY)');
  AConn.Exec('INSERT INTO ' + APrefix + '_p VALUES (1)');
  if AConn.Kind = dbkSqlite then
    ExpectConstraint(AConn, 'INSERT INTO ' + APrefix + '_p VALUES (1)',
      dckPrimaryKey, APrefix + '/pk')
  else
    ExpectConstraint(AConn, 'INSERT INTO ' + APrefix + '_p VALUES (1)',
      dckUnique, APrefix + '/pk');

  { FOREIGN KEY（外键强制是 sqlite 会话开关，pg 恒开） }
  if AConn.Kind = dbkSqlite then
    AConn.Exec('PRAGMA foreign_keys = ON');
  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_child');
  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_parent');
  AConn.Exec('CREATE TABLE ' + APrefix + '_parent (id INTEGER PRIMARY KEY)');
  AConn.Exec('CREATE TABLE ' + APrefix + '_child (' +
    'pid INTEGER REFERENCES ' + APrefix + '_parent(id))');
  ExpectConstraint(AConn, 'INSERT INTO ' + APrefix + '_child VALUES (999)',
    dckForeignKey, APrefix + '/fk');

  { CHECK }
  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_c');
  AConn.Exec('CREATE TABLE ' + APrefix + '_c (v INTEGER CHECK (v >= 0))');
  ExpectConstraint(AConn, 'INSERT INTO ' + APrefix + '_c VALUES (-5)',
    dckCheck, APrefix + '/check');
end;

procedure RunSavepointSuite(const AConn: IDbConnection; const APrefix: string);
var
  Sp: IDbSavepointControl;
  Q: IDbQuery;
  function CountOf(const AT: string): Int64;
  begin
    Q := AConn.Query('SELECT COUNT(*) FROM ' + AT);
    Check(Q.Step, APrefix + ': count row');
    Result := Q.GetInt64(0);
  end;
begin
  if AConn.QueryInterface(IDbSavepointControl, Sp) <> 0 then
  begin
    Check(False, APrefix + ': savepoint capability available');
    Exit;
  end;
  Check(True, APrefix + ': savepoint capability via QueryInterface');

  AConn.Exec('DROP TABLE IF EXISTS ' + APrefix + '_sp');
  AConn.Exec('CREATE TABLE ' + APrefix + '_sp (tag TEXT)');
  WithTransaction(AConn, procedure
  begin
    AConn.Exec('INSERT INTO ' + APrefix + '_sp VALUES (''keep'')');
    Sp.Savepoint('inner1');
    try
      AConn.Exec('INSERT INTO ' + APrefix + '_sp VALUES (''doomed'')');
      raise ENextPasError.Create(APrefix + ' inner boom');
    except
      { 内层失败被捕获：savepoint 回滚只撤销 ''doomed'' }
      Sp.RollbackTo('inner1');
      Sp.ReleaseTo('inner1');
    end;
  end);
  { 外层提交：keep 在、doomed 不在——部分回滚语义成立 }
  CheckEqual(Int64(1), CountOf(APrefix + '_sp'), APrefix + ': only keep row survives');
end;

{ ==== sqlite 段 ==== }

procedure TestSqliteSuite;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  RunConstraintSuite(Conn, 'sq');
  RunSavepointSuite(Conn, 'sq');
end;

{ ==== pg 段 ==== }

function PgAvailable: Boolean;
begin
  Result := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') <> '';
end;

procedure TestPgSuite;
var
  Conn: IDbConnection;
begin
  if not PgAvailable then
  begin
    WriteLn('pg section skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'));
  RunConstraintSuite(Conn, 't_v2_pg');
  RunSavepointSuite(Conn, 't_v2_pg');
end;

begin
  T := TTestSuite.Create('nextpas.core.db.v2');
  T.Test('sqlite: constraint classification + savepoint', @TestSqliteSuite);
  T.Test('pg: same code same semantics', @TestPgSuite);
  if not T.Run then Halt(1);
end.
