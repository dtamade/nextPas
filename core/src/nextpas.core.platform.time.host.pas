unit nextpas.core.platform.time.host;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.time.base;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
function platform_realtime_ns: TPlatformTimeNanoseconds;
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds;

implementation

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.math
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.ffi
  {$ELSE}
  , nextpas.core.platform.windows.math
  {$ENDIF}
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.ffi
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

function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := windows_qpc_to_ns(ACounter, AFrequency);
end;

function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := windows_qpc_resolution_ns(AFrequency);
end;

function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds;
var
  LTime: timespec;
begin
  LTime.tv_sec := ASec;
  LTime.tv_nsec := ANsec;
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

{$IFDEF NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_PLATFORM_TIME_HOST_FFI}
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  {$DEFINE NEXTPAS_PLATFORM_TIME_HOST_FFI}
{$ENDIF}
{$IFNDEF NEXTPAS_PLATFORM_TIME_HOST_FFI}
  {$FATAL 'nextpas.core.platform.time.host: unsupported platform. Implement for your target.'}
{$ENDIF}

function platform_time_host_clock_monotonic_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_clock_monotonic_ns_u64;
  {$ELSE}
  Result := platform_clock_monotonic_ns_u64;
  {$ENDIF}
end;

function platform_time_host_clock_realtime_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_clock_realtime_ns_u64;
  {$ELSE}
  Result := platform_clock_realtime_ns_u64;
  {$ENDIF}
end;

function platform_time_host_clock_monotonic_resolution_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_clock_monotonic_resolution_ns_u64;
  {$ELSE}
  Result := platform_clock_monotonic_resolution_ns_u64;
  {$ENDIF}
end;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_monotonic_ns_u64;
end;

function platform_realtime_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_realtime_ns_u64;
end;

function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_monotonic_resolution_ns_u64;
end;

end.
