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
 * @desc 计数器频率转纳秒级分辨率
 * @note 纯函数，可单测；使用 ceil，不高估时钟精度
 *}
function platform_resolution_from_frequency_ns(const AFrequency: UInt64): UInt64;

{**
 * @desc timespec 转纳秒
 * @note 纯函数，可单测
 *}
function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;

implementation

uses
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.ffi
  {$ELSE}
  , nextpas.core.platform.windows.math
  {$ENDIF}
  {$IFDEF NEXTPAS_UNIX}
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.ffi
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.ffi
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.ffi
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.ffi
  {$ELSE}
  , nextpas.core.platform.unix.ffi
  {$ENDIF}
  {$ENDIF}
  ;

function platform_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64;
begin
  Result := windows_qpc_to_ns(ACounter, AFrequency);
end;

function platform_resolution_from_frequency_ns(const AFrequency: UInt64): UInt64;
begin
  Result := windows_qpc_resolution_ns(AFrequency);
end;

function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;
var
  LTime: timespec;
begin
  LTime.tv_sec := ASec;
  LTime.tv_nsec := ANsec;
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

{ ============================================================ }
{ POSIX: host-owned clock helper wrappers                      }
{ ============================================================ }
{$IFDEF NEXTPAS_POSIX_CLOCK}

function platform_monotonic_ns: UInt64;
begin
  Result := platform_clock_monotonic_ns_u64;
end;

function platform_realtime_ns: UInt64;
begin
  Result := platform_clock_realtime_ns_u64;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := platform_clock_monotonic_resolution_ns_u64;
end;

{$ENDIF}

{ ============================================================ }
{ macOS: mach_absolute_time + host-owned realtime helper       }
{ ============================================================ }
{$IFDEF NEXTPAS_MACOS}
function platform_monotonic_ns: UInt64;
begin
  Result := platform_clock_monotonic_ns_u64;
end;

function platform_realtime_ns: UInt64;
begin
  Result := platform_clock_realtime_ns_u64;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := platform_clock_monotonic_resolution_ns_u64;
end;

{$ENDIF}

{ ============================================================ }
{ Windows: QueryPerformanceCounter (div/mod safe conversion)   }
{ ============================================================ }
{$IFDEF NEXTPAS_WINDOWS}
{**
 * @desc QPC → nanoseconds 无溢出换算
 * @note 使用 div/mod 分段：(counter div freq) * 1e9 + (counter mod freq) * 1e9 / freq
 *       避免 counter * 1e9 的 UInt64 溢出
 *}
function platform_monotonic_ns: UInt64;
begin
  Result := platform_clock_monotonic_ns_u64;
end;

function platform_realtime_ns: UInt64;
begin
  Result := platform_clock_realtime_ns_u64;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := platform_clock_monotonic_resolution_ns_u64;
end;

{$ENDIF}

{ ============================================================ }
{ Unsupported platform: compile-time error                     }
{ ============================================================ }
{$IFNDEF NEXTPAS_POSIX_CLOCK}
{$IFNDEF NEXTPAS_MACOS}
{$IFNDEF NEXTPAS_WINDOWS}
  {$FATAL 'nextpas.core.platform.time: unsupported platform. Implement for your target.'}
{$ENDIF}
{$ENDIF}
{$ENDIF}

end.
