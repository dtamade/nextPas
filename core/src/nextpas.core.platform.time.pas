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

implementation

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

end.
