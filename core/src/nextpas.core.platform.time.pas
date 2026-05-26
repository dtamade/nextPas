unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

{**
 * @desc 单调时钟，纳秒精度
 * @note 契约：绝不倒退，不受系统时钟调整影响
 *       失败时返回 0（不应发生在正常系统上）
 *}
function platform_monotonic_ns: UInt64;

{**
 * @desc 实时时钟，纳秒精度
 * @note 契约：返回自 Unix epoch (1970-01-01T00:00:00Z) 以来的纳秒数
 *       可能因 NTP/手动调整而跳变
 *}
function platform_realtime_ns: UInt64;

{**
 * @desc 单调时钟分辨率
 * @note 契约：返回保守值（实际精度 >= 返回值），最小为 1ns
 *       不高估精度
 *}
function platform_monotonic_resolution_ns: UInt64;

{**
 * @desc QPC 计数器转纳秒（div/mod 安全，不溢出）
 * @note 纯函数，可单测
 *}
function platform_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64;

{**
 * @desc timespec 转纳秒
 * @note 纯函数，可单测
 *}
function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  Linux, UnixType;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  UnixType;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  Windows;
{$ENDIF}

const
  NANOSECONDS_PER_SECOND = UInt64(1000000000);

{ ============================================================ }
{ Linux: clock_gettime(CLOCK_MONOTONIC / CLOCK_REALTIME)       }
{ ============================================================ }
{$IFDEF NEXTPAS_LINUX}

function platform_monotonic_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_gettime(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
end;

function platform_realtime_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_gettime(CLOCK_REALTIME, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
end;

function platform_monotonic_resolution_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_getres(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 1;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ macOS: mach_absolute_time + clock_gettime (10.12+)           }
{ ============================================================ }
{$IFDEF NEXTPAS_MACOS}

type
  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

function mach_absolute_time: UInt64; cdecl; external 'c';
function mach_timebase_info(out AInfo: mach_timebase_info_data_t): Int32; cdecl; external 'c';
function clock_gettime(AClockId: Int32; ATs: Pointer): Int32; cdecl; external 'c';

const
  CLOCK_REALTIME = 0;

var
  GTimebaseNumer: UInt64 = 0;
  GTimebaseDenom: UInt64 = 0;

procedure EnsureTimebase;
var
  LInfo: mach_timebase_info_data_t;
begin
  if GTimebaseDenom = 0 then
  begin
    mach_timebase_info(LInfo);
    GTimebaseNumer := LInfo.numer;
    GTimebaseDenom := LInfo.denom;
    if GTimebaseDenom = 0 then
    begin
      GTimebaseNumer := 1;
      GTimebaseDenom := 1;
    end;
  end;
end;

function platform_monotonic_ns: UInt64;
var
  LTicks: UInt64;
begin
  EnsureTimebase;
  LTicks := mach_absolute_time;
  Result := LTicks div GTimebaseDenom * GTimebaseNumer +
            LTicks mod GTimebaseDenom * GTimebaseNumer div GTimebaseDenom;
end;

function platform_realtime_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_gettime(CLOCK_REALTIME, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  EnsureTimebase;
  Result := GTimebaseNumer div GTimebaseDenom;
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ Windows: QueryPerformanceCounter (div/mod safe conversion)   }
{ ============================================================ }
{$IFDEF NEXTPAS_WINDOWS}

var
  GFrequency: Int64 = 0;

procedure EnsureFrequency;
begin
  if GFrequency = 0 then
  begin
    if not QueryPerformanceFrequency(GFrequency) then
      GFrequency := 1;
    if GFrequency <= 0 then
      GFrequency := 1;
  end;
end;

{**
 * @desc QPC → nanoseconds 无溢出换算
 * @note 使用 div/mod 分段：(counter div freq) * 1e9 + (counter mod freq) * 1e9 / freq
 *       避免 counter * 1e9 的 UInt64 溢出
 *}
function platform_monotonic_ns: UInt64;
var
  LCounter: Int64;
  LFreq: UInt64;
  LWholeSec, LFracTicks: UInt64;
begin
  EnsureFrequency;
  if not QueryPerformanceCounter(LCounter) then
  begin
    Result := 0;
    Exit;
  end;
  LFreq := UInt64(GFrequency);
  LWholeSec := UInt64(LCounter) div LFreq;
  LFracTicks := UInt64(LCounter) mod LFreq;
  Result := LWholeSec * NANOSECONDS_PER_SECOND +
            LFracTicks * NANOSECONDS_PER_SECOND div LFreq;
end;

function platform_realtime_ns: UInt64;
var
  LFt: FILETIME;
  LVal: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);
  LVal := (UInt64(LFt.dwHighDateTime) shl 32) or UInt64(LFt.dwLowDateTime);
  // FILETIME is 100ns intervals since 1601-01-01
  // Unix epoch offset: 116444736000000000 * 100ns
  Result := (LVal - UInt64(116444736000000000)) * UInt64(100);
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  EnsureFrequency;
  Result := NANOSECONDS_PER_SECOND div UInt64(GFrequency);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ Unsupported platform: compile-time error                     }
{ ============================================================ }
{$IFNDEF NEXTPAS_LINUX}
{$IFNDEF NEXTPAS_MACOS}
{$IFNDEF NEXTPAS_WINDOWS}
  {$FATAL 'nextpas.core.platform.time: unsupported platform. Implement for your target.'}
{$ENDIF}
{$ENDIF}
{$ENDIF}

{ ============================================================ }
{ Pure helper functions (testable, platform-independent)        }
{ ============================================================ }

function platform_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64;
var
  LFreq: UInt64;
  LWholeSec, LFracTicks: UInt64;
begin
  LFreq := AFrequency;
  if LFreq = 0 then
    LFreq := 1;
  LWholeSec := ACounter div LFreq;
  LFracTicks := ACounter mod LFreq;
  Result := LWholeSec * NANOSECONDS_PER_SECOND +
            LFracTicks * NANOSECONDS_PER_SECOND div LFreq;
end;

function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;
begin
  Result := UInt64(ASec) * NANOSECONDS_PER_SECOND + UInt64(ANsec);
end;

end.
