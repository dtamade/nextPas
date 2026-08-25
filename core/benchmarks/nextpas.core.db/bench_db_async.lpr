program bench_db_async;

{ V3-B6 / INC-4 异步挂载开销比（对照 bench_db_adapter_overhead 的 J1 口径）：
    - sync 直调基线：调用线程内 N 次 SELECT 1 往返
    - async submit/wait：同一负载经 TDbAsyncExecutor 单飞挂载
      （每次往返 = 提交唤醒 + 完成唤醒两次跨线程切换）
    - 计时 platform_monotonic_ns，报告均值 / P50 / P99 / max（µs）
    - sqlite :memory: 与 pg 真机（NEXTPAS_PG_TEST_CONN 自门控）双段
  判据（路线图 B6）：异步相对同步劣化 >20% 触发回退条款——
  诚实入册，给"何时值得异步"的使用指引，不砍功能。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.async,
  nextpas.core.async.cancellation,
  nextpas.core.platform.time;

const
  SQLITE_N = 20000;
  PG_N = 2000;
  WARMUP_N = 100;

var
  GConn: IDbConnection;                 { 工作体经全局捕获 }
  GK: Int64;
  GLat: array of QWord;

{ ---- 统计：原地堆排序 + 均值/P50/P99/max 报告 ---- }

procedure HeapSortQWord(var AArr: array of QWord; const AN: Integer);

  procedure SiftDown(var ARoot: Integer; AEnd_: Integer);
  var
    LChild: Integer;
    LTmp: QWord;
  begin
    while True do
    begin
      LChild := 2 * ARoot + 1;
      if LChild > AEnd_ then
        Break;
      if (LChild + 1 <= AEnd_) and (AArr[LChild + 1] > AArr[LChild]) then
        Inc(LChild);
      if AArr[ARoot] >= AArr[LChild] then
        Break;
      LTmp := AArr[ARoot]; AArr[ARoot] := AArr[LChild]; AArr[LChild] := LTmp;
      ARoot := LChild;
    end;
  end;

var
  I, LIdx: Integer;
  LTmp: QWord;
begin
  for I := AN div 2 downto 0 do
  begin
    LIdx := I;
    SiftDown(LIdx, AN - 1);
  end;
  for I := AN - 1 downto 1 do
  begin
    LTmp := AArr[0]; AArr[0] := AArr[I]; AArr[I] := LTmp;
    LIdx := 0;
    SiftDown(LIdx, I - 1);
  end;
end;

function ReportLat(const ALabel_: string; const AN: Integer): Double;
var
  I: Integer;
  LSorted: array of QWord;
  LSum: QWord;
begin
  LSorted := Copy(GLat, 0, AN);
  HeapSortQWord(LSorted, AN);
  LSum := 0;
  for I := 0 to AN - 1 do
    LSum := LSum + LSorted[I];
  WriteLn(Format('%s n=%d mean=%.1fus p50=%.1fus p99=%.1fus max=%.1fus',
    [ALabel_, AN, LSum / AN / 1000.0,
     LSorted[AN div 2] / 1000.0,
     LSorted[(AN * 99) div 100] / 1000.0,
     LSorted[AN - 1] / 1000.0]));
  Result := LSum / AN;
end;

{ ---- sqlite :memory: 双路 ---- }

function BenchSqliteSync(const AN: Integer): Double;
var
  I: Integer;
  LQ: IDbQuery;
  LT0, LT1: QWord;
begin
  SetLength(GLat, AN);
  { 预热 }
  for I := 1 to WARMUP_N do
  begin
    LQ := GConn.Query('SELECT 1');
    LQ.Step;
    LQ := nil;
  end;
  for I := 0 to AN - 1 do
  begin
    LT0 := platform_monotonic_ns;
    LQ := GConn.Query('SELECT 1');
    LQ.Step;
    LQ := nil;
    LT1 := platform_monotonic_ns;
    GLat[I] := LT1 - LT0;
  end;
  Result := ReportLat('sqlite sync direct ', AN);
end;

function BenchSqliteAsync(const AN: Integer): Double;
var
  I: Integer;
  LH: IDbAsyncHandle;
  LExec: TDbAsyncExecutor;
  LT0, LT1: QWord;
begin
  SetLength(GLat, AN);
  LExec := TDbAsyncExecutor.Create(GConn);
  try
    { 预热 }
    for I := 1 to WARMUP_N do
    begin
      LH := LExec.Submit(procedure
        var
          LQ: IDbQuery;
        begin
          LQ := GConn.Query('SELECT 1');
          LQ.Step;
          LQ := nil;
        end);
      if not LH.WaitFor(60000) then
      begin
        WriteLn('FATAL: warmup wait timeout');
        Halt(1);
      end;
      LH := nil;
    end;
    for I := 0 to AN - 1 do
    begin
      LT0 := platform_monotonic_ns;
      LH := LExec.Submit(procedure
        var
          LQ: IDbQuery;
        begin
          LQ := GConn.Query('SELECT 1');
          LQ.Step;
          LQ := nil;
        end);
      if not LH.WaitFor(60000) then
      begin
        WriteLn('FATAL: wait timeout at op ', GK);
        Halt(1);
      end;
      LT1 := platform_monotonic_ns;
      GLat[I] := LT1 - LT0;
      LH := nil;
    end;
  finally
    LExec.Free;
  end;
  Result := ReportLat('sqlite async submit/wait', AN);
end;

{ ---- pg 真机双路（自门控） ---- }

function BenchPgSync(const AN: Integer): Double;
var
  I: Integer;
  LQ: IDbQuery;
  LT0, LT1: QWord;
begin
  SetLength(GLat, AN);
  for I := 1 to WARMUP_N do
  begin
    LQ := GConn.Query('SELECT 1');
    LQ.Step;
    LQ := nil;
  end;
  for I := 0 to AN - 1 do
  begin
    LT0 := platform_monotonic_ns;
    LQ := GConn.Query('SELECT 1');
    LQ.Step;
    LQ := nil;
    LT1 := platform_monotonic_ns;
    GLat[I] := LT1 - LT0;
  end;
  Result := ReportLat('pg sync direct ', AN);
end;

function BenchPgAsync(const AN: Integer): Double;
var
  I: Integer;
  LH: IDbAsyncHandle;
  LExec: TDbAsyncExecutor;
  LT0, LT1: QWord;
begin
  SetLength(GLat, AN);
  LExec := TDbAsyncExecutor.Create(GConn);
  try
    for I := 1 to WARMUP_N do
    begin
      LH := LExec.Submit(procedure
        var
          LQ: IDbQuery;
        begin
          LQ := GConn.Query('SELECT 1');
          LQ.Step;
          LQ := nil;
        end);
      if not LH.WaitFor(60000) then
        Halt(1);
      LH := nil;
    end;
    for I := 0 to AN - 1 do
    begin
      LT0 := platform_monotonic_ns;
      LH := LExec.Submit(procedure
        var
          LQ: IDbQuery;
        begin
          LQ := GConn.Query('SELECT 1');
          LQ.Step;
          LQ := nil;
        end);
      if not LH.WaitFor(60000) then
        Halt(1);
      LT1 := platform_monotonic_ns;
      GLat[I] := LT1 - LT0;
      LH := nil;
    end;
  finally
    LExec.Free;
  end;
  Result := ReportLat('pg async submit/wait', AN);
end;

{ ---- 主段 ---- }

var
  LPgDsn: string;
  LSyncUs, LAsyncUs: Double;
begin
  WriteLn('== B6 异步挂载开销比：sync 直调 vs async submit/wait ==');

  GConn := ConnectSqlite(':memory:');
  LSyncUs := BenchSqliteSync(SQLITE_N);
  LAsyncUs := BenchSqliteAsync(SQLITE_N);
  WriteLn(Format('sqlite overhead ratio: %.2fx (async/sync)',
    [LAsyncUs / LSyncUs]));
  GConn := nil;

  LPgDsn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if LPgDsn <> '' then
  begin
    GConn := ConnectPostgres(LPgDsn);
    LSyncUs := BenchPgSync(PG_N);
    LAsyncUs := BenchPgAsync(PG_N);
    WriteLn(Format('pg overhead ratio: %.2fx (async/sync)',
      [LAsyncUs / LSyncUs]));
    GConn := nil;
  end
  else
    WriteLn('pg segment skipped (NEXTPAS_PG_TEST_CONN not set)');
end.
