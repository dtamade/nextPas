program test_iso8601_format;

{ nextpas.core.time.iso8601 Format 方向聚焦门禁：
  - RFC3339 UTC 序列化：epoch 秒 → 'YYYY-MM-DDTHH:MM:SSZ'（定长 20）；
  - 已知向量（date 独立验证）：闰日/闰年、世纪年 2100、9999 上限、
    5 位扩展年自然输出；日内/跨日边界；
  - 校验：负数时间戳拒绝（EArgumentError）；
  - 与 ParseISO8601DateTimeOffset 往返等价（Format 产物可直接回读）；
  - 门面 re-export 等价。
  全程 heaptrc 0 unfreed（common.mk HEAPTRC_GATE=1）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.time,
  nextpas.core.time.iso8601,
  nextpas.core.time.offsetdatetime;

var
  T: TTestSuite;

{ ==================== 已知向量 ==================== }

procedure TestKnownVectors;
begin
  CheckEqual('1970-01-01T00:00:00Z', FormatISO8601UTC(0), 'epoch zero');
  CheckEqual('1970-01-02T00:00:00Z', FormatISO8601UTC(86400), 'day two');
  CheckEqual('2000-01-01T00:00:00Z', FormatISO8601UTC(946684800), '2000 leap year');
  CheckEqual('2000-02-29T00:00:00Z', FormatISO8601UTC(951782400), 'leap day');
  CheckEqual('2000-03-01T00:00:00Z', FormatISO8601UTC(951868800), 'after leap day');
  CheckEqual('2006-01-01T00:00:00Z', FormatISO8601UTC(1136073600), '2006');
  { 网关数据锚点：1785900000 秒 ≈ 2026-08（与 time.bucket 测试同一时间域）。 }
  CheckEqual('2026-08-05T03:20:00Z', FormatISO8601UTC(1785900000),
    'gateway-anchored instant');
  { 2100 为世纪年非闰（能被 100 整除且不能被 400 整除）。 }
  CheckEqual('2100-01-01T00:00:00Z', FormatISO8601UTC(4102444800),
    'century non-leap year');
  { 4 位年上限：9999-12-31T23:59:59Z。 }
  CheckEqual('9999-12-31T23:59:59Z', FormatISO8601UTC(253402300799),
    'year 9999 upper bound');
end;

procedure TestDayBoundaries;
begin
  CheckEqual('1970-01-01T23:59:59Z', FormatISO8601UTC(86399), 'last second of day');
  CheckEqual('2000-02-29T23:59:59Z', FormatISO8601UTC(951782400 + 86399),
    'leap day last second');
  CheckEqual('2026-08-05T03:20:59Z', FormatISO8601UTC(1785900000 + 59),
    'second precision within minute');
end;

{ ==================== 扩展年 ==================== }

procedure TestExtendedYear;
begin
  { 9999 之后 ISO8601 允许扩展年：自然 5 位输出，不做上限截断。 }
  CheckEqual('10000-01-01T00:00:00Z', FormatISO8601UTC(253402300800),
    '5-digit extended year');
  CheckEqual(21, Length(FormatISO8601UTC(253402300800)), 'extended length 21');
end;

{ ==================== 定长 ==================== }

procedure TestFixedWidth;
begin
  CheckEqual(20, Length(FormatISO8601UTC(0)), 'epoch width');
  CheckEqual(20, Length(FormatISO8601UTC(1785900000)), 'gateway instant width');
  CheckEqual(20, Length(FormatISO8601UTC(253402300799)), 'year 9999 width');
end;

{ ==================== 校验 ==================== }

procedure TestNegativeRejected;
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    FormatISO8601UTC(-1);
  except
    on E: EArgumentError do
      LRejected := True;
  end;
  Check(LRejected, 'negative timestamp rejected');
end;

{ ==================== 与 Parse 往返 ==================== }

procedure TestRoundTripWithParser;
var
  LDT: TOffsetDateTime;
begin
  { Format 产物可直接被本单元 Parse 方向回读，秒值无损往返。 }
  LDT := ParseISO8601DateTimeOffset(FormatISO8601UTC(951782400 + 86399));
  CheckEqual(951782400 + 86399, LDT.ToUnixSeconds,
    'round-trip leap day last second');
  LDT := ParseISO8601DateTimeOffset(FormatISO8601UTC(1785900000));
  CheckEqual(1785900000, LDT.ToUnixSeconds, 'round-trip gateway instant');
end;

{ ==================== 门面等价 ==================== }

procedure TestFacadeEquivalence;
begin
  CheckEqual(nextpas.core.time.iso8601.FormatISO8601UTC(1785900000),
    FormatISO8601UTC(1785900000), 'facade matches module');
  CheckEqual(nextpas.core.time.iso8601.FormatISO8601UTC(253402300799),
    FormatISO8601UTC(253402300799), 'facade matches module (upper bound)');
end;

{ ==================== main ==================== }

begin
  T := TTestSuite.Create('core.time.iso8601.format');
  T.Test('known vectors', @TestKnownVectors);
  T.Test('day boundaries', @TestDayBoundaries);
  T.Test('extended year', @TestExtendedYear);
  T.Test('fixed width', @TestFixedWidth);
  T.Test('negative rejected', @TestNegativeRejected);
  T.Test('round-trip with parser', @TestRoundTripWithParser);
  T.Test('facade equivalence', @TestFacadeEquivalence);
  if not T.Run then
    Halt(1);
end.