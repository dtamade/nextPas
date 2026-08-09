unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.time.base,
  nextpas.core.platform.time.host;

type
  TPlatformTimeNanoseconds = nextpas.core.platform.time.base.TPlatformTimeNanoseconds;
  TPlatformCounterValue = nextpas.core.platform.time.base.TPlatformCounterValue;
  TPlatformCounterFrequency = nextpas.core.platform.time.base.TPlatformCounterFrequency;
  { breakdown 类型一并 re-export：业务代码 uses platform.time 即可拿到
    整数 UTC 分解（NextIntegerDoc：调用方无需钻 base 单元） }
  TPlatformTimeBreakdown = nextpas.core.platform.time.base.TPlatformTimeBreakdown;

{** @desc 获取单调时钟时间（纳秒，永不回退）
    @return 单调递增时间戳（纳秒） *}
function platform_monotonic_ns: TPlatformTimeNanoseconds; inline;

{** @desc 获取实时时钟时间（纳秒，UTC）
    @return 实时时间戳（纳秒） *}
function platform_realtime_ns: TPlatformTimeNanoseconds; inline;

{** @desc 获取单调时钟分辨率（纳秒，保守估计）
    @return 时钟分辨率（纳秒） *}
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds; inline;

{** @desc 将性能计数器值转换为纳秒
    @param ACounter 计数器值
    @param AFrequency 计数器频率（Hz）
    @return 纳秒值 *}
function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds; inline;

{** @desc 从频率计算分辨率（纳秒）
    @param AFrequency 频率（Hz）
    @return 分辨率（纳秒） *}
function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds; inline;

{** @desc 将 timespec 结构转换为纳秒
    @param ASec 秒
    @param ANsec 纳秒
    @return 总纳秒值 *}
function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds; inline;

{** @desc 获取本地 UTC 偏移量（秒）
    @return UTC 偏移量（如 UTC+8 返回 +28800） *}
function platform_utc_offset_seconds: Int32;

{** @desc 将实时时间戳分解为 UTC 时间组件
    @param ANs 实时时间戳（纳秒）
    @param AResult 输出时间分解结构 *}
procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds;
  out AResult: TPlatformTimeBreakdown);

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

function platform_monotonic_ns: TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_monotonic_ns;
end;

function platform_realtime_ns: TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_realtime_ns;
end;

function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_monotonic_resolution_ns;
end;

function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_qpc_to_ns(ACounter, AFrequency);
end;

function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_resolution_from_frequency_ns(AFrequency);
end;

function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.time.host.platform_timespec_to_ns(ASec, ANsec);
end;

function platform_utc_offset_seconds: Int32;
{$IFDEF NEXTPAS_UNIX}
var
  LTime: time_t;
  LTm: tm;
begin
  LTime := c_time(nil);
  localtime_r(@LTime, @LTm);
  Result := Int32(LTm.tm_gmtoff);
end;
{$ELSE}
{$IFDEF NEXTPAS_WINDOWS}
var
  LTzi: array[0..43] of Int32;
  LRet: UInt32;
  LBias: Int32;
begin
  LRet := GetTimeZoneInformation(LTzi);
  LBias := LTzi[0];
  case LRet of
    1: LBias := LBias + LTzi[21];
    2: LBias := LBias + LTzi[42];
  end;
  Result := -LBias * 60;
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}
{$ENDIF}

procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds;
  out AResult: TPlatformTimeBreakdown);
const
  DAYS_PER_400Y = 146097;
  DAYS_PER_100Y = 36524;
  DAYS_PER_4Y = 1461;
  MONTH_DAYS: array[0..11] of Int32 = (31,28,31,30,31,30,31,31,30,31,30,31);
  { March-start month order for the civil calendar algorithm: Mar=0..Feb=11 }
  MONTH_ORDER: array[0..11] of Int32 = (2,3,4,5,6,7,8,9,10,11,0,1);
var
  LSec, LDay, LRem: Int64;
  LYear, LMonth, LLeap: Int32;
  L400, L100, L4, L1: Int64;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LSec := Int64(ANs div 1000000000);
  AResult.Millisecond := Int32((ANs div 1000000) mod 1000);

  LDay := LSec div 86400;
  LRem := LSec mod 86400;
  if LRem < 0 then begin Inc(LRem, 86400); Dec(LDay); end;

  AResult.Hour := Int32(LRem div 3600);
  LRem := LRem mod 3600;
  AResult.Minute := Int32(LRem div 60);
  AResult.Second := Int32(LRem mod 60);

  LDay := LDay + 719468;
  L400 := LDay div DAYS_PER_400Y;
  LDay := LDay - L400 * DAYS_PER_400Y;
  if LDay < 0 then begin Dec(L400); Inc(LDay, DAYS_PER_400Y); end;

  L100 := LDay div DAYS_PER_100Y;
  if L100 = 4 then L100 := 3;
  LDay := LDay - L100 * DAYS_PER_100Y;

  L4 := LDay div DAYS_PER_4Y;
  LDay := LDay - L4 * DAYS_PER_4Y;

  L1 := LDay div 365;
  if L1 = 4 then L1 := 3;
  LDay := LDay - L1 * 365;

  LYear := Int32(L400 * 400 + L100 * 100 + L4 * 4 + L1);
  if (L1 = 0) and ((L4 <> 0) or (L100 = 0)) then
    LLeap := 1
  else
    LLeap := 0;

  LMonth := 0;
  while LMonth < 11 do
  begin
    if (MONTH_ORDER[LMonth] = 1) and (LLeap = 1) then
    begin
      if LDay < 29 then Break;
      Dec(LDay, 29);
    end
    else
    begin
      if LDay < MONTH_DAYS[MONTH_ORDER[LMonth]] then Break;
      Dec(LDay, MONTH_DAYS[MONTH_ORDER[LMonth]]);
    end;
    Inc(LMonth);
  end;

  if LMonth >= 10 then
    Inc(LYear);
  AResult.Year := LYear;
  AResult.Month := MONTH_ORDER[LMonth] + 1;
  AResult.Day := Int32(LDay) + 1;
end;

end.
