program bench_db_listen;

{ V3-B7 LISTEN/NOTIFY 投递面基准（CONTRACT §2.18 延迟事实的判据源）：
    - latency：单条 NOTIFY → Receive 醒来的端到端耗时。双泵节拍对照
      （默认 50ms / 5ms）验证"延迟上界 ≈ 泵节拍 + 服务端 RTT"契约，
      并为 PQsocket + 平台轮询器升级路径留存升级前基线（有判据再立项）
    - throughput：分批流水 NOTIFY 的稳态消费吞吐，DroppedCount ≠ 0
      即 Halt(1)（fail-fast，对齐 pool_stress 的不变式风格）
    - 计时 platform_monotonic_ns，报告均值 / P50 / P99 / max（µs）
    - pg 真机段（NEXTPAS_PG_TEST_CONN 自门控）；LISTEN/NOTIFY 为 pg
      独有能力，无 sqlite 对照段 }

{$mode ObjFPC}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.base,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg,
  nextpas.core.db.pg.listen,
  nextpas.core.platform.time;

const
  LAT_N = 400;          { 延迟采样条数（每节拍档） }
  WARMUP_N = 20;
  TPT_TOTAL = 2000;     { 吞吐段通知总数 }
  TPT_CHUNK = 100;      { 每次 Exec 携带的通知数 }
  QUEUE_CAP = 8192;     { 吞吐段容量：总量的 4 倍，杜绝溢出干扰 }

var
  GLat: array of QWord;

{ ---- 统计：原地堆排序 + 均值/P50/P99/max 报告（ns 输入，µs 输出） ---- }

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
  if AN < 2 then
    Exit;
  for I := AN div 2 - 1 downto 0 do
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

function ReportLat(const ALabel: string; const AN: Integer): Double;
var
  I: Integer;
  LMean: Double;
begin
  HeapSortQWord(GLat, AN);
  LMean := 0;
  for I := 0 to AN - 1 do
    LMean := LMean + GLat[I] / 1000.0;
  LMean := LMean / AN;
  Result := LMean;
  WriteLn(Format('%s: mean=%.1fus p50=%.1fus p99=%.1fus max=%.1fus (n=%d)',
    [ALabel, LMean,
     GLat[AN div 2] / 1000.0,
     GLat[(AN * 99) div 100] / 1000.0,
     GLat[AN - 1] / 1000.0, AN]));
end;

{ ---- 延迟段：单发单收，双节拍对照 ---- }

procedure BenchLatency(const ADsn, AChannel: string; const ATickMs: Cardinal);
var
  L: TPgListener;
  S: TPgConn;
  I: Integer;
  LT0, LT1: QWord;
  A: TDbPgNotificationArray;
begin
  SetLength(GLat, LAT_N);
  L := TPgListener.Create(ADsn, ATickMs, QUEUE_CAP);
  S := TPgConn.Create(ADsn);
  try
    L.Listen(AChannel);
    Sleep(ATickMs * 3);                { 确保 LISTEN 已应用 }
    for I := 1 to WARMUP_N do
    begin
      S.Exec('NOTIFY ' + AChannel);
      L.Receive(5000);
    end;
    for I := 0 to LAT_N - 1 do
    begin
      LT0 := platform_monotonic_ns;
      S.Exec('NOTIFY ' + AChannel);
      A := L.Receive(5000);
      LT1 := platform_monotonic_ns;
      if Length(A) < 1 then
      begin
        WriteLn('FATAL: notification lost in latency pass at ', I);
        Halt(1);
      end;
      GLat[I] := LT1 - LT0;
      A := nil;
    end;
    if L.DroppedCount <> 0 then
    begin
      WriteLn('FATAL: unexpected drops in latency pass');
      Halt(1);
    end;
    ReportLat('listen latency tick=' + IntToStr(ATickMs) + 'ms ', LAT_N);
  finally
    S.Free;
    L.Free;
  end;
end;

{ ---- 吞吐段：分批流水，零丢弃断言 ---- }

procedure BenchThroughput(const ADsn, AChannel: string);
var
  L: TPgListener;
  S: TPgConn;
  I, K, LGot: Integer;
  LBatches: array of string;
  LT0, LT1: QWord;
  A: TDbPgNotificationArray;
begin
  { 服务端语义：同事务内同频道+同载荷的 NOTIFY 去重只投一条——
    载荷必须逐条唯一（batch 序号 + 条内序号），否则吞吐测的是去重 }
  SetLength(LBatches, TPT_TOTAL div TPT_CHUNK);
  for I := 0 to High(LBatches) do
  begin
    LBatches[I] := '';
    for K := 1 to TPT_CHUNK do
    begin
      if LBatches[I] <> '' then
        LBatches[I] := LBatches[I] + '; ';
      LBatches[I] := LBatches[I] + 'NOTIFY ' + AChannel + ', ''b' +
        IntToStr(I) + '_n' + IntToStr(K) + '''';
    end;
  end;
  L := TPgListener.Create(ADsn, PG_LISTEN_DEFAULT_TICK_MS, QUEUE_CAP);
  S := TPgConn.Create(ADsn);
  try
    L.Listen(AChannel);
    Sleep(PG_LISTEN_DEFAULT_TICK_MS * 3);
    LT0 := platform_monotonic_ns;
    for I := 0 to High(LBatches) do
      S.Exec(LBatches[I]);
    LGot := 0;
    while LGot < TPT_TOTAL do
    begin
      A := L.Receive(10000);
      if Length(A) = 0 then
      begin
        WriteLn('FATAL: throughput drain stalled at ', LGot, '/', TPT_TOTAL);
        Halt(1);
      end;
      Inc(LGot, Length(A));
      A := nil;
    end;
    LT1 := platform_monotonic_ns;
    if L.DroppedCount <> 0 then
    begin
      WriteLn('FATAL: DroppedCount=', L.DroppedCount,
        ' (capacity too small for burst)');
      Halt(1);
    end;
    WriteLn(Format('listen throughput: %d notifs in %.1f ms => %.0f notifs/s',
      [TPT_TOTAL, (LT1 - LT0) / 1e6,
       TPT_TOTAL * 1e9 / (LT1 - LT0)]));
  finally
    S.Free;
    L.Free;
  end;
end;

var
  LPgDsn: string;
begin
  WriteLn('== B7 LISTEN/NOTIFY 投递面：延迟（双节拍）+ 吞吐 ==');
  LPgDsn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if LPgDsn = '' then
  begin
    WriteLn('pg segment skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  BenchLatency(LPgDsn, 'np_bench_lat', PG_LISTEN_DEFAULT_TICK_MS);
  BenchLatency(LPgDsn, 'np_bench_lat5', 5);
  BenchThroughput(LPgDsn, 'np_bench_tpt');
end.
