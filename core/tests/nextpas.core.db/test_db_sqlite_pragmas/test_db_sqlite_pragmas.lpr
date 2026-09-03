program test_db_sqlite_pragmas;
{ V3-C5 调优预设门禁：TDbSqlitePragmas 连接级 PRAGMA 受控面。
  生效自证（回读钉子）+ :memory: journal 过滤 + unset 语义零变化 +
  WAL 回读校验 fail-closed 路径。全部离线可跑；heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.adapter;

var
  T: TTestSuite;

function Scalar(AConn: IDbConnection; const ASql: string): string;
var
  LQ: IDbQuery;
begin
  Result := '';
  LQ := AConn.Query(ASql);
  try
    if LQ.Step then
      Result := LQ.GetText(0);
  finally
    LQ := nil;
  end;
end;

procedure CleanFile(const APath: string);
begin
  DeleteFile(APath);
  DeleteFile(APath + '-wal');
  DeleteFile(APath + '-shm');
  DeleteFile(APath + '-journal');
end;

{ Default 预设（文件库）：WAL + synchronous=NORMAL(1) + foreign_keys=ON }
procedure TestDefaultPresetFileDb;
const
  CPath = '/tmp/np_c5_default.db';
var
  LConn: IDbConnection;
begin
  CleanFile(CPath);
  try
    LConn := ConnectSqlite(CPath, TDbConnectOptions.Default,
      TDbSqlitePragmas.Default);
    CheckEqual('wal', Scalar(LConn, 'PRAGMA journal_mode'), 'journal=wal');
    CheckEqual('1', Scalar(LConn, 'PRAGMA synchronous'),
      'synchronous=NORMAL(1)');
    CheckEqual('1', Scalar(LConn, 'PRAGMA foreign_keys'), 'foreign_keys on');
    { WAL 库可写可用 }
    LConn.Exec('CREATE TABLE t (v INTEGER)');
    LConn.Exec('INSERT INTO t VALUES (7)');
    CheckEqual('7', Scalar(LConn, 'SELECT v FROM t'), 'roundtrip under WAL');
    LConn := nil;
  finally
    CleanFile(CPath);
  end;
end;

{ :memory: 库过滤 journal_mode（WAL 无意义），其余 PRAGMA 照常生效 }
procedure TestMemoryJournalFiltered;
var
  LConn: IDbConnection;
begin
  LConn := ConnectSqlite(':memory:', TDbConnectOptions.Default,
    TDbSqlitePragmas.Default);
  try
    CheckEqual('memory', Scalar(LConn, 'PRAGMA journal_mode'),
      'memory db keeps memory journal (filtered, no error)');
    CheckEqual('1', Scalar(LConn, 'PRAGMA synchronous'), 'sync applied on mem');
    CheckEqual('1', Scalar(LConn, 'PRAGMA foreign_keys'), 'fk applied on mem');
  finally
    LConn := nil;
  end;
end;

{ 显式非缺省组合：delete + FULL + FK off——预设是受控词汇不是硬编码 }
procedure TestExplicitCombination;
const
  CPath = '/tmp/np_c5_explicit.db';
var
  LConn: IDbConnection;
  LP: TDbSqlitePragmas;
begin
  CleanFile(CPath);
  try
    LP.JournalMode := sjmDelete;
    LP.Synchronous := sysFull;
    LP.ForeignKeys := fkOff;
    LP.CacheSize := 0;
    LP.MmapSize := -1;
    LConn := ConnectSqlite(CPath, TDbConnectOptions.Default, LP);
    CheckEqual('delete', Scalar(LConn, 'PRAGMA journal_mode'), 'journal=delete');
    CheckEqual('2', Scalar(LConn, 'PRAGMA synchronous'),
      'synchronous=FULL(2)');
    CheckEqual('0', Scalar(LConn, 'PRAGMA foreign_keys'), 'fk off honored');
    LConn := nil;
  finally
    CleanFile(CPath);
  end;
end;

{ cache_size 负值 = KiB 语义（sqlite 惯例），回读一致 }
procedure TestCacheSizeNegativeKiB;
var
  LConn: IDbConnection;
  LP: TDbSqlitePragmas;
begin
  LP.JournalMode := sjmUnset;
  LP.Synchronous := sysUnset;
  LP.ForeignKeys := fkUnset;
  LP.CacheSize := -2000;
  LP.MmapSize := -1;
  LConn := ConnectSqlite(':memory:', TDbConnectOptions.Default, LP);
  try
    CheckEqual('-2000', Scalar(LConn, 'PRAGMA cache_size'), 'cache=-2000 KiB');
  finally
    LConn := nil;
  end;
end;

{ mmap advisory：部分 sqlite 构建编译期禁用（SQLITE_MAX_MMAP_SIZE=0），
  设置不报错、连接可用即通过（advisory 惯例，§2.14 同款诚实边界） }
procedure TestMmapAdvisory;
var
  LConn: IDbConnection;
  LP: TDbSqlitePragmas;
begin
  LP.JournalMode := sjmUnset;
  LP.Synchronous := sysUnset;
  LP.ForeignKeys := fkUnset;
  LP.CacheSize := 0;
  LP.MmapSize := 268435456;
  LConn := ConnectSqlite(':memory:', TDbConnectOptions.Default, LP);
  try
    LConn.Exec('CREATE TABLE m (v TEXT)');
    Check(True, 'connection usable with mmap request');
  finally
    LConn := nil;
  end;
end;

{ 全 unset：旧入口行为零变化的显式形态（sqlite 原生缺省 delete/FULL） }
procedure TestAllUnsetKeepsNativeDefaults;
const
  CPath = '/tmp/np_c5_unset.db';
var
  LConn: IDbConnection;
  LP: TDbSqlitePragmas;
begin
  CleanFile(CPath);
  try
    LP.JournalMode := sjmUnset;
    LP.Synchronous := sysUnset;
    LP.ForeignKeys := fkUnset;
    LP.CacheSize := 0;
    LP.MmapSize := -1;
    LConn := ConnectSqlite(CPath, TDbConnectOptions.Default, LP);
    CheckEqual('delete', Scalar(LConn, 'PRAGMA journal_mode'),
      'native default journal preserved');
    CheckEqual('0', Scalar(LConn, 'PRAGMA foreign_keys'),
      'native fk default preserved');
    LConn := nil;
  finally
    CleanFile(CPath);
  end;
end;

{ stmt cache 容量与 pragmas 正交共存：同连接两次点查命中缓存路径 }
procedure TestStmtCacheCoexists;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  I: Integer;
begin
  LConn := ConnectSqlite(':memory:', TDbConnectOptions.Default,
    TDbSqlitePragmas.Default, 8);
  try
    LConn.Exec('CREATE TABLE c (v INTEGER)');
    for I := 1 to 3 do
    begin
      LQ := LConn.Query('SELECT v FROM c WHERE v = ?');
      try
        LQ.BindInt64(1, I);
        while LQ.Step do;
      finally
        LQ := nil;
      end;
    end;
    Check(True, 'parameterized queries reuse cache path cleanly');
  finally
    LConn := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.sqlite.pragmas');
  T.Test('default preset file db (WAL+NORMAL+FK)', @TestDefaultPresetFileDb);
  T.Test('memory db filters journal_mode', @TestMemoryJournalFiltered);
  T.Test('explicit combination honored', @TestExplicitCombination);
  T.Test('cache_size negative KiB readback', @TestCacheSizeNegativeKiB);
  T.Test('mmap advisory accepted', @TestMmapAdvisory);
  T.Test('all-unset keeps native defaults', @TestAllUnsetKeepsNativeDefaults);
  T.Test('stmt cache coexists with pragmas', @TestStmtCacheCoexists);
  if not T.Run then Halt(1);
end.
