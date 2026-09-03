program test_time_bucket;

{ nextpas.core.time.bucket 聚焦门禁：
  - 桶键语义：epoch 秒 div 桶宽 → 定宽补零（字典序 = 时间序）；
  - 桶宽任意（分/时/天）；零时刻；跨桶边界；定长；
  - 校验：桶宽 >= 1、非负时间戳、宽度足够；
  - 门面 re-export 等价。
  全程 heaptrc 0 unfreed（common.mk HEAPTRC_GATE=1）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.time,
  nextpas.core.time.bucket;

var
  T: TTestSuite;

{ ==================== 桶键语义 ==================== }

procedure TestHourBucketDefault;
begin
  { epoch 0 与 3599（首小时内）→ 桶 0；3600/7200 → 桶 1/2。 }
  CheckEqual('000000000000', TimeBucketKey(0), 'epoch 0 -> bucket 0');
  CheckEqual('000000000000', TimeBucketKey(3599), '3599 still bucket 0');
  CheckEqual('000000000001', TimeBucketKey(3600), '3600 -> bucket 1');
  CheckEqual('000000000002', TimeBucketKey(7200), '7200 -> bucket 2');
  { 与网关 QuotaPeriodKey 同语义的已知值（1785900000 秒 ≈ 2026-08，小时桶）。 }
  CheckEqual('000000496083', TimeBucketKey(1785900000), 'known hour bucket');
end;

procedure TestBucketWidths;
begin
  CheckEqual('000000000001', TimeBucketKey(60, 60), 'minute bucket');
  CheckEqual('000000000001', TimeBucketKey(86400, 86400), 'day bucket');
  CheckEqual('000000000030', TimeBucketKey(86400 * 30, 86400), 'day 30');
  CheckEqual('000000000000', TimeBucketKey(86399, 86400), 'day boundary');
  CheckEqual('000000000365', TimeBucketKey(86400 * 365, 86400), 'year span');
end;

procedure TestLexicographicOrder;
var
  LT1, LT2, LT3: string;
begin
  { 字典序 = 时间序：相邻桶/跨桶/不同宽均定长可比较。 }
  LT1 := TimeBucketKey(0);
  LT2 := TimeBucketKey(3600);
  LT3 := TimeBucketKey(3600 * 24 * 30);
  Check(LT1 < LT2, 'bucket 0 < bucket 1 lexicographically');
  Check(LT2 < LT3, 'bucket 1 < bucket 30 lexicographically');
  { 同桶不同秒：键相等（聚合语义）。 }
  CheckEqual(TimeBucketKey(100), TimeBucketKey(3599), 'same bucket, same key');
end;

procedure TestFixedWidth;
begin
  CheckEqual(12, Length(TimeBucketKey(0)), 'default width 12');
  CheckEqual(12, Length(TimeBucketKey(1785900000)), 'default width 12 (large)');
  CheckEqual(20, Length(TimeBucketKey(1785900000, 3600, 20)), 'custom width 20');
end;

{ ==================== 校验 ==================== }

procedure TestValidation;
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    TimeBucketKey(0, 0);
  except
    on E: EArgumentError do
      LRejected := True;
  end;
  Check(LRejected, 'bucket seconds 0 rejected');

  LRejected := False;
  try
    TimeBucketKey(-1);
  except
    on E: EArgumentError do
      LRejected := True;
  end;
  Check(LRejected, 'negative timestamp rejected');

  LRejected := False;
  try
    TimeBucketKey(1785900000, 3600, 5);   { 桶序号 6 位 > 宽度 5 }
  except
    on E: EArgumentError do
      LRejected := True;
  end;
  Check(LRejected, 'width too small rejected');
end;

{ ==================== 大时间戳 ==================== }

procedure TestLargeTimestamps;
begin
  { 桶序号位数 > 默认 12 时须显式加宽；不溢出。 }
  CheckEqual(20, Length(TimeBucketKey(High(Int64), 3600, 20)),
    'high int64 fits width 20');
  Check(TimeBucketKey(High(Int64), 3600, 20) >
    TimeBucketKey(0), 'large bucket sorts after zero');
end;

{ ==================== 门面等价 ==================== }

procedure TestFacadeEquivalence;
begin
  { 门面 re-export 与子模块直调等价（含默认参数）。 }
  CheckEqual(nextpas.core.time.bucket.TimeBucketKey(1785900000),
    TimeBucketKey(1785900000), 'facade matches module (defaults)');
  CheckEqual(nextpas.core.time.bucket.TimeBucketKey(86400 * 7, 86400, 16),
    TimeBucketKey(86400 * 7, 86400, 16), 'facade matches module (explicit)');
end;

{ ==================== main ==================== }

begin
  T := TTestSuite.Create('core.time.bucket');
  T.Test('hour bucket default', @TestHourBucketDefault);
  T.Test('bucket widths', @TestBucketWidths);
  T.Test('lexicographic order', @TestLexicographicOrder);
  T.Test('fixed width', @TestFixedWidth);
  T.Test('validation', @TestValidation);
  T.Test('large timestamps', @TestLargeTimestamps);
  T.Test('facade equivalence', @TestFacadeEquivalence);
  if not T.Run then
    Halt(1);
end.