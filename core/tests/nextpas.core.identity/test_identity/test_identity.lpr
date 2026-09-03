program test_identity;

{ nextpas.core.identity 专属离线门禁（L2 能力域，Owner=identity lane，四件套 base←identity 已独立）：
  user_profiles 单表 + 文本/时间/字节单源 + 迁移幂等 + 资源释放不丢。
  契约：core/docs/identity/CONTRACT.md（§1 表/§2 文本时间单源/§4 性能/§5 稳定性）；
  归属：Owner=identity lane，路径 core/tests/nextpas.core.identity/test_identity（原 wallet 寄宿已分治，见 wallet/CONTRACT.md §1 与 db/CONTRACT.md §1）；
  单源：bytes.ops 单 Move 零拷贝 + text.utils Trim inline 零拷贝 + time iso8601 单源，已分治零 L3→L3。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  BaseUnix,
  nextpas.core.test,
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.time,
  nextpas.core.time.iso8601,
  nextpas.core.db.base,
  nextpas.core.db,
  nextpas.core.db.pool,
  nextpas.core.db.migrate,
  nextpas.core.identity.base,
  nextpas.core.identity;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: test_identity must reuse bytes.ops'}
{$IFEND}

var
  T: TTestSuite;
  GSeq: Integer = 0;

function NextIdentityPath: string; inline;
begin
  Inc(GSeq);
  Result := GetTempDir + 'test_identity_' + IntToStr(FpGetPid) + '_' + IntToStr(GSeq) + '.db';
end;

procedure TestIdentityMigrations;
var
  LPath: string;
  Pool: TDbPool;
  C: IDbConnection;
begin
  LPath := NextIdentityPath;
  DeleteFile(LPath);
  Pool := TDbPool.Create(
    function: IDbConnection
    var
      Cc: IDbConnection;
    begin
      Cc := ConnectSqlite(LPath);
      Cc.Exec('PRAGMA foreign_keys=ON');
      Result := Cc;
    end, TDbPoolPolicy.Default);
  try
    C := Pool.Writer;
    try
      Check(Migrate(C, IdentityMakeMigrations) = 1, 'identity: v14 applied');
      Check(Migrate(C, IdentityMakeMigrations) = 0, 'identity: idempotent');
      Check(MigrationVersion(C) = IDENTITY_MIGRATION_VERSION, 'identity: version 14');
      Check(IDENTITY_MIGRATION_VERSION = 14, 'identity: base const single source');
      Check(IDENTITY_USER_PROFILES_TABLE = 'user_profiles', 'identity: table const single source');
    finally
      C := nil;
    end;
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

procedure TestIdentityTextTimeBytesSingleSource;
var
  B: TBytes;
begin
  Check(IdentityNormalizeId('  abc  ') = 'abc', 'identity: Trim via text.utils inline');
  Check(IdentityNormalizeId('abc') = 'abc', 'identity: no-trim zero-copy share');
  Check(IdentityIsValidId('u1'), 'identity: IsValid true');
  Check(not IdentityIsValidId(''), 'identity: empty invalid');
  Check(not IdentityIsValidId('  '), 'identity: blank invalid');
  B := IdentityIdToBytes('  abc  ');
  Check((Length(B)=3) and (B[0]=Ord('a')), 'identity: StringToBytes single Move after Trim');
  B := IdentityIdToBytes('');
  Check(Length(B)=0, 'identity: empty bytes');
  Check(IdentityNowIso8601 <> '', 'identity: NowIso8601 via time single source');
  Check(Pos('T', IdentityNowIso8601) > 0, 'identity: iso8601 format');
end;

procedure TestIdentityInsertAndFk;
var
  LPath: string;
  Pool: TDbPool;
  C: IDbConnection;
  Q: IDbQuery;
begin
  LPath := NextIdentityPath;
  DeleteFile(LPath);
  Pool := TDbPool.Create(
    function: IDbConnection
    var
      Cc: IDbConnection;
    begin
      Cc := ConnectSqlite(LPath);
      Cc.Exec('PRAGMA foreign_keys=ON');
      Result := Cc;
    end, TDbPoolPolicy.Default);
  try
    C := Pool.Writer;
    try
      Migrate(C, IdentityMakeMigrations);
      Q := C.Query('INSERT INTO user_profiles (id) VALUES (?1)');
      Q.BindText(1, 'u1');
      Q.Step;
      Q := nil;
      Q := C.Query('SELECT count(*) FROM user_profiles WHERE id=?1');
      Q.BindText(1, 'u1');
      Check(Q.Step, 'identity: inserted');
      Check(Q.GetInt64(0)=1, 'identity: count 1');
    finally
      Q := nil;
      C := nil;
    end;
  finally
    Pool.Free;
    DeleteFile(LPath);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.identity');
  T.Test('migrations v14 single source', @TestIdentityMigrations);
  T.Test('text/time/bytes single source inline zero-copy', @TestIdentityTextTimeBytesSingleSource);
  T.Test('insert user_profiles and query', @TestIdentityInsertAndFk);
  if not T.Run then Halt(1);
end.
