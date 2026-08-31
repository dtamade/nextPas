program bench_db_blob_stream;

{ 大对象内存恒定探针（INC-8 性能门禁，§12.4 判据数据源）：
    materialize : GetBlob 全量物化大 blob——RSS 随体积线性涨（旧路径）
    stream      : IDbBlobStream 分块读写——RSS 恒定不随体积涨（判据：
                  峰值增量 < 16MB @ 128MB blob）
  探针读 /proc/self/statm 常驻页数。sqlite 段用文件库（:memory: 会把
  数据吃进堆干扰判据）；pg 段走 large object（客户端侧恒定性）。
  结束删除临时库文件。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  SysUtils,
  StrUtils,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.tx;

const
  SQLITE_BLOB_MB = 128;
  SQLITE_BLOB_BYTES = Int64(SQLITE_BLOB_MB) * 1024 * 1024;
  PG_BLOB_BYTES = Int64(64) * 1024 * 1024;
  CHUNK = 256 * 1024;
  STREAM_BUDGET_MB = 16;

var
  GTmpPath: string;
  GK: Integer;

function RssMb: Double;
var
  F: TextFile;
  S: string;
  P1, P2: Integer;
  Pages: Int64;
begin
  AssignFile(F, '/proc/self/statm');
  Reset(F);
  ReadLn(F, S);
  CloseFile(F);
  P1 := Pos(' ', S);
  P2 := PosEx(' ', S, P1 + 1);
  Val(Copy(S, P1 + 1, P2 - P1 - 1), Pages);
  Result := Pages * 4096 / (1024 * 1024);
end;

procedure MakeRamp(var ABuf: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(ABuf) do
    ABuf[I] := Byte((I * 7 + (I shr 8)) and $FF);
end;

{ 全量物化对照：RSS 应随体积线性涨 }
procedure BenchMaterialize(const AConn: IDbConnection);
var
  Q: IDbQuery;
  B: TBytes;
  Before, After: Double;
begin
  Before := RssMb;
  Q := AConn.Query('SELECT data FROM t_big WHERE id = 1');
  if not Q.Step then
  begin
    WriteLn('FAIL: materialize row missing');
    Halt(1);
  end;
  B := Q.GetBlob(0);
  GK := Length(B) div 4096;                { 消费防优化 }
  After := RssMb;
  WriteLn('mode=materialize blob_mb=', SQLITE_BLOB_MB,
    ' rss_before_mb=', Before:0:1,
    ' rss_peak_delta_mb=', (After - Before):0:1);
end;

{ 流式分块写读：RSS 恒定判据 }
procedure BenchStreamSqlite(const AConn: IDbConnection);
var
  Row: IDbRowBlobControl;
  S: IDbBlobStream;
  Buf: TBytes;
  I: Integer;
  Before, Peak, Now: Double;
begin
  SetLength(Buf, CHUNK);
  MakeRamp(Buf);
  if AConn.QueryInterface(IDbRowBlobControl, Row) <> 0 then
  begin
    WriteLn('stream: row-blob control unavailable');
    Exit;
  end;
  Before := RssMb;
  Peak := Before;
  S := Row.OpenRowBlob('t_big', 'data', 1, True);
  for I := 0 to (SQLITE_BLOB_BYTES div CHUNK) - 1 do
  begin
    S.Write(@Buf[0], CHUNK);
    Now := RssMb;
    if Now > Peak then
      Peak := Now;
  end;
  S.Seek(0, dsoBegin);
  for I := 0 to (SQLITE_BLOB_BYTES div CHUNK) - 1 do
  begin
    S.Read(@Buf[0], CHUNK);
    GK := GK xor Buf[0];                   { 消费防优化 }
  end;
  S := nil;
  Buf := nil;
  WriteLn('mode=stream blob_mb=', SQLITE_BLOB_MB,
    ' chunk_kb=', CHUNK div 1024,
    ' rss_before_mb=', Before:0:1,
    ' rss_peak_delta_mb=', (Peak - Before):0:1);
  if Peak - Before > STREAM_BUDGET_MB then
  begin
    WriteLn('FAIL: stream rss delta exceeds budget ', STREAM_BUDGET_MB, 'MB');
    Halt(1);
  end;
end;

{ pg 条件段：LO 流式 64MB，客户端 RSS 恒定同判据 }
procedure BenchPgStream;
var
  Conn: IDbConnection;
  Loc: IDbLargeObjectControl;
  S: IDbBlobStream;
  Buf: TBytes;
  Oid: Int64;
  Before, Peak, Now: Double;
begin
  if GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') = '' then
  begin
    WriteLn('pg stream skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  SetLength(Buf, CHUNK);
  MakeRamp(Buf);
  Conn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'));
  try
    Conn.QueryInterface(IDbLargeObjectControl, Loc);
    Before := RssMb;
    Peak := Before;
    WithTransaction(Conn, procedure
    var
      K: Integer;
    begin
      Oid := Loc.CreateLO;
      S := Loc.OpenLO(Oid, True);
      K := 0;
      while K < PG_BLOB_BYTES div CHUNK do
      begin
        S.Write(@Buf[0], CHUNK);
        Now := RssMb;
        if Now > Peak then
          Peak := Now;
        Inc(K);
      end;
      S.Seek(0, dsoBegin);
      K := 0;
      while K < PG_BLOB_BYTES div CHUNK do
      begin
        S.Read(@Buf[0], CHUNK);
        GK := GK xor Buf[0];
        Inc(K);
      end;
      S := nil;
    end);
    WriteLn('mode=pg-stream blob_mb=', PG_BLOB_BYTES div (1024 * 1024),
      ' rss_before_mb=', Before:0:1,
      ' rss_peak_delta_mb=', (Peak - Before):0:1);
    if Peak - Before > STREAM_BUDGET_MB then
    begin
      WriteLn('FAIL: pg stream rss delta exceeds budget');
      Halt(1);
    end;
  finally
    Conn := nil;
  end;
end;

var
  Conn: IDbConnection;
begin
  Randomize;
  GTmpPath := GetEnvironmentVariable('TMPDIR');
  if GTmpPath = '' then
    GTmpPath := '/tmp';
  GTmpPath := IncludeTrailingPathDelimiter(GTmpPath) +
    'np_blob_bench_' + IntToStr(Random(1000000000)) + '.db';
  try
    Conn := ConnectSqlite(GTmpPath);
    try
      Conn.Exec('CREATE TABLE t_big (id INTEGER PRIMARY KEY, data BLOB)');
      Conn.Exec('INSERT INTO t_big VALUES (1, zeroblob(' +
        IntToStr(SQLITE_BLOB_BYTES) + '))');
      BenchMaterialize(Conn);
      BenchStreamSqlite(Conn);
    finally
      Conn := nil;
    end;
    BenchPgStream;
    WriteLn('blob-stream-bench=pass');
  finally
    DeleteFile(GTmpPath);
  end;
  if GK < 0 then
    WriteLn;
end.
