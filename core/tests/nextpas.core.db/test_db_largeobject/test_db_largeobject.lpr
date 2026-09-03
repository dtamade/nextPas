program test_db_largeobject;

{ V2-S7 大对象流（INC-8）契约测试：
    1 能力探测分面：sqlite 有 IDbRowBlobControl、无 IDbLargeObjectControl
    2 写读往返：分块写模式数据，重开逐字节校验
    3 Seek 语义：Begin/Current/End 定位精确
    4 EOF 语义：末尾短读；末端读返回 0
    5 定长契约：越过单元末尾写 = 异常（占位经 zeroblob(N)）
    6 持久性：释放流后重开读到已写数据
    7 打开失败：不存在的行抛 EDbError
    8 pg 条件段：有 IDbLargeObjectControl、无 IDbRowBlobControl；
      CreateLO/Write/Seek/Read/UnlinkLO 全程事务内；事务外 OpenLO 抛错
      （句柄-事务耦合契约的 fail-fast 面）
  pg 段需本地实例（NEXTPAS_PG_TEST_CONN）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.tx,
  nextpas.core.db.factory.register.sqlite,
  nextpas.core.db.factory.register.pg;

const
  BLOB_SIZE = 1048576;                   { 1MB：跨多块写入 }
  CHUNK = 65536;

var
  T: TTestSuite;
  GPgConn: string;

procedure MakePattern(var ABuf: TBytes; const ASeed: Integer);
var
  I: Integer;
begin
  for I := 0 to High(ABuf) do
    ABuf[I] := Byte((I * 31 + ASeed) and $FF);
end;

function PatternMatches(const ABuf: TBytes; const ASeed: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ABuf) do
    if ABuf[I] <> Byte((I * 31 + ASeed) and $FF) then
      Exit;
  Result := True;
end;

{ 1 }
procedure TestCapabilitySplit;
var
  Conn: IDbConnection;
  Row, LO: IDbRowBlobControl;
  Loc: IDbLargeObjectControl;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Check(Conn.QueryInterface(IDbRowBlobControl, Row) = 0,
      'split: sqlite exposes row-blob control');
    Check(Conn.QueryInterface(IDbLargeObjectControl, Loc) <> 0,
      'split: sqlite does not fake OID model');
    Row := nil;
  finally
    Conn := nil;
  end;
end;

{ 2 }
procedure TestRoundtripChunked;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
  I: Integer;
begin
  SetLength(Buf, CHUNK);
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_lo (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.Exec('INSERT INTO t_lo VALUES (1, zeroblob(' +
      IntToStr(BLOB_SIZE) + '))');       { 占位定长 }
    Check(Conn.QueryInterface(IDbRowBlobControl, Row) = 0, 'rt: capability');
    S := Row.OpenRowBlob('t_lo', 'data', 1, True);
    Check(S.Size = BLOB_SIZE, 'rt: size from placeholder');
    for I := 0 to (BLOB_SIZE div CHUNK) - 1 do
    begin
      MakePattern(Buf, I);
      S.Write(@Buf[0], Length(Buf));
    end;
    S := nil;                            { 接口释放即关闭 }

    S := Row.OpenRowBlob('t_lo', 'data', 1, False);
    for I := 0 to (BLOB_SIZE div CHUNK) - 1 do
    begin
      FillChar(Buf[0], Length(Buf), 0);
      Check(S.Read(@Buf[0], Length(Buf)) = SizeUInt(CHUNK),
        'rt: full chunk read ' + IntToStr(I));
      Check(PatternMatches(Buf, I), 'rt: chunk pattern intact ' + IntToStr(I));
    end;
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 3 }
procedure TestSeekSemantics;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  B: array[0..3] of Byte;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_sk (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.Exec('INSERT INTO t_sk VALUES (1, zeroblob(16))');
    Conn.QueryInterface(IDbRowBlobControl, Row);
    S := Row.OpenRowBlob('t_sk', 'data', 1, True);
    Check(S.Seek(10, dsoBegin) = 10, 'seek: begin absolute');
    Check(S.Seek(2, dsoCurrent) = 12, 'seek: current relative');
    Check(S.Seek(-4, dsoEnd) = 12, 'seek: end relative');
    B[0] := $AB;
    S.Write(@B[0], 1);                   { 位置 12 处写入 }
    Check(S.Seek(12, dsoBegin) = 12, 'seek: back to written pos');
    Check(S.Read(@B[0], 1) = 1, 'seek: read back');
    Check(B[0] = $AB, 'seek: value at positioned write');
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 4 }
procedure TestEofSemantics;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
begin
  SetLength(Buf, 64);
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_ef (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.Exec('INSERT INTO t_ef VALUES (1, zeroblob(100))');
    Conn.QueryInterface(IDbRowBlobControl, Row);
    S := Row.OpenRowBlob('t_ef', 'data', 1, False);
    Check(S.Seek(90, dsoBegin) = 90, 'eof: near-end position');
    Check(S.Read(@Buf[0], 64) = 10, 'eof: short read returns remainder');
    Check(S.Read(@Buf[0], 64) = 0, 'eof: read at end returns zero');
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 5 }
procedure TestFixedCellContract;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
  Raised: Boolean;
begin
  SetLength(Buf, 16);
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_fx (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.Exec('INSERT INTO t_fx VALUES (1, zeroblob(32))');
    Conn.QueryInterface(IDbRowBlobControl, Row);
    S := Row.OpenRowBlob('t_fx', 'data', 1, True);
    S.Seek(24, dsoBegin);
    Raised := False;
    try
      S.Write(@Buf[0], 16);              { 24+16 > 32：越界 }
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'fixed-cell: write beyond end raises');
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 6 }
procedure TestPersistenceAcrossReopen;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
begin
  SetLength(Buf, 8);
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_pr (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.Exec('INSERT INTO t_pr VALUES (1, zeroblob(8))');
    Conn.QueryInterface(IDbRowBlobControl, Row);
    S := Row.OpenRowBlob('t_pr', 'data', 1, True);
    Buf[0] := 1; Buf[7] := 255;
    S.Write(@Buf[0], 8);
    S := nil;
    S := Row.OpenRowBlob('t_pr', 'data', 1, False);
    FillChar(Buf[0], 8, 0);
    Check(S.Read(@Buf[0], 8) = 8, 'persist: reopened read ok');
    Check((Buf[0] = 1) and (Buf[7] = 255), 'persist: bytes survive close/reopen');
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 7 }
procedure TestOpenMissingRowRaises;
var
  Conn: IDbConnection;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_mr (id INTEGER PRIMARY KEY, data BLOB)');
    Conn.QueryInterface(IDbRowBlobControl, Row);
    Raised := False;
    try
      S := Row.OpenRowBlob('t_mr', 'data', 999, False);
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'missing-row: open raises cleanly');
    S := nil;
  finally
    Conn := nil;
  end;
end;

{ 8 }
procedure TestPgLargeObjects;
var
  Conn: IDbConnection;
  Loc: IDbLargeObjectControl;
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
  Oid: Int64;
  Raised: Boolean;
  Tx: IDbTxControl;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg large object tests skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  SetLength(Buf, CHUNK);
  Conn := ConnectPostgres(GPgConn);
  try
    Check(Conn.QueryInterface(IDbLargeObjectControl, Loc) = 0,
      'pg-lo: OID control present');
    Check(Conn.QueryInterface(IDbRowBlobControl, Row) <> 0,
      'pg-lo: cell model absent (honest split)');

    { 事务外 OpenLO 必须失败（fail-fast 契约） }
    Raised := False;
    try
      Loc.CreateLO;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'pg-lo: outside txn fails fast');

    WithTransaction(Conn, procedure
    var
      I: Integer;
      Back: TBytes;
    begin
      Oid := Loc.CreateLO;
      Check(Oid <> 0, 'pg-lo: created non-zero oid');
      S := Loc.OpenLO(Oid, True);
      for I := 0 to 15 do
      begin
        MakePattern(Buf, I);
        S.Write(@Buf[0], Length(Buf));
      end;
      Check(S.Seek(0, dsoBegin) = 0, 'pg-lo: seek begin');
      SetLength(Back, CHUNK);
      for I := 0 to 15 do
      begin
        FillChar(Back[0], Length(Back), 0);
        Check(S.Read(@Back[0], Length(Back)) = SizeUInt(CHUNK),
          'pg-lo: chunk read back');
        Check(PatternMatches(Back, I), 'pg-lo: chunk matches');
      end;
      Check(S.Size = Int64(16) * CHUNK, 'pg-lo: size after writes');
      S := nil;
    end);

    { 反向契约：UnlinkLO 在事务内 = fail-fast。异常经包装器回滚路径
      穿出，外层捕获断言；未写数据，无残留状态。 }
    Tx := nil;
    Conn.QueryInterface(IDbTxControl, Tx);
    Check(Tx <> nil, 'pg-lo: tx control reachable');
    Raised := False;
    try
      WithTransaction(Conn, procedure
      begin
        Loc.UnlinkLO(Oid);
      end);
    except
      on E: EDbError do
        Raised := True;
    end;
    Check(Raised, 'pg-lo: unlink inside txn fails fast');
    Check(not Tx.InTransaction, 'pg-lo: aborted txn fully unwound');
    Tx := nil;

    { 事务外删除（libpq lo_unlink 自管 BEGIN/END） }
    Loc.UnlinkLO(Oid);
    Oid := 0;
  finally
    Conn := nil;
  end;
end;

begin
  RegisterSqliteDriver;
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.largeobject');
  T.Test('capability split', @TestCapabilitySplit);
  T.Test('chunked roundtrip', @TestRoundtripChunked);
  T.Test('seek semantics', @TestSeekSemantics);
  T.Test('eof semantics', @TestEofSemantics);
  T.Test('fixed cell contract', @TestFixedCellContract);
  T.Test('persistence across reopen', @TestPersistenceAcrossReopen);
  T.Test('open missing row raises', @TestOpenMissingRowRaises);
  T.Test('pg large objects', @TestPgLargeObjects);
  if not T.Run then Halt(1);
end.
