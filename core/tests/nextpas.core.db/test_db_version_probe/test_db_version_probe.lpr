program test_db_version_probe;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.db.base,
  nextpas.core.db,
  nextpas.core.db.bulk,
  nextpas.core.db.capprobe,
  nextpas.core.db.sqlite.adapter;

var
  T: TTestSuite;

procedure TestParseServerVersion;
begin
  Check(ParseServerVersion('') = 0, 'empty 0');
  Check(ParseServerVersion('17.1') = 170100, '17.1');
  Check(ParseServerVersion('17.1.2') = 170102, '17.1.2');
  Check(ParseServerVersion('8.0.33') = 80033, '8.0.33');
  Check(ParseServerVersion('3.46.0') = 34600, '3.46.0');
  Check(ParseServerVersion('PostgreSQL 17.1') = 170100, 'prefix stripped -> 17.1');
  Check(ParseServerVersion('8.0.33-0ubuntu') = 80033, 'suffix dash');
  Check(ParseServerVersion('  15.2  ') = 150200, 'trim');
  Check(ParseServerVersion('14') = 140000, 'major only');
  Check(ParseServerVersion('10.6.11-MariaDB') = 100611, 'mariadb suffix');
end;

procedure TestProbeVector;
begin
  Check(not ProbeNativeVector(140000, True), '14 true still false');
  Check(not ProbeNativeVector(150000, False), '15 false');
  Check(ProbeNativeVector(150000, True), '15 true');
  Check(ProbeNativeVector(170001, True), '17 true');
end;

procedure TestProbeJsonPath;
begin
  Check(not ProbeJsonPath(110000), '11 false');
  Check(ProbeJsonPath(120000), '12 true');
  Check(ProbeJsonPath(170000), '17 true');
end;

procedure TestProbeRange;
begin
  Check(not ProbeRangeTypes(130000), '13 false');
  Check(ProbeRangeTypes(140000), '14 true');
  Check(ProbeRangeTypes(160000), '16 true');
end;

procedure TestProbeBulk;
begin
  Check(not ProbeBulkCopy(0), 'bulk false 0 honest');
  Check(not ProbeBulkCopy(130000), 'bulk false 13');
  Check(ProbeBulkCopy(140000), 'bulk true 14 COPY BINARY threshold');
  Check(ProbeBulkCopy(170000), 'bulk true 17');
end;

procedure TestCapsServerVersion;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
begin
  Conn := ConnectSqlite(':memory:');
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'sqlite caps present');
  if Cap <> nil then
  begin
    Check(Cap.ServerVersion > 30000, 'sqlite version >30000');
    Check(not Cap.SupportsNativeVector, 'sqlite no vector');
    Check(Cap.SupportsBulkCopy, 'sqlite bulk true V4.2');
    // sqlite 3.35+ supports json path? our probe says false for sqlite (0)
    Check(not Cap.SupportsJsonPath, 'sqlite json path false (pg-only)');
  end;
end;

procedure TestCapsHonestFalse;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
begin
  Conn := ConnectSqlite(':memory:');
  Cap := DbCapabilities(Conn);
  // odbc/redis/sqlite/dm stub version 0 => all new caps false
  Check(Cap.ServerVersion <> 0, 'sqlite version non-zero');
  Check(Cap.MaxPlaceholders = 999, 'sqlite max 999');
end;

procedure TestBulkBufferFiveKinds;
var
  Buf: TDbBulkBuffer;
  Kinds: array[0..4] of TDbKind;
  K: Integer;
  S: string;
begin
  Buf := Default(TDbBulkBuffer);
  Kinds[0] := dbkSqlite; Kinds[1] := dbkPostgres; Kinds[2] := dbkMysql;
  Kinds[3] := dbkOdbc; Kinds[4] := dbkDm;
  for K := 0 to High(Kinds) do
  begin
    Buf.Clear;
    Check(not Buf.IsActive, 'buf clear inactive ' + IntToStr(K));
    Buf.BeginCopy('t_bulk', ['id', 'v']);
    Check(Buf.IsActive, 'buf active ' + IntToStr(K));
    Check(Buf.ColumnCount = 2, 'buf col 2 ' + IntToStr(K));
    Buf.WriteRow(Kinds[K], ['1', 'a']);
    Buf.WriteRow(Kinds[K], ['2', 'O''Brien']);
    Check(Buf.RowCount = 2, 'buf row 2 ' + IntToStr(K));
    S := DbBulkMultiInsertSql(Buf.TableName, Buf.Columns, Buf.Rows, 0, 2);
    Check(Pos('O''''Brien', S) > 0, 'DbBulkEscape single ''->'''' ' + IntToStr(K));
    Check(DbBulkChunkRows(999, Buf.ColumnCount, Buf.RowCount) = 2, 'chunk 2 ' + IntToStr(K));
    Buf.Clear;
    Check(not Buf.IsActive, 'buf cleared ' + IntToStr(K));
  end;
  // redis honest false via ProbeBulkCopy(0)=false — bulk buffer not used for redis
  Check(not ProbeBulkCopy(0), 'redis ProbeBulkCopy(0)=false honest');
  Check(ProbeBulkCopy(140000), 'PG COPY BINARY ProbeBulkCopy PG>=140000 true');
end;

procedure TestBulkEscapeSingleSource;
var
  S: string;
  Buf: TDbBulkBuffer;
begin
  S := DbBulkEscape('a''b');
  Check(S = 'a''''b', 'DbBulkEscape single quote');
  S := DbBulkEscape('''');
  Check(S = '''''' , 'DbBulkEscape lone quote');
  Check(DbBulkEscape('') = '', 'DbBulkEscape empty');
  // TDbBulkBuffer single-source reuse
  Buf.Clear;
  Buf.BeginCopy('t', ['a', 'b']);
  Buf.WriteRow(dbkPostgres, ['x', 'y']);
  Check(Buf.RowCount = 1, 'buf pg row 1');
  Buf.Clear;
end;

type
  TFlushProbe = class
    InTxn: Boolean;
    ExecCalls: Integer;
    BeginCalls: Integer;
    CommitCalls: Integer;
    RollbackCalls: Integer;
    LastSql: string;
    procedure DoExec(const ASql: string);
    procedure DoBegin(const AImmediate: Boolean);
    procedure DoCommit;
    procedure DoRollback;
  end;

procedure TFlushProbe.DoExec(const ASql: string);
begin
  Inc(ExecCalls);
  LastSql := ASql;
end;

procedure TFlushProbe.DoBegin(const AImmediate: Boolean);
begin
  Inc(BeginCalls);
  InTxn := True;
end;

procedure TFlushProbe.DoCommit;
begin
  Inc(CommitCalls);
  InTxn := False;
end;

procedure TFlushProbe.DoRollback;
begin
  Inc(RollbackCalls);
  InTxn := False;
end;

procedure TestBulkFlushInTxnBranching;
var
  Probe: TFlushProbe;
  Rows: TDbBulkRows;
  Cols: TDbStringArray;
begin
  SetLength(Cols, 2); Cols[0] := 'id'; Cols[1] := 'v';
  SetLength(Rows, 2);
  SetLength(Rows[0], 2); Rows[0][0] := '1'; Rows[0][1] := 'a';
  SetLength(Rows[1], 2); Rows[1][0] := '2'; Rows[1][1] := 'b';
  // InTransaction=true -> SAVEPOINT + Exec per chunk + RELEASE (no BEGIN/COMMIT)
  Probe := TFlushProbe.Create;
  try
    Probe.InTxn := True;
    DbBulkFlushChunked('t_bulk', Cols, Rows, 1, True, @Probe.DoExec, @Probe.DoBegin, @Probe.DoCommit, @Probe.DoRollback);
    Check(Probe.ExecCalls = 4, 'flush InTxn true exec 2 chunks + SAVEPOINT/RELEASE');
    Check(Probe.BeginCalls = 0, 'flush InTxn true no begin');
    Check(Probe.CommitCalls = 0, 'flush InTxn true no commit');
  finally
    Probe.Free;
  end;
  // InTransaction=false -> BEGIN/COMMIT wrapping
  Probe := TFlushProbe.Create;
  try
    Probe.InTxn := False;
    DbBulkFlushChunked('t_bulk', Cols, Rows, 2, False, @Probe.DoExec, @Probe.DoBegin, @Probe.DoCommit, @Probe.DoRollback);
    Check(Probe.BeginCalls = 1, 'flush InTxn false begin 1');
    Check(Probe.CommitCalls = 1, 'flush InTxn false commit 1');
    Check(Probe.ExecCalls = 1, 'flush InTxn false exec 1 chunk (2 rows)');
    Check(Probe.RollbackCalls = 0, 'flush InTxn false no rollback on success');
  finally
    Probe.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.version_probe');
  T.Test('parse server version', @TestParseServerVersion);
  T.Test('probe vector', @TestProbeVector);
  T.Test('probe json', @TestProbeJsonPath);
  T.Test('probe range', @TestProbeRange);
  T.Test('probe bulk', @TestProbeBulk);
  T.Test('caps server version', @TestCapsServerVersion);
  T.Test('caps honest', @TestCapsHonestFalse);
  T.Test('bulk buffer five kinds (5/6 hard-coded true, redis ProbeBulkCopy(0)=false)', @TestBulkBufferFiveKinds);
  T.Test('bulk escape single-source reuse', @TestBulkEscapeSingleSource);
  T.Test('bulk flush InTransaction branching', @TestBulkFlushInTxnBranching);
  if not T.Run then Halt(1);
end.
