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

{ Monotonic clock in nanoseconds. Never moves backward and is not affected by
  wall-clock adjustments. Returns 0 only if the host clock is unavailable. }
function platform_monotonic_ns: TPlatformTimeNanoseconds; inline;

{ Realtime clock in nanoseconds since the Unix epoch. This can jump if the
  system clock is adjusted. }
function platform_realtime_ns: TPlatformTimeNanoseconds; inline;

{ Conservative monotonic clock resolution in nanoseconds. The returned value is
  never smaller than 1ns and does not overstate precision. }
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds; inline;

{ Convert a host counter value to nanoseconds without intermediate overflow. }
function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds; inline;

{ Convert a counter frequency to a conservative nanosecond resolution. }
function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds; inline;

{ Convert a POSIX timespec pair to saturated nanoseconds. }
function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds; inline;

{ Get the local UTC offset in seconds (e.g. +28800 for UTC+8). }
function platform_utc_offset_seconds: Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
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
  LBias: Int32;
begin
  // Windows: GetTimeZoneInformation returns bias in minutes (UTC = local + bias)
  // So offset = -bias * 60
  LBias := 0; // TODO: implement via GetTimeZoneInformation
  Result := -LBias * 60;
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}
{$ENDIF}

end.
